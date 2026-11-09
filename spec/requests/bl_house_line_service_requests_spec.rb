require "rails_helper"

RSpec.describe "Solicitudes de servicios Lázaro", type: :request do
  let(:agency_user) { create(:user, :customs_broker) }
  let(:executive) { create(:user, :executive) }
  let(:port) { create(:port, name: "Lázaro", code: "MXLZC", country_code: "MX") }
  let(:voyage) { create(:voyage, destination_port: port) }
  let(:container) { create(:container, voyage: voyage, recinto: "APM TERMINALS", almacen: "UTTSA RECINTO 173") }
  let(:line) { create(:bl_house_line, container: container, customs_agent: agency_user.entity, status: "revalidado") }
  let(:catalog) { create(:service_catalog, code: "BL-PMD-LZC", applies_to: "bl_house_line") }
  let(:assignment_catalog) { create(:service_catalog, code: "BL-ASIG", name: "Asignación electrónica de carga", applies_to: "bl_house_line") }
  let!(:assignment) { create(:bl_house_line_service, bl_house_line: line, service_catalog: assignment_catalog) }
  let!(:invoice) { create(:invoice, invoiceable: assignment, status: "issued") }
  let!(:payment) { create(:invoice_payment, invoice: invoice, amount: invoice.total) }

  def submit_request
    post bl_house_line_service_requests_path, params: {
      bl_house_line_service_request: { bl_house_line_id: line.id, service_catalog_id: catalog.id, requested_date: "2026-12-01" }
    }
  end

  it "shows the service request section and its empty state only for the agency's Lázaro line" do
    sign_in agency_user, scope: :user
    get bl_house_line_path(line)

    document = Nokogiri::HTML(response.body)
    section = document.at_css("section[aria-labelledby='service-requests-heading']")
    expect(section.text).to include("Solicitudes de servicios", "Aún no hay solicitudes")
    expect(section.at_css("a[href='#{new_bl_house_line_service_request_path(bl_house_line_id: line.id)}'] svg")).to be_present

    port.update!(code: "MXVER")
    get bl_house_line_path(line)
    expect(Nokogiri::HTML(response.body).at_css("section[aria-labelledby='service-requests-heading']")).to be_nil

    port.update!(code: "MXLZC")
    sign_out agency_user
    sign_in executive, scope: :user
    get bl_house_line_path(line)
    expect(Nokogiri::HTML(response.body).at_css("section[aria-labelledby='service-requests-heading']")).to be_nil
  end

  it "shows request status, dates and review notes in the line details" do
    sign_in agency_user, scope: :user
    submit_request
    request_record = BlHouseLineServiceRequest.last
    sign_out agency_user
    sign_in executive, scope: :user
    patch approve_bl_house_line_service_request_path(request_record), params: {
      bl_house_line_service_request: { scheduled_date: "2026-12-02", scheduled_time: "09:30", notes: "Confirmado con agencia" }
    }
    patch execute_bl_house_line_service_request_path(request_record)

    sign_out executive
    sign_in agency_user, scope: :user
    get bl_house_line_path(line)
    card = Nokogiri::HTML(response.body).at_css("article[data-service-request-id='#{request_record.id}']")
    expect(card.text).to include(catalog.display_name, "Ejecutada", "Solicitada", "2026-12-01",
      "2026-12-02", "09:30", "Observaciones", "Confirmado con agencia")
    expect(card.text).to include(I18n.l(request_record.reload.executed_at, format: :short))
  end

  it "allows an agency to request a service, then staff to schedule, reschedule and execute without dispatching" do
    sign_in agency_user, scope: :user
    submit_request
    expect(response).to redirect_to(bl_house_line_path(line))
    request_record = BlHouseLineServiceRequest.last
    expect(request_record.requested_date).to eq(Date.new(2026, 12, 1))
    expect(request_record.scheduled_time).to be_nil
    get bl_house_line_path(line)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Solicitudes de servicios", catalog.code, "Pendiente")
    get customs_agents_dashboard_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Solicitar servicio")
    expect(response.body).not_to include(catalog.display_name, "Solicitud: ", "Requerida: ", "Programada: ")
    links = Nokogiri::HTML(response.body).css("a[href='#{new_bl_house_line_service_request_path(bl_house_line_id: line.id)}']")
    expect(links.size).to eq(2)
    expect(links).to all(satisfy { |link| link.at_css("svg[aria-hidden='true']").present? && link.text.include?("Solicitar servicio") })

    sign_out agency_user
    sign_in executive, scope: :user
    patch approve_bl_house_line_service_request_path(request_record), params: {
      bl_house_line_service_request: { scheduled_date: "2026-12-01", scheduled_time: "09:30" }
    }
    expect(request_record.reload.status).to eq("approved")
    expect(request_record.scheduled_time.strftime("%H:%M")).to eq("09:30")
    expect(request_record.bl_house_line_service.fecha_programada).to eq(Date.new(2026, 12, 1))
    expect(line.reload.status).to eq("revalidado")

    patch reschedule_bl_house_line_service_request_path(request_record), params: {
      bl_house_line_service_request: { scheduled_date: "2026-12-02", scheduled_time: "10:00" }
    }
    expect(request_record.reload.requested_date).to eq(Date.new(2026, 12, 1))
    expect(request_record.scheduled_date).to eq(Date.new(2026, 12, 2))
    expect(request_record.scheduled_time.strftime("%H:%M")).to eq("10:00")
    expect(request_record.events.count).to eq(2)
    patch execute_bl_house_line_service_request_path(request_record)
    expect(request_record.reload.status).to eq("executed")
    expect(line.reload.status).to eq("revalidado")
  end

  it "rejects an unpaid assignment invoice" do
    payment.destroy!
    sign_in agency_user, scope: :user
    expect { submit_request }.not_to change(BlHouseLineServiceRequest, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("factura de asignación debe estar pagada")
    document = Nokogiri::HTML(response.body)
    expect(document.at_css("[role='alert']").text).to include("factura de asignación debe estar pagada")
    expect(document.at_css("input[name='bl_house_line_service_request[requested_date]']")["value"]).to eq("2026-12-01")
    expect(document.at_css("select[name='bl_house_line_service_request[service_catalog_id]'] option[selected]")["value"]).to eq(catalog.id.to_s)
  end

  it "accepts a paid Lázaro assignment regardless of its catalog name" do
    assignment_catalog.update!(code: "BL-ASIG-LZC", name: "Asignación electrónica Lázaro")
    sign_in agency_user, scope: :user
    expect { submit_request }.to change(BlHouseLineServiceRequest, :count).by(1)
  end

  it "accepts a paid historical reassignment using a container catalog" do
    assignment_catalog.update!(applies_to: "container", name: "Asignacion electronica de carga")
    sign_in agency_user, scope: :user
    expect { submit_request }.to change(BlHouseLineServiceRequest, :count).by(1)
  end

  it "accepts a paid grouped invoice for the Lázaro assignment" do
    assignment_catalog.update!(code: "BL-ASIG-LZC", name: "Asignación electrónica Lázaro")
    payment.destroy!
    grouped = create(:invoice, invoiceable: nil, status: "issued")
    InvoiceServiceLink.create!(invoice: grouped, serviceable: assignment)
    create(:invoice_payment, invoice: grouped, amount: grouped.total)
    sign_in agency_user, scope: :user
    expect { submit_request }.to change(BlHouseLineServiceRequest, :count).by(1)
  end

  it "requires payment of the latest assignment rather than a paid historical assignment" do
    lazaro_catalog = create(:service_catalog, code: "BL-ASIG-LZC", applies_to: "bl_house_line")
    latest = create(:bl_house_line_service, bl_house_line: line, service_catalog: lazaro_catalog)
    latest_invoice = create(:invoice, invoiceable: latest, status: "issued")
    sign_in agency_user, scope: :user
    expect { submit_request }.not_to change(BlHouseLineServiceRequest, :count)
    expect(response.body).to include("factura de asignación debe estar pagada")
    create(:invoice_payment, invoice: latest_invoice, amount: latest_invoice.total)
    expect { submit_request }.to change(BlHouseLineServiceRequest, :count).by(1)
  end

  it "rejects a service that is not for Lázaro" do
    catalog.update!(code: "BL-PMD")
    sign_in agency_user, scope: :user
    expect { submit_request }.not_to change(BlHouseLineServiceRequest, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "rejects requests for a line that is not revalidated or is in another port" do
    sign_in agency_user, scope: :user
    line.update!(status: "activo")
    expect { submit_request }.not_to change(BlHouseLineServiceRequest, :count)
    line.update_column(:status, "revalidado")
    port.update!(code: "MXVER")
    expect { submit_request }.not_to change(BlHouseLineServiceRequest, :count)
  end

  it "shows the date selector but no time selector to the agency" do
    catalog
    sign_in agency_user, scope: :user
    get new_bl_house_line_service_request_path(bl_house_line_id: line.id)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Fecha requerida", catalog.code)
    expect(response.body).not_to include('type="time"')
    document = Nokogiri::HTML(response.body)
    form = document.at_css("form[action='#{bl_house_line_service_requests_path}']")
    expect(form.at_css("input[name='bl_house_line_service_request[bl_house_line_id]']")["value"]).to eq(line.id.to_s)
    expect(form.at_css("select[name='bl_house_line_service_request[service_catalog_id]'][required]")).to be_present
    expect(form.at_css("input[name='bl_house_line_service_request[requested_date]'][required][aria-describedby='requested-date-help']")).to be_present
    expect(document.at_css("#requested-date-help").text).to include("El personal interno asignará la hora.")
    expect(form.at_css("button[type='submit']").text).to include("Enviar solicitud")
    expect(document.css("a[href='#{bl_house_line_path(line)}']").map(&:text).join).to include("Volver a la partida", "Cancelar")
  end

  it "prevents agencies from reviewing requests and changing dispatch directly" do
    sign_in agency_user, scope: :user
    submit_request
    request_record = BlHouseLineServiceRequest.last
    patch approve_bl_house_line_service_request_path(request_record), params: {
      bl_house_line_service_request: { scheduled_date: "2026-12-01", scheduled_time: "09:30" }
    }
    expect(request_record.reload.status).to eq("pending")
    patch bl_house_line_path(line), params: { bl_house_line: { status: "despachado", fecha_despacho: "2026-12-01" } }
    expect(line.reload.status).to eq("revalidado")
  end

  it "does not allow another agency to request a service for the line" do
    sign_in create(:user, role: agency_user.role, entity: create(:entity, :customs_agent)), scope: :user
    expect { submit_request }.not_to change(BlHouseLineServiceRequest, :count)
  end

  it "does not allow manual selection of automatic or inactive catalogs" do
    sign_in agency_user, scope: :user
    catalog.update!(code: "BL-ALMA-LZC")
    expect { submit_request }.not_to change(BlHouseLineServiceRequest, :count)
    catalog.update!(code: "BL-ALM-LZC")
    get new_bl_house_line_service_request_path(bl_house_line_id: line.id)
    expect(response.body).not_to include(catalog.display_name)
    expect { submit_request }.not_to change(BlHouseLineServiceRequest, :count)
    catalog.update!(code: "BL-CODIE-LZC")
    expect { submit_request }.not_to change(BlHouseLineServiceRequest, :count)
    catalog.update!(code: "bl-asig-lzc")
    get new_bl_house_line_service_request_path(bl_house_line_id: line.id)
    expect(response.body).not_to include(catalog.display_name)
    expect { submit_request }.not_to change(BlHouseLineServiceRequest, :count)
    catalog.update!(code: "BL-PMD-LZC", active: false)
    expect { submit_request }.not_to change(BlHouseLineServiceRequest, :count)
  end

  it "keeps a legacy pending storage request pending if the automatic service already exists" do
    sign_in agency_user, scope: :user
    submit_request
    request_record = BlHouseLineServiceRequest.last
    catalog.update!(code: "BL-ALM-LZC")
    create(:bl_house_line_service, bl_house_line: line, service_catalog: catalog)
    sign_out agency_user
    sign_in executive, scope: :user

    expect {
      patch approve_bl_house_line_service_request_path(request_record), params: {
        bl_house_line_service_request: { scheduled_date: "2026-12-01", scheduled_time: "09:30" }
      }
    }.not_to change { line.bl_house_line_services.where(service_catalog: catalog).count }
    expect(request_record.reload.status).to eq("pending")
    expect(flash[:alert]).to include("Ya existe el servicio automático")
  end

  it "blocks a legacy storage request if the historical BL-ALMA service exists" do
    sign_in agency_user, scope: :user
    submit_request
    request_record = BlHouseLineServiceRequest.last
    catalog.update!(code: "BL-ALM-LZC")
    historical_catalog = create(:service_catalog, code: "BL-ALMA", applies_to: "bl_house_line")
    create(:bl_house_line_service, bl_house_line: line, service_catalog: historical_catalog)
    sign_out agency_user
    sign_in executive, scope: :user

    expect {
      patch approve_bl_house_line_service_request_path(request_record), params: {
        bl_house_line_service_request: { scheduled_date: "2026-12-01", scheduled_time: "09:30" }
      }
    }.not_to change { line.bl_house_line_services.where(service_catalog: catalog).count }
    expect(request_record.reload.status).to eq("pending")
    expect(flash[:alert]).to include("Ya existe el servicio automático")
  end

  it "blocks a legacy pending documentary request after dispatch created the service" do
    sign_in agency_user, scope: :user
    submit_request
    request_record = BlHouseLineServiceRequest.last
    catalog.update!(code: "BL-CODIE-LZC")
    line.update!(status: "despachado")
    expect(line.bl_house_line_services.where(service_catalog: catalog).count).to eq(1)
    sign_out agency_user
    sign_in executive, scope: :user

    expect {
      patch approve_bl_house_line_service_request_path(request_record), params: {
        bl_house_line_service_request: { scheduled_date: "2026-12-01", scheduled_time: "09:30" }
      }
    }.not_to change { line.bl_house_line_services.where(service_catalog: catalog).count }
    expect(request_record.reload.status).to eq("pending")
    expect(flash[:alert]).to include("Ya existe el servicio automático")
  end

  it "reuses a previously approved documentary service at dispatch" do
    sign_in agency_user, scope: :user
    submit_request
    request_record = BlHouseLineServiceRequest.last
    catalog.update!(code: "BL-CODIE-LZC")
    sign_out agency_user
    sign_in executive, scope: :user
    patch approve_bl_house_line_service_request_path(request_record), params: {
      bl_house_line_service_request: { scheduled_date: "2026-12-01", scheduled_time: "09:30" }
    }
    expect(request_record.reload.status).to eq("approved")
    expect { line.update!(status: "despachado") }
      .not_to change { line.bl_house_line_services.where(service_catalog: catalog).count }
    expect(request_record.reload.bl_house_line_service).to be_present
  end

  it "preserves a previously requested storage service if a changed date falls within grace" do
    sign_in agency_user, scope: :user
    submit_request
    request_record = BlHouseLineServiceRequest.last
    catalog.update!(code: "BL-ALM-LZC")
    container.update!(fecha_desconsolidacion: Date.new(2026, 3, 20))
    line.update!(fecha_despacho: Time.zone.local(2026, 3, 27))
    sign_out agency_user
    sign_in executive, scope: :user
    patch approve_bl_house_line_service_request_path(request_record), params: {
      bl_house_line_service_request: { scheduled_date: "2026-12-01", scheduled_time: "09:30" }
    }
    service = request_record.reload.bl_house_line_service
    line.update!(status: "despachado")
    line.update!(fecha_despacho: Time.zone.local(2026, 3, 26))
    expect(service.reload).to be_persisted
    expect(request_record.reload.bl_house_line_service_id).to eq(service.id)
  end

  it "keeps a billed service unchanged when an executive reschedules" do
    sign_in agency_user, scope: :user
    submit_request
    request_record = BlHouseLineServiceRequest.last
    sign_out agency_user
    sign_in executive, scope: :user
    patch approve_bl_house_line_service_request_path(request_record), params: {
      bl_house_line_service_request: { scheduled_date: "2026-12-01", scheduled_time: "09:30" }
    }
    service = request_record.reload.bl_house_line_service
    service.update!(factura: "LZC-001")
    patch reschedule_bl_house_line_service_request_path(request_record), params: {
      bl_house_line_service_request: { scheduled_date: "2026-12-02", scheduled_time: "10:00" }
    }
    expect(request_record.reload.scheduled_date).to eq(Date.new(2026, 12, 2))
    expect(service.reload.fecha_programada).to eq(Date.new(2026, 12, 1))
  end

  it "includes the invoice for an approved request in the agency overdue rule" do
    sign_in agency_user, scope: :user
    submit_request
    request_record = BlHouseLineServiceRequest.last
    sign_out agency_user
    sign_in executive, scope: :user
    patch approve_bl_house_line_service_request_path(request_record), params: {
      bl_house_line_service_request: { scheduled_date: "2026-12-01", scheduled_time: "09:30" }
    }
    agency_user.entity.update!(enforce_overdue_payment_rule: true)
    overdue = create(:invoice, invoiceable: request_record.reload.bl_house_line_service, status: "issued", issued_at: 20.days.ago)

    expect(Invoice.for_customs_agent(agency_user.entity_id)).to include(overdue)
    expect(CustomsAgents::RestrictionEvaluatorService.call(customs_agent: agency_user.entity).restricted).to be(true)
  end

  it "includes grouped invoice links in the agency rule and payment recalculation" do
    sign_in agency_user, scope: :user
    submit_request
    request_record = BlHouseLineServiceRequest.last
    sign_out agency_user
    sign_in executive, scope: :user
    patch approve_bl_house_line_service_request_path(request_record), params: {
      bl_house_line_service_request: { scheduled_date: "2026-12-01", scheduled_time: "09:30" }
    }
    service = request_record.reload.bl_house_line_service
    agency_user.entity.update!(enforce_overdue_payment_rule: true)
    grouped = create(:invoice, invoiceable: nil, status: "issued", issued_at: 20.days.ago)
    InvoiceServiceLink.create!(invoice: grouped, serviceable: service)

    expect(Invoice.for_customs_agent(agency_user.entity_id)).to include(grouped)
    expect(InvoicePolicy.new(agency_user, grouped).show?).to be(true)
    expect(CustomsAgents::RestrictionEvaluatorService.call(customs_agent: agency_user.entity).restricted).to be(true)
    sign_out executive
    sign_in agency_user, scope: :user
    get new_customs_agents_payment_evidence_path, params: { invoice_id: grouped.id }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(grouped.id.to_s)
    expect(CustomsAgents::RecalculateAccessRestrictionsJob).to receive(:perform_later).with(customs_agent_id: agency_user.entity_id)
    Facturador::RegisterInvoicePaymentService.call(invoice: grouped, amount: grouped.total, paid_at: Time.current, payment_method: "03")
    expect(CustomsAgents::RestrictionEvaluatorService.call(customs_agent: agency_user.entity).restricted).to be(false)
  end

  it "invoices an approved service using the catalog SAT keys" do
    sign_in agency_user, scope: :user
    submit_request
    request_record = BlHouseLineServiceRequest.last
    sign_out agency_user
    sign_in executive, scope: :user
    patch approve_bl_house_line_service_request_path(request_record), params: {
      bl_house_line_service_request: { scheduled_date: "2026-12-01", scheduled_time: "09:30" }
    }
    receiver = line.client
    create(:fiscal_profile, profileable: receiver)
    create(:address, addressable: receiver, tipo: "matriz")
    issuer = create(:entity, :customs_agent, :with_fiscal_profile, :with_address).reload
    receiver.reload
    allow(Facturador::Config).to receive_messages(enabled?: true, manual_actions_enabled?: true, issuer_entity: issuer)
    result = Facturador::IssueGroupedServicesService.call(serviceables: [ request_record.reload.bl_house_line_service ], actor: executive)

    expect(result.success?).to be(true), result.error_message
    item = result.invoice.invoice_line_items.first
    expect(item.sat_clave_prod_serv).to eq(catalog.sat_clave_prod_serv)
    expect(item.sat_clave_unidad).to eq(catalog.sat_clave_unidad)
    expect(result.invoice.invoice_service_links.count).to eq(1)
  end

  it "does not expose a grouped invoice containing services belonging to another agency" do
    sign_in agency_user, scope: :user
    submit_request
    request_record = BlHouseLineServiceRequest.last
    sign_out agency_user
    sign_in executive, scope: :user
    patch approve_bl_house_line_service_request_path(request_record), params: {
      bl_house_line_service_request: { scheduled_date: "2026-12-01", scheduled_time: "09:30" }
    }
    service = request_record.reload.bl_house_line_service
    other_line = create(:bl_house_line, client: line.client)
    other_service = create(:bl_house_line_service, bl_house_line: other_line, billed_to_entity: line.client)
    allow(Facturador::Config).to receive_messages(enabled?: true, manual_actions_enabled?: true)
    result = Facturador::IssueGroupedServicesService.call(serviceables: [ service, other_service ])
    expect(result.error_message).to eq("Los servicios solicitados deben facturarse con partidas de la misma agencia.")

    grouped = create(:invoice, invoiceable: nil, status: "issued")
    InvoiceServiceLink.create!(invoice: grouped, serviceable: service)
    InvoiceServiceLink.create!(invoice: grouped, serviceable: other_service)
    expect(InvoicePolicy.new(agency_user, grouped).show?).to be(false)
  end

  it "rejects submissions when a different invoice makes the agency overdue" do
    agency_user.entity.update!(enforce_overdue_payment_rule: true)
    create(:invoice, status: "issued", issued_at: 20.days.ago, customs_agent: agency_user.entity)
    sign_in agency_user, scope: :user
    expect { submit_request }.not_to change(BlHouseLineServiceRequest, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "does not allow deleting or changing the catalog of an approved requested service" do
    sign_in agency_user, scope: :user
    submit_request
    request_record = BlHouseLineServiceRequest.last
    sign_out agency_user
    sign_in executive, scope: :user
    patch approve_bl_house_line_service_request_path(request_record), params: {
      bl_house_line_service_request: { scheduled_date: "2026-12-01", scheduled_time: "09:30" }
    }
    service = request_record.reload.bl_house_line_service
    expect(service.update(service_catalog: assignment_catalog)).to be(false)
    expect(service.destroy).to be(false)
  end

  it "renders the administration view and exports all filtered rows" do
    sign_in agency_user, scope: :user
    26.times { submit_request }
    sign_out agency_user
    sign_in executive, scope: :user
    get bl_house_line_service_requests_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Solicitudes de Servicio", "26 resultados")
    document = Nokogiri::HTML(response.body)
    expect(document.css("table tbody[data-request-id]").size).to eq(25)
    expect(document.css("article[data-request-id]").size).to eq(25)
    request_record = BlHouseLineServiceRequest.last
    [ "desktop", "mobile" ].each do |prefix|
      expect(document.at_css("##{prefix}_request_#{request_record.id}_date")["value"]).to eq("2026-12-01")
      expect(document.at_css("##{prefix}_request_#{request_record.id}_time")["required"]).to be_present
      expect(document.at_css("##{prefix}_request_#{request_record.id}_rejection")["required"]).to be_present
    end
    expect(document.css("form[action='#{approve_bl_house_line_service_request_path(request_record)}']").size).to eq(2)
    expect(document.css("form[action='#{reject_bl_house_line_service_request_path(request_record)}']").size).to eq(2)
    get bl_house_line_service_requests_path(format: :xlsx), params: { status: "pending" }
    expect(response).to have_http_status(:ok)
    Zip::File.open_buffer(response.body) do |zip|
      sheet = Nokogiri::XML(zip.read("xl/worksheets/sheet1.xml"))
      expect(sheet.xpath("//*[local-name()='row']").size).to eq(27)
      header = sheet.xpath("//*[local-name()='row'][1]//*[local-name()='t']").map(&:text)
      expect(header).to include("Cantidad", "Peso (kg)", "Volumen (m³)", "Embalaje")
      expect(header).not_to include("Solicitada", "Fecha requerida", "Ejecución")
    end
    get bl_house_line_service_requests_path(format: :xlsx), params: { date_type: "requested_date", start_date: "2026-12-02" }
    Zip::File.open_buffer(response.body) do |zip|
      sheet = Nokogiri::XML(zip.read("xl/worksheets/sheet1.xml"))
      expect(sheet.xpath("//*[local-name()='row']").size).to eq(1)
    end
    get bl_house_line_service_requests_path, params: { date_type: "invalid" }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "renders and exports a populated list without Bullet warnings" do
    sign_in agency_user, scope: :user
    3.times { submit_request }
    sign_out agency_user
    sign_in executive, scope: :user

    previous_enable = Bullet.enable?
    previous_raise = UniformNotifier::Raise.active?
    Bullet.enable = true
    Bullet.raise = true
    begin
      [
        [ bl_house_line_service_requests_path, {} ],
        [ bl_house_line_service_requests_path, { blhouse: line.blhouse, container: container.number } ],
        [ bl_house_line_service_requests_path(format: :xlsx), {} ]
      ].each do |path, filters|
        Bullet.start_request
        begin
          get path, params: filters
          expect(response).to have_http_status(:ok)
          Bullet.perform_out_of_channel_notifications if Bullet.notification?
        ensure
          Bullet.end_request
        end
      end
    ensure
      UniformNotifier.raise = previous_raise
      Bullet.enable = previous_enable
    end
  end

  it "shows the empty state and keeps the selected filters for export" do
    sign_in executive, scope: :user
    get bl_house_line_service_requests_path, params: { status: "approved", blhouse: "NO-RESULT" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No se encontraron solicitudes")
    document = Nokogiri::HTML(response.body)
    export_link = document.css("a").find { |link| link.text.include?("Exportar XLSX") }
    expect(export_link["href"]).to include("status=approved", "blhouse=NO-RESULT")
  end

  it "offers only active Lázaro line services in the service filter" do
    lazaro_catalog = catalog
    automatic_catalog = create(:service_catalog, code: "BL-ALMA-LZC", applies_to: "bl_house_line")
    lowercase_catalog = create(:service_catalog, code: "BL-OTRO-lzc", applies_to: "bl_house_line")
    other_port_catalog = create(:service_catalog, code: "BL-PMD-ATM", applies_to: "bl_house_line")
    inactive_catalog = create(:service_catalog, code: "BL-INACTIVE-LZC", applies_to: "bl_house_line", active: false)
    container_catalog = create(:service_catalog, code: "CONT-LZC", applies_to: "container")
    sign_in executive, scope: :user

    get bl_house_line_service_requests_path, params: { service_catalog_id: lazaro_catalog.id }

    document = Nokogiri::HTML(response.body)
    options = document.css("select[name='service_catalog_id'] option")
    expect(options.map { |option| option["value"] }).to contain_exactly("",
      lazaro_catalog.id.to_s, automatic_catalog.id.to_s, lowercase_catalog.id.to_s)
    expect(options.map { |option| option["value"] }).not_to include(other_port_catalog.id.to_s,
      inactive_catalog.id.to_s, container_catalog.id.to_s)
    expect(document.at_css("select[name='service_catalog_id'] option[selected]")["value"]).to eq(lazaro_catalog.id.to_s)
    expect(document.text).to include("Servicio: #{lazaro_catalog.display_name}")
  end

  it "filters requests and their export by the selected Lázaro service" do
    sign_in agency_user, scope: :user
    submit_request
    first_request = BlHouseLineServiceRequest.last
    other_catalog = create(:service_catalog, code: "BL-OTHER-LZC", applies_to: "bl_house_line")
    post bl_house_line_service_requests_path, params: {
      bl_house_line_service_request: { bl_house_line_id: line.id, service_catalog_id: other_catalog.id, requested_date: "2026-12-01" }
    }
    second_request = BlHouseLineServiceRequest.last
    expect(second_request.id).not_to eq(first_request.id)
    sign_out agency_user
    sign_in executive, scope: :user

    get bl_house_line_service_requests_path, params: { service_catalog_id: catalog.id }
    document = Nokogiri::HTML(response.body)
    expect(document.css("table tbody[data-request-id]").map { |row| row["data-request-id"] }).to eq([ first_request.id.to_s ])
    export_link = document.css("a").find { |link| link.text.include?("Exportar XLSX") }
    expect(export_link["href"]).to include("service_catalog_id=#{catalog.id}")

    get bl_house_line_service_requests_path(format: :xlsx), params: { service_catalog_id: catalog.id }
    Zip::File.open_buffer(response.body) do |zip|
      sheet = Nokogiri::XML(zip.read("xl/worksheets/sheet1.xml"))
      expect(sheet.xpath("//*[local-name()='row']").size).to eq(2)
    end
  end

  it "shows applied filters with readable labels and a link to clear them" do
    sign_in executive, scope: :user
    get bl_house_line_service_requests_path, params: {
      status: "approved", service_catalog_id: catalog.id, customs_agent_id: agency_user.entity_id,
      blhouse: "BL-123", container: "CONT-456", date_type: "scheduled_date",
      start_date: "2026-12-01", end_date: "2026-12-31", page: 2
    }

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.text).to include("Filtros activos:", "Estado: Autorizada", "Servicio: #{catalog.display_name}",
      "Agencia: #{agency_user.entity.name}", "BL House: BL-123", "Contenedor: CONT-456",
      "Fecha programada: desde 2026-12-01 hasta 2026-12-31")
    clear_link = document.css("a").find { |link| link.text.include?("Quitar filtros") }
    expect(clear_link["href"]).to eq(bl_house_line_service_requests_path)
  end

  it "only shows an active date filter when a date boundary is supplied" do
    sign_in executive, scope: :user
    get bl_house_line_service_requests_path, params: { date_type: "scheduled_date", page: 2 }
    expect(response.body).not_to include("Filtros activos:", "Quitar filtros")

    get bl_house_line_service_requests_path, params: { end_date: "2026-12-31" }
    expect(Nokogiri::HTML(response.body).text).to include("Fecha requerida: hasta 2026-12-31")

    get bl_house_line_service_requests_path, params: { date_type: "created_at", start_date: "2026-12-01" }
    expect(Nokogiri::HTML(response.body).text).to include("Fecha de solicitud: desde 2026-12-01")
  end

  it "renders reprogramming and execution controls for approved requests in both layouts" do
    sign_in agency_user, scope: :user
    submit_request
    request_record = BlHouseLineServiceRequest.last
    sign_out agency_user
    sign_in executive, scope: :user
    patch approve_bl_house_line_service_request_path(request_record), params: {
      bl_house_line_service_request: { scheduled_date: "2026-12-02", scheduled_time: "09:30" }
    }

    get bl_house_line_service_requests_path
    document = Nokogiri::HTML(response.body)
    expect(document.css("form[action='#{reschedule_bl_house_line_service_request_path(request_record)}']").size).to eq(2)
    execution_forms = document.css("form[action='#{execute_bl_house_line_service_request_path(request_record)}']")
    expect(execution_forms.size).to eq(2)
    execution_forms.each do |form|
      expect(form["data-turbo-confirm"]).to include("¿Confirmas la ejecución", "Solicitud: ##{request_record.id}",
        catalog.display_name, line.blhouse, agency_user.entity.name, "2026-12-02", "09:30",
        "pasará a Ejecutada", "momento de la confirmación", "no cambia el estado de la partida",
        "no se puede deshacer desde esta pantalla")
      expect(form.at_css("input[name='_method']")["value"]).to eq("patch")
    end
    [ "desktop", "mobile" ].each do |prefix|
      expect(document.at_css("##{prefix}_request_#{request_record.id}_date")["value"]).to eq("2026-12-02")
      expect(document.at_css("##{prefix}_request_#{request_record.id}_time")["value"]).to eq("09:30")
    end
  end
end
