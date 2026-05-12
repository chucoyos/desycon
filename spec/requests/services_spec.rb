require "rails_helper"

RSpec.describe "Services", type: :request do
  let(:admin_user) { create(:user, :admin) }

  describe "GET /services" do
    before { sign_in admin_user, scope: :user }

    it "includes BL services with blank factura in proforma filter" do
      service = create(:bl_house_line_service, factura: nil)
      service.update_column(:factura, "")

      get services_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("BlHouseLineService:#{service.id}")
    end

    it "renders index successfully with service rows" do
      container = create(:container, number: "SERV1234567")
      create(:container_service, container: container, factura: nil, amount: 1450)

      get services_path, params: { service_type: "container" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Servicios de facturación")
      expect(response.body).to include("Tipo de servicio")
      expect(response.body).to include("SERV1234567")
      expect(response.body).to include("Proforma")
    end

    it "applies proforma filter by default on initial load" do
      proforma_catalog = create(:service_catalog, name: "Srv Proforma Default")
      failed_catalog = create(:service_catalog, name: "Srv Failed Hidden By Default")

      proforma_service = create(:container_service, service_catalog: proforma_catalog, factura: nil)
      failed_service = create(:container_service, service_catalog: failed_catalog, factura: nil)
      create(:invoice, invoiceable: failed_service, kind: "ingreso", status: "failed")

      get services_path, params: { service_type: "container" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Srv Proforma Default")
      expect(response.body).to include("ContainerService:#{proforma_service.id}")
      expect(response.body).not_to include("Srv Failed Hidden By Default")
      expect(response.body).to include("Estatus")
      expect(response.body).to include("Proforma")
    end

    it "filters by service_type container" do
      container = create(:container, number: "TYPE1234567")
      bl_house_line = create(:bl_house_line, container: container, blhouse: "BLH-TYPE-001")

      container_service = create(:container_service, container: container, factura: nil)
      bl_service = create(:bl_house_line_service, bl_house_line: bl_house_line, factura: nil)

      get services_path, params: { service_type: "container" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ContainerService:#{container_service.id}")
      expect(response.body).not_to include("BlHouseLineService:#{bl_service.id}")
    end

    it "filters by service_type partida" do
      container = create(:container, number: "PART1234001")
      bl_house_line = create(:bl_house_line, container: container, blhouse: "BLH-TYPE-002")

      container_service = create(:container_service, container: container, factura: nil)
      bl_service = create(:bl_house_line_service, bl_house_line: bl_house_line, factura: nil)

      get services_path, params: { service_type: "bl_house_line" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("BlHouseLineService:#{bl_service.id}")
      expect(response.body).not_to include("ContainerService:#{container_service.id}")
    end

    it "filters by container and blhouse" do
      matching_container = create(:container, number: "ABCD1234567")
      non_matching_container = create(:container, number: "WXYZ7654321")

      matching_bl = create(:bl_house_line, container: matching_container, blhouse: "BLH-FILTER-001")
      non_matching_bl = create(:bl_house_line, container: non_matching_container, blhouse: "BLH-FILTER-999")

      create(:bl_house_line_service, bl_house_line: matching_bl, factura: nil)
      create(:bl_house_line_service, bl_house_line: non_matching_bl, factura: nil)

      get services_path, params: { container_number: "ABCD1234567", blhouse: "BLH-FILTER-001" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ABCD1234567")
      expect(response.body).to include("BLH-FILTER-001")
      expect(response.body).not_to include("WXYZ7654321")
      expect(response.body).not_to include("BLH-FILTER-999")
    end

    it "does not include parent container services when filtering by blhouse" do
      container = create(:container, number: "BLHS1234567")
      bl_house_line = create(:bl_house_line, container: container, blhouse: "BLH-ONLY-001")

      parent_catalog = create(:service_catalog, name: "Servicio Padre Único")
      partida_catalog = create(:service_catalog, name: "Servicio Partida Único")

      parent_service = create(:container_service, container: container, service_catalog: parent_catalog, factura: nil)
      partida_service = create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: partida_catalog, factura: nil)

      get services_path, params: { blhouse: "BLH-ONLY-001" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Servicio Partida Único")
      expect(response.body).to include("BlHouseLineService:#{partida_service.id}")
      expect(response.body).not_to include("ContainerService:#{parent_service.id}")
    end

    it "includes partida services when filtering by container" do
      container = create(:container, number: "PART1234567")
      bl_house_line = create(:bl_house_line, container: container, blhouse: "BLH-CONT-001")
      partida_catalog = create(:service_catalog, name: "Servicio Partida Contenedor")

      create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: partida_catalog, factura: nil)

      get services_path, params: { container_number: "PART1234567" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Servicio Partida Contenedor")
      expect(response.body).to include("BLH-CONT-001")
    end

    it "filters by customs agency name for BL services" do
      target_agency = create(:entity, :customs_agent, name: "Agencia Filtro Norte")
      other_agency = create(:entity, :customs_agent, name: "Agencia Filtro Sur")

      matching_bl = create(:bl_house_line, customs_agent: target_agency)
      non_matching_bl = create(:bl_house_line, customs_agent: other_agency)

      create(:bl_house_line_service, bl_house_line: matching_bl, factura: nil)
      create(:bl_house_line_service, bl_house_line: non_matching_bl, factura: nil)

      get services_path, params: { customs_agency: "Norte" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Agencia Filtro Norte")
      expect(response.body).not_to include("Agencia Filtro Sur")
    end

    it "applies customs agency filter only to BL services and excludes container services" do
      target_agency = create(:entity, :customs_agent, name: "Agencia Exclusiva Partida")

      matching_bl = create(:bl_house_line, customs_agent: target_agency)
      create(:bl_house_line_service, bl_house_line: matching_bl, factura: nil)

      container = create(:container, number: "ABCD1234567")
      create(:container_service, container: container, factura: nil)

      get services_path, params: { customs_agency: "Exclusiva" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Agencia Exclusiva Partida")
      expect(response.body).not_to include("ABCD1234567")
    end

    it "uses two-week date range by default" do
      recent_catalog = create(:service_catalog, name: "Srv Recent")
      old_catalog = create(:service_catalog, name: "Srv Old")

      recent_service = create(:container_service, service_catalog: recent_catalog, factura: nil)
      old_service = create(:container_service, service_catalog: old_catalog, factura: nil)
      old_service.update_column(:created_at, 2.months.ago)

      get services_path, params: { service_type: "container" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Srv Recent")
      expect(response.body).to include("ContainerService:#{recent_service.id}")
      expect(response.body).not_to include("ContainerService:#{old_service.id}")
      expect(response.body).to include("name=\"start_date\"")
      expect(response.body).to include("name=\"end_date\"")

      # Ensure we still have both records, proving exclusion comes from date filter.
      expect(ContainerService.where(id: [ recent_service.id, old_service.id ]).count).to eq(2)
    end

    it "allows expanding date range to include older services" do
      old_catalog = create(:service_catalog, name: "Srv Old Expanded")
      old_service = create(:container_service, service_catalog: old_catalog, factura: nil)
      old_service.update_column(:created_at, 2.months.ago)

      get services_path, params: {
        service_type: "container",
        start_date: 3.months.ago.to_date.to_s,
        end_date: Date.current.to_s
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Srv Old Expanded")
    end

    it "shows failed services as non-issuable" do
      catalog = create(:service_catalog, name: "Srv Failed Visible")
      service = create(:container_service, service_catalog: catalog, factura: nil)
      create(:invoice, invoiceable: service, kind: "ingreso", status: "failed")

      get services_path, params: { service_type: "container", billing_status: "fallido" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Srv Failed Visible")
      expect(response.body).to include("Fallido")
      expect(response.body).not_to include("ContainerService:#{service.id}")
    end

    it "uses non-REP invoice link for in-process services" do
      catalog = create(:service_catalog, name: "Srv InProcess Link")
      service = create(:container_service, service_catalog: catalog, factura: nil)
      ingreso_invoice = create(:invoice, invoiceable: service, kind: "ingreso", status: "draft")
      rep_invoice = create(:invoice, invoiceable: service, kind: "pago", status: "draft")

      get services_path, params: { service_type: "container", billing_status: "en_proceso" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Srv InProcess Link")
      expect(response.body).to include(invoice_path(ingreso_invoice))
      expect(response.body).not_to include(invoice_path(rep_invoice))
    end

    it "filters by billing status fallido" do
      failed_catalog = create(:service_catalog, name: "Srv Failed Filter")
      queued_catalog = create(:service_catalog, name: "Srv Queued Filter")
      proforma_catalog = create(:service_catalog, name: "Srv Proforma Filter")

      failed_service = create(:container_service, service_catalog: failed_catalog, factura: nil)
      queued_service = create(:container_service, service_catalog: queued_catalog, factura: nil)
      proforma_service = create(:container_service, service_catalog: proforma_catalog, factura: nil)

      create(:invoice, invoiceable: failed_service, status: "failed")
      create(:invoice, invoiceable: queued_service, status: "queued")

      get services_path, params: { service_type: "container", billing_status: "fallido" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Srv Failed Filter")
      expect(response.body).not_to include("Srv Queued Filter")
      expect(response.body).not_to include("Srv Proforma Filter")
      expect(response.body).to include("Fallido")
    end

    it "hides BL services covered by NIPON exception rule" do
      target_rfc = "NEM901109BC2"
      allow(Facturador::Config).to receive(:auto_issue_nipon_exception_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:auto_issue_nipon_rfc).and_return(target_rfc)
      allow(Facturador::Config).to receive(:auto_issue_exception_rfcs).and_return([ target_rfc ])

      consolidator = create(:entity, :consolidator)
      create(:fiscal_profile, profileable: consolidator, rfc: target_rfc)
      client = consolidator

      container = create(:container, consolidator_entity: consolidator)
      bl_house_line = create(:bl_house_line, container: container, client: client)
      hidden_service = create(:bl_house_line_service, bl_house_line: bl_house_line, factura: nil)

      visible_service = create(:container_service, factura: nil)

      get services_path, params: { service_type: "all" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ContainerService:#{visible_service.id}")
      expect(response.body).not_to include("BlHouseLineService:#{hidden_service.id}")
    end

    it "hides BL services for Master Forwarding RFC" do
      allow(Facturador::Config).to receive(:auto_issue_nipon_exception_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:auto_issue_nipon_rfc).and_return("NEM901109BC2")
      allow(Facturador::Config).to receive(:auto_issue_exception_rfcs).and_return([ "NEM901109BC2", "MFO250717B72" ])

      consolidator = create(:entity, :consolidator)
      create(:fiscal_profile, profileable: consolidator, rfc: "MFO250717B72")
      client = consolidator

      container = create(:container, consolidator_entity: consolidator)
      bl_house_line = create(:bl_house_line, container: container, client: client)
      hidden_service = create(:bl_house_line_service, bl_house_line: bl_house_line, factura: nil)

      get services_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("BlHouseLineService:#{hidden_service.id}")
    end

    it "hides BL services when client has NIPON RFC on a different entity record" do
      target_rfc = "NEM901109BC2"
      allow(Facturador::Config).to receive(:auto_issue_nipon_exception_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:auto_issue_nipon_rfc).and_return(target_rfc)
      allow(Facturador::Config).to receive(:auto_issue_exception_rfcs).and_return([ target_rfc ])

      consolidator = create(:entity, :consolidator)
      create(:fiscal_profile, profileable: consolidator, rfc: target_rfc)

      nippon_client = create(:entity, :client)
      client_profile = create(:fiscal_profile, profileable: nippon_client)
      client_profile.update_column(:rfc, target_rfc)

      container = create(:container, consolidator_entity: consolidator)
      bl_house_line = create(:bl_house_line, container: container, client: nippon_client)
      hidden_service = create(:bl_house_line_service, bl_house_line: bl_house_line, billed_to_entity: nil, factura: nil)

      get services_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("BlHouseLineService:#{hidden_service.id}")
    end

    it "keeps BL service visible when billed_to RFC is different even if client RFC matches exception" do
      target_rfc = "NEM901109BC2"
      allow(Facturador::Config).to receive(:auto_issue_nipon_exception_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:auto_issue_nipon_rfc).and_return(target_rfc)
      allow(Facturador::Config).to receive(:auto_issue_exception_rfcs).and_return([ target_rfc ])

      consolidator = create(:entity, :consolidator)
      create(:fiscal_profile, profileable: consolidator, rfc: target_rfc)

      nippon_client = create(:entity, :client)
      client_profile = create(:fiscal_profile, profileable: nippon_client)
      client_profile.update_column(:rfc, target_rfc)

      other_billed_to = create(:entity, :client)
      create(:fiscal_profile, profileable: other_billed_to, rfc: "ABC010203ZZA")

      container = create(:container, consolidator_entity: consolidator)
      bl_house_line = create(:bl_house_line, container: container, client: nippon_client)
      visible_service = create(:bl_house_line_service, bl_house_line: bl_house_line, billed_to_entity: other_billed_to, factura: nil)

      get services_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("BlHouseLineService:#{visible_service.id}")
    end
  end

  describe "POST /services/issue_batch" do
    before { sign_in admin_user, scope: :user }

    it "issues mixed service types in one batch" do
      container_service = create(:container_service, factura: nil)
      bl_service = create(:bl_house_line_service, factura: nil)
      grouped_invoice = create(:invoice, invoiceable: nil)
      service_result = Facturador::IssueGroupedServicesService::Result.new(invoice: grouped_invoice)

      expect(Facturador::IssueGroupedServicesService).to receive(:call) do |args|
        expect(args[:actor]).to eq(admin_user)
        expect(args[:serviceables]).to match_array([ container_service, bl_service ])
        service_result
      end

      post issue_batch_services_path, params: {
        service_tokens: [
          "ContainerService:#{container_service.id}",
          "BlHouseLineService:#{bl_service.id}"
        ]
      }

      expect(response).to redirect_to(invoice_path(grouped_invoice))
      expect(flash[:notice]).to include("Emisión agrupada")
    end

    it "returns alert when no valid services are selected" do
      post issue_batch_services_path, params: { service_tokens: [] }

      expect(response).to redirect_to(services_path)
      expect(flash[:alert]).to include("Selecciona al menos un servicio válido")
    end

    it "rejects NIPON-exception BL services even when token is submitted" do
      target_rfc = "NEM901109BC2"
      allow(Facturador::Config).to receive(:auto_issue_nipon_exception_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:auto_issue_nipon_rfc).and_return(target_rfc)
      allow(Facturador::Config).to receive(:auto_issue_exception_rfcs).and_return([ target_rfc ])

      consolidator = create(:entity, :consolidator)
      create(:fiscal_profile, profileable: consolidator, rfc: target_rfc)
      client = consolidator

      container = create(:container, consolidator_entity: consolidator)
      bl_house_line = create(:bl_house_line, container: container, client: client)
      blocked_service = create(:bl_house_line_service, bl_house_line: bl_house_line, factura: nil)

      expect(Facturador::IssueGroupedServicesService).not_to receive(:call)

      post issue_batch_services_path, params: { service_tokens: [ "BlHouseLineService:#{blocked_service.id}" ] }

      expect(response).to redirect_to(services_path)
      expect(flash[:alert]).to include("Selecciona al menos un servicio válido")
    end

    it "rejects BL service token when NIPON RFC match comes from client entity" do
      target_rfc = "NEM901109BC2"
      allow(Facturador::Config).to receive(:auto_issue_nipon_exception_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:auto_issue_nipon_rfc).and_return(target_rfc)
      allow(Facturador::Config).to receive(:auto_issue_exception_rfcs).and_return([ target_rfc ])

      consolidator = create(:entity, :consolidator)
      create(:fiscal_profile, profileable: consolidator, rfc: target_rfc)

      nippon_client = create(:entity, :client)
      client_profile = create(:fiscal_profile, profileable: nippon_client)
      client_profile.update_column(:rfc, target_rfc)

      container = create(:container, consolidator_entity: consolidator)
      bl_house_line = create(:bl_house_line, container: container, client: nippon_client)
      blocked_service = create(:bl_house_line_service, bl_house_line: bl_house_line, billed_to_entity: nil, factura: nil)

      expect(Facturador::IssueGroupedServicesService).not_to receive(:call)

      post issue_batch_services_path, params: { service_tokens: [ "BlHouseLineService:#{blocked_service.id}" ] }

      expect(response).to redirect_to(services_path)
      expect(flash[:alert]).to include("Selecciona al menos un servicio válido")
    end

    it "allows BL service token when billed_to RFC differs even if client RFC matches exception" do
      target_rfc = "NEM901109BC2"
      allow(Facturador::Config).to receive(:auto_issue_nipon_exception_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:auto_issue_nipon_rfc).and_return(target_rfc)
      allow(Facturador::Config).to receive(:auto_issue_exception_rfcs).and_return([ target_rfc ])

      consolidator = create(:entity, :consolidator)
      create(:fiscal_profile, profileable: consolidator, rfc: target_rfc)

      nippon_client = create(:entity, :client)
      client_profile = create(:fiscal_profile, profileable: nippon_client)
      client_profile.update_column(:rfc, target_rfc)

      other_billed_to = create(:entity, :client)
      create(:fiscal_profile, profileable: other_billed_to, rfc: "ABC010203ZZB")

      container = create(:container, consolidator_entity: consolidator)
      bl_house_line = create(:bl_house_line, container: container, client: nippon_client)
      allowed_service = create(:bl_house_line_service, bl_house_line: bl_house_line, billed_to_entity: other_billed_to, factura: nil)

      grouped_invoice = create(:invoice, invoiceable: nil)
      service_result = Facturador::IssueGroupedServicesService::Result.new(invoice: grouped_invoice)

      expect(Facturador::IssueGroupedServicesService).to receive(:call) do |args|
        expect(args[:serviceables]).to match_array([ allowed_service ])
        service_result
      end

      post issue_batch_services_path, params: { service_tokens: [ "BlHouseLineService:#{allowed_service.id}" ] }

      expect(response).to redirect_to(invoice_path(grouped_invoice))
      expect(flash[:notice]).to include("Emisión agrupada")
    end

    it "rejects Master Forwarding BL services even when token is submitted" do
      allow(Facturador::Config).to receive(:auto_issue_nipon_exception_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:auto_issue_nipon_rfc).and_return("NEM901109BC2")
      allow(Facturador::Config).to receive(:auto_issue_exception_rfcs).and_return([ "NEM901109BC2", "MFO250717B72" ])

      consolidator = create(:entity, :consolidator)
      create(:fiscal_profile, profileable: consolidator, rfc: "MFO250717B72")
      client = consolidator

      container = create(:container, consolidator_entity: consolidator)
      bl_house_line = create(:bl_house_line, container: container, client: client)
      blocked_service = create(:bl_house_line_service, bl_house_line: bl_house_line, factura: nil)

      expect(Facturador::IssueGroupedServicesService).not_to receive(:call)

      post issue_batch_services_path, params: { service_tokens: [ "BlHouseLineService:#{blocked_service.id}" ] }

      expect(response).to redirect_to(services_path)
      expect(flash[:alert]).to include("Selecciona al menos un servicio válido")
    end
  end

  describe "authorization" do
    it "denies access to consolidator users" do
      consolidator_user = create(:user, :consolidator)
      sign_in consolidator_user, scope: :user

      get services_path

      expect(response).to redirect_to(containers_path)
    end
  end
end
