require "rails_helper"

RSpec.describe "Containers autocomplete", type: :system do
  let(:user) { create(:user, :admin) }

  before do
    driven_by(:selenium_chrome_headless, screen_size: [ 1400, 1400 ])
    login_as(user, scope: :user)
  end

  it "autoloads voyage after selecting vessel from autocomplete" do
    selected_vessel = create(:vessel, name: "Buque Autocomplete")
    other_vessel = create(:vessel, name: "Buque No Seleccionado")

    selected_port = create(:port, name: "Puerto Seleccionado", code: "MXSEL")
    other_port = create(:port, name: "Puerto Otro", code: "MXOTR")

    selected_voyage = create(:voyage, vessel: selected_vessel, destination_port: selected_port, viaje: "AUTO-001")
    create(:voyage, vessel: other_vessel, destination_port: other_port, viaje: "OTRO-001")

    visit new_container_path

    vessel_input = find_field("vessel_search")
    vessel_input.fill_in(with: "Buque Auto")

    expect(page).to have_css("button[data-index='0']", text: selected_vessel.name)
    vessel_input.send_keys(:enter)

    expect(page).to have_field("vessel_search", with: selected_vessel.name)

    hidden_vessel = find("#container_vessel_id", visible: :all)
    expect(hidden_vessel.value).to eq(selected_vessel.id.to_s)

    expect(page).to have_css("#container_voyage_id option", text: "AUTO-001")
    expect(page).not_to have_css("#container_voyage_id option", text: "OTRO-001")

    voyage_select = find("#container_voyage_id", visible: :all)
    expect(voyage_select.value).to eq(selected_voyage.id.to_s)
  end

  it "autoloads the most recent voyage for the selected vessel" do
    selected_vessel = create(:vessel, name: "Buque Multi Viaje")
    selected_port = create(:port, name: "Puerto Reciente", code: "MXREC")

    older_voyage = create(:voyage, vessel: selected_vessel, destination_port: selected_port, viaje: "VIEJO-001")
    recent_voyage = create(:voyage, vessel: selected_vessel, destination_port: selected_port, viaje: "NUEVO-001")

    visit new_container_path

    vessel_input = find_field("vessel_search")
    vessel_input.fill_in(with: "Buque Multi")

    expect(page).to have_css("button[data-index='0']", text: selected_vessel.name)
    vessel_input.send_keys(:enter)

    expect(page).to have_css("#container_voyage_id option", text: "NUEVO-001")
    expect(page).not_to have_css("#container_voyage_id option", text: "VIEJO-001")

    voyage_select = find("#container_voyage_id", visible: :all)
    expect(voyage_select.value).to eq(recent_voyage.id.to_s)
    expect(voyage_select.value).not_to eq(older_voyage.id.to_s)
  end

  it "selects consolidator from autocomplete and sets consolidator id" do
    selected_consolidator = create(:entity, :consolidator, name: "Consolidador Alpha")
    create(:entity, :consolidator, name: "Consolidador Beta")

    visit new_container_path

    consolidator_input = find_field("consolidator_search")
    consolidator_input.fill_in(with: "Consolidador Al")

    expect(page).to have_css("button[data-index='0']", text: selected_consolidator.name)
    consolidator_input.send_keys(:enter)

    expect(page).to have_field("consolidator_search", with: selected_consolidator.name)

    hidden_consolidator = find("#container_consolidator_entity_id", visible: :all)
    expect(hidden_consolidator.value).to eq(selected_consolidator.id.to_s)
  end

  it "uses selected consolidator as default billed_to for new services" do
    selected_consolidator = create(:entity, :consolidator, name: "Consolidador Servicios")

    visit new_container_path

    consolidator_input = find_field("consolidator_search")
    consolidator_input.fill_in(with: "Consolidador Serv")
    expect(page).to have_css("button[data-index='0']", text: selected_consolidator.name)
    consolidator_input.send_keys(:enter)

    click_button "Agregar Servicio"

    service_card = first("#services-container .service-card")
    billed_to_select = service_card.find("select.js-billed-to-entity-select", visible: :all)

    expect(billed_to_select.value).to eq(selected_consolidator.id.to_s)
  end

  it "selects origin port from autocomplete and sets origin_port_id" do
    selected_port = create(:port, name: "Puerto de Origen Alpha", code: "MXALP")
    create(:port, name: "Puerto de Origen Beta", code: "MXBET")

    visit new_container_path

    origin_port_input = find_field("origin_port_search")
    origin_port_input.fill_in(with: "Origen Alp")

    expect(page).to have_css("button[data-index='0']", text: selected_port.display_name)
    origin_port_input.send_keys(:enter)

    expect(page).to have_field("origin_port_search", with: selected_port.display_name)

    hidden_origin_port = find("#container_origin_port_id", visible: :all)
    expect(hidden_origin_port.value).to eq(selected_port.id.to_s)
  end
end
