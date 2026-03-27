require "rails_helper"

RSpec.describe "Services", type: :request do
  let(:admin_user) { create(:user, :admin) }

  describe "GET /services" do
    before { sign_in admin_user, scope: :user }

    it "renders index successfully with service rows" do
      container = create(:container, number: "SERV1234567")
      create(:container_service, container: container, factura: nil, amount: 1450)

      get services_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Servicios de facturación")
      expect(response.body).to include("SERV1234567")
      expect(response.body).to include("Proforma")
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

      create(:container_service, container: container, service_catalog: parent_catalog, factura: nil)
      create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: partida_catalog, factura: nil)

      get services_path, params: { blhouse: "BLH-ONLY-001" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Servicio Partida Único")
      expect(response.body).not_to include("Servicio Padre Único")
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
