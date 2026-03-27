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

  it "creates a container successfully from new form" do
    consolidator = create(:entity, :consolidator, name: "Consolidador Creacion")
    shipping_line = create(:shipping_line, name: "Linea Creacion")
    vessel = create(:vessel, name: "Buque Creacion")

    destination_port = create(:port, :manzanillo)
    voyage = create(:voyage, vessel: vessel, destination_port: destination_port, viaje: "CREA-001")

    origin_port = create(:port, name: "Puerto Origen Creacion", code: "MXORC")

    visit new_container_path

    fill_in "container_number", with: "ABCD1234567"
    fill_in "container_type_size", with: "40HC"
    fill_in "container_bl_master", with: "BLM-CR-001"
    fill_in "container_archivo_nr", with: "NR-CR-001"
    fill_in "container_sello", with: "SELLO123"
    fill_in "container_ejecutivo", with: "Usuario QA"

    consolidator_input = find_field("consolidator_search")
    consolidator_input.fill_in(with: "Consolidador Crea")
    expect(page).to have_css("button[data-index='0']", text: consolidator.name)
    consolidator_input.send_keys(:enter)

    shipping_input = find_field("shipping_line_search")
    shipping_input.fill_in(with: "Linea Crea")
    expect(page).to have_css("button[data-index='0']", text: shipping_line.name)
    shipping_input.send_keys(:enter)

    vessel_input = find_field("vessel_search")
    vessel_input.fill_in(with: "Buque Crea")
    expect(page).to have_css("button[data-index='0']", text: vessel.name)
    vessel_input.send_keys(:enter)

    expect(page).to have_css("#container_voyage_id option", text: "CREA-001")
    find("#container_voyage_id", visible: :all)
      .find("option[value='#{voyage.id}']", visible: :all)
      .select_option

    origin_port_input = find_field("origin_port_search")
    origin_port_input.fill_in(with: "Origen Crea")
    expect(page).to have_css("button[data-index='0']", text: origin_port.display_name)
    origin_port_input.send_keys(:enter)

    select "CONTECON", from: "container_recinto"

    before_count = Container.count
    click_button "Crear Contenedor"

    expect(page).to have_text("Contenedor creado exitosamente.")
    expect(Container.count).to eq(before_count + 1)

    created_container = Container.order(:id).last
    expect(created_container.number).to eq("ABCD1234567")
    expect(created_container.consolidator_entity_id).to eq(consolidator.id)
    expect(created_container.shipping_line_id).to eq(shipping_line.id)
    expect(created_container.vessel_id).to eq(vessel.id)
    expect(created_container.voyage_id).to eq(voyage.id)
    expect(created_container.origin_port_id).to eq(origin_port.id)
    expect(created_container.recinto).to eq("CONTECON")
  end

  it "creates Veracruz then Manzanillo containers in the same browser session" do
    consolidator = create(:entity, :consolidator, name: "Consolidador Secuencia")
    shipping_line = create(:shipping_line, name: "Linea Secuencia")

    vessel_veracruz = create(:vessel, name: "Buque Veracruz Secuencia")
    vessel_manzanillo = create(:vessel, name: "Buque Manzanillo Secuencia")

    veracruz_port = create(:port, :veracruz)
    manzanillo_port = create(:port, :manzanillo)

    veracruz_voyage = create(:voyage, vessel: vessel_veracruz, destination_port: veracruz_port, viaje: "VER-S01")
    manzanillo_voyage = create(:voyage, vessel: vessel_manzanillo, destination_port: manzanillo_port, viaje: "MZO-S01")

    origin_port = create(:port, name: "Puerto Origen Secuencia", code: "MXSEQ")

    visit new_container_path

    fill_in "container_number", with: "SEQA1234567"
    fill_in "container_type_size", with: "40HC"
    fill_in "container_bl_master", with: "BLM-SQ-A"
    fill_in "container_archivo_nr", with: "NR-SQ-A"
    fill_in "container_sello", with: "SELLOSQA"
    fill_in "container_ejecutivo", with: "Usuario Seq A"

    consolidator_input = find_field("consolidator_search")
    consolidator_input.fill_in(with: "Consolidador Sec")
    expect(page).to have_css("button[data-index='0']", text: consolidator.name)
    consolidator_input.send_keys(:enter)

    shipping_input = find_field("shipping_line_search")
    shipping_input.fill_in(with: "Linea Sec")
    expect(page).to have_css("button[data-index='0']", text: shipping_line.name)
    shipping_input.send_keys(:enter)

    vessel_input = find_field("vessel_search")
    vessel_input.fill_in(with: "Veracruz Sec")
    expect(page).to have_css("button[data-index='0']", text: vessel_veracruz.name)
    vessel_input.send_keys(:enter)

    expect(page).to have_css("#container_voyage_id option", text: "VER-S01")
    find("#container_voyage_id", visible: :all)
      .find("option[value='#{veracruz_voyage.id}']", visible: :all)
      .select_option

    origin_port_input = find_field("origin_port_search")
    origin_port_input.fill_in(with: "Origen Sec")
    expect(page).to have_css("button[data-index='0']", text: origin_port.display_name)
    origin_port_input.send_keys(:enter)

    select "CICE", from: "container_recinto"
    select "CICE", from: "container_almacen"

    click_button "Crear Contenedor"
    expect(page).to have_text("Contenedor creado exitosamente.")

    visit new_container_path

    fill_in "container_number", with: "SEQB1234567"
    fill_in "container_type_size", with: "40HC"
    fill_in "container_bl_master", with: "BLM-SQ-B"
    fill_in "container_archivo_nr", with: "NR-SQ-B"
    fill_in "container_sello", with: "SELLOSQB"
    fill_in "container_ejecutivo", with: "Usuario Seq B"

    consolidator_input = find_field("consolidator_search")
    consolidator_input.fill_in(with: "Consolidador Sec")
    expect(page).to have_css("button[data-index='0']", text: consolidator.name)
    consolidator_input.send_keys(:enter)

    shipping_input = find_field("shipping_line_search")
    shipping_input.fill_in(with: "Linea Sec")
    expect(page).to have_css("button[data-index='0']", text: shipping_line.name)
    shipping_input.send_keys(:enter)

    vessel_input = find_field("vessel_search")
    vessel_input.fill_in(with: "Manzanillo Sec")
    expect(page).to have_css("button[data-index='0']", text: vessel_manzanillo.name)
    vessel_input.send_keys(:enter)

    expect(page).to have_css("#container_voyage_id option", text: "MZO-S01")
    find("#container_voyage_id", visible: :all)
      .find("option[value='#{manzanillo_voyage.id}']", visible: :all)
      .select_option

    origin_port_input = find_field("origin_port_search")
    origin_port_input.fill_in(with: "Origen Sec")
    expect(page).to have_css("button[data-index='0']", text: origin_port.display_name)
    origin_port_input.send_keys(:enter)

    select "CONTECON", from: "container_recinto"

    before_count = Container.count
    click_button "Crear Contenedor"

    expect(page).to have_text("Contenedor creado exitosamente.")
    expect(Container.count).to eq(before_count + 1)

    created_container = Container.order(:id).last
    expect(created_container.number).to eq("SEQB1234567")
    expect(created_container.voyage_id).to eq(manzanillo_voyage.id)
    expect(created_container.recinto).to eq("CONTECON")
  end

  it "creates Manzanillo then Veracruz containers in the same browser session" do
    consolidator = create(:entity, :consolidator, name: "Consolidador Secuencia")
    shipping_line = create(:shipping_line, name: "Linea Secuencia")

    vessel_manzanillo = create(:vessel, name: "Buque Manzanillo Secuencia")
    vessel_veracruz = create(:vessel, name: "Buque Veracruz Secuencia")

    manzanillo_port = create(:port, :manzanillo)
    veracruz_port = create(:port, :veracruz)

    manzanillo_voyage = create(:voyage, vessel: vessel_manzanillo, destination_port: manzanillo_port, viaje: "MZO-S01")
    veracruz_voyage = create(:voyage, vessel: vessel_veracruz, destination_port: veracruz_port, viaje: "VER-S01")

    origin_port = create(:port, name: "Puerto Origen Secuencia", code: "MXSEQ")

    visit new_container_path

    fill_in "container_number", with: "SQMA1234567"
    fill_in "container_type_size", with: "40HC"
    fill_in "container_bl_master", with: "BLM-SQ-MA"
    fill_in "container_archivo_nr", with: "NR-SQ-MA"
    fill_in "container_sello", with: "SELLOSQMA"
    fill_in "container_ejecutivo", with: "Usuario Seq MA"

    consolidator_input = find_field("consolidator_search")
    consolidator_input.fill_in(with: "Consolidador Sec")
    expect(page).to have_css("button[data-index='0']", text: consolidator.name)
    consolidator_input.send_keys(:enter)

    shipping_input = find_field("shipping_line_search")
    shipping_input.fill_in(with: "Linea Sec")
    expect(page).to have_css("button[data-index='0']", text: shipping_line.name)
    shipping_input.send_keys(:enter)

    vessel_input = find_field("vessel_search")
    vessel_input.fill_in(with: "Manzanillo Sec")
    expect(page).to have_css("button[data-index='0']", text: vessel_manzanillo.name)
    vessel_input.send_keys(:enter)

    expect(page).to have_css("#container_voyage_id option", text: "MZO-S01")
    find("#container_voyage_id", visible: :all)
      .find("option[value='#{manzanillo_voyage.id}']", visible: :all)
      .select_option

    origin_port_input = find_field("origin_port_search")
    origin_port_input.fill_in(with: "Origen Sec")
    expect(page).to have_css("button[data-index='0']", text: origin_port.display_name)
    origin_port_input.send_keys(:enter)

    select "CONTECON", from: "container_recinto"

    click_button "Crear Contenedor"
    expect(page).to have_text("Contenedor creado exitosamente.")

    visit new_container_path

    fill_in "container_number", with: "SQVE1234567"
    fill_in "container_type_size", with: "40HC"
    fill_in "container_bl_master", with: "BLM-SQ-VE"
    fill_in "container_archivo_nr", with: "NR-SQ-VE"
    fill_in "container_sello", with: "SELLOSQVE"
    fill_in "container_ejecutivo", with: "Usuario Seq VE"

    consolidator_input = find_field("consolidator_search")
    consolidator_input.fill_in(with: "Consolidador Sec")
    expect(page).to have_css("button[data-index='0']", text: consolidator.name)
    consolidator_input.send_keys(:enter)

    shipping_input = find_field("shipping_line_search")
    shipping_input.fill_in(with: "Linea Sec")
    expect(page).to have_css("button[data-index='0']", text: shipping_line.name)
    shipping_input.send_keys(:enter)

    vessel_input = find_field("vessel_search")
    vessel_input.fill_in(with: "Veracruz Sec")
    expect(page).to have_css("button[data-index='0']", text: vessel_veracruz.name)
    vessel_input.send_keys(:enter)

    expect(page).to have_css("#container_voyage_id option", text: "VER-S01")
    find("#container_voyage_id", visible: :all)
      .find("option[value='#{veracruz_voyage.id}']", visible: :all)
      .select_option

    origin_port_input = find_field("origin_port_search")
    origin_port_input.fill_in(with: "Origen Sec")
    expect(page).to have_css("button[data-index='0']", text: origin_port.display_name)
    origin_port_input.send_keys(:enter)

    select "CICE", from: "container_recinto"
    select "CICE", from: "container_almacen"

    before_count = Container.count
    click_button "Crear Contenedor"

    expect(page).to have_text("Contenedor creado exitosamente.")
    expect(Container.count).to eq(before_count + 1)

    created_container = Container.order(:id).last
    expect(created_container.number).to eq("SQVE1234567")
    expect(created_container.voyage_id).to eq(veracruz_voyage.id)
    expect(created_container.recinto).to eq("CICE")
  end

  it "resolves autocomplete ids from exact text on blur" do
    consolidator = create(:entity, :consolidator, name: "Consolidador Blur Exact")
    shipping_line = create(:shipping_line, name: "Linea Blur Exact")
    vessel = create(:vessel, name: "Buque Blur Exact")
    destination_port = create(:port, :veracruz)
    voyage = create(:voyage, vessel: vessel, destination_port: destination_port, viaje: "BLR-001")
    origin_port = create(:port, name: "Puerto Blur Exact", code: "MXBLR")

    visit new_container_path

    fill_in "container_number", with: "BLUR1234567"
    fill_in "container_type_size", with: "40HC"
    fill_in "container_bl_master", with: "BLM-BLR-001"
    fill_in "container_archivo_nr", with: "NR-BLR-001"
    fill_in "container_sello", with: "SELLOBLR"
    fill_in "container_ejecutivo", with: "Usuario Blur"

    fill_in "consolidator_search", with: consolidator.name
    expect(page).to have_css("button[data-index='0']", text: consolidator.name)
    find_field("shipping_line_search").click

    fill_in "shipping_line_search", with: shipping_line.name
    expect(page).to have_css("button[data-index='0']", text: shipping_line.name)
    find_field("vessel_search").click

    fill_in "vessel_search", with: vessel.name
    expect(page).to have_css("button[data-index='0']", text: vessel.name)
    find_field("origin_port_search").click

    expect(page).to have_css("#container_voyage_id option", text: "BLR-001")
    find("#container_voyage_id", visible: :all)
      .find("option[value='#{voyage.id}']", visible: :all)
      .select_option

    origin_port_input = find_field("origin_port_search")
    origin_port_input.fill_in(with: "Blur Exact")
    expect(page).to have_css("button[data-index='0']", text: origin_port.display_name)
    origin_port_input.send_keys(:enter)

    expect(find("#container_consolidator_entity_id", visible: :all).value).to eq(consolidator.id.to_s)
    expect(find("#container_shipping_line_id", visible: :all).value).to eq(shipping_line.id.to_s)
    expect(find("#container_vessel_id", visible: :all).value).to eq(vessel.id.to_s)
    expect(find("#container_origin_port_id", visible: :all).value).to eq(origin_port.id.to_s)

    select "CICE", from: "container_recinto"
    select "CICE", from: "container_almacen"

    click_button "Crear Contenedor"
    expect(page).to have_text("Contenedor creado exitosamente.")
  end
end
