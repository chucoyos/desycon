require "rails_helper"

RSpec.describe "Confirmación de ejecución de solicitudes", type: :system do
  it "only executes the request after the user accepts the confirmation" do
    driven_by(:selenium_chrome_headless, screen_size: [ 800, 1000 ])
    agency_user = create(:user, :customs_broker)
    executive = create(:user, :executive)
    port = create(:port, name: "Lázaro", code: "MXLZC", country_code: "MX")
    voyage = create(:voyage, destination_port: port)
    container = create(:container, voyage: voyage, recinto: "APM TERMINALS", almacen: "UTTSA RECINTO 173")
    line = create(:bl_house_line, container: container, customs_agent: agency_user.entity, status: "revalidado")
    catalog = create(:service_catalog, code: "BL-PMD-LZC", applies_to: "bl_house_line")
    assignment_catalog = create(:service_catalog, code: "BL-ASIG", name: "Asignación electrónica de carga", applies_to: "bl_house_line")
    assignment = create(:bl_house_line_service, bl_house_line: line, service_catalog: assignment_catalog)
    invoice = create(:invoice, invoiceable: assignment, status: "issued")
    create(:invoice_payment, invoice: invoice, amount: invoice.total)
    service_request = BlHouseLineServiceRequest.create!(
      bl_house_line: line, service_catalog: catalog, requester: agency_user,
      customs_agent: agency_user.entity, requested_date: Date.new(2026, 12, 1)
    )
    service_request.approve!(actor: executive, date: "2026-12-02", time: "09:30", notes: "")

    login_as(executive, scope: :user)
    visit bl_house_line_service_requests_path
    within("article[data-request-id='#{service_request.id}']") do
      find("summary", text: "Gestionar solicitud").click
      message = dismiss_confirm { click_button "Confirmar ejecución" }
      expect(message).to include(catalog.display_name, line.blhouse, "2026-12-02", "09:30")
      expect(service_request.reload.status).to eq("approved")
      expect(service_request.events.where(action: "executed")).not_to exist

      accept_confirm { click_button "Confirmar ejecución" }
    end
    expect(page).to have_text("Solicitud actualizada.")
    expect(service_request.reload.status).to eq("executed")
    expect(service_request.events.where(action: "executed").count).to eq(1)
    expect(line.reload.status).to eq("revalidado")
  end
end
