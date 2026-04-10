require 'rails_helper'

RSpec.describe "Containers", type: :request do
  let(:user) { create(:user, :admin) }
  let(:consolidator_entity) { create(:entity, :consolidator) }
  let(:shipping_line) { create(:shipping_line) }

  let(:valid_attributes) {
    {
      number: "CONT001234",
      tipo_maniobra: "importacion",
      consolidator_entity_id: consolidator_entity.id,
      shipping_line_id: shipping_line.id,
      status: "activo"
    }
  }

  describe "GET /containers" do
    before { sign_in user, scope: :user }

    it "shows only recent containers by default (last 60 days)" do
      recent_container = create(:container, number: "ABCD1234501")
      old_container = create(:container, number: "ABCD1234502")
      old_container.update_column(:created_at, 75.days.ago)

      get containers_url

      expect(response).to be_successful
      expect(response.body).to include(recent_container.number)
      expect(response.body).not_to include(old_container.number)
    end

    it "includes older containers when explicit date range is provided" do
      old_container = create(:container, number: "ABCD1234503")
      old_container.update_column(:created_at, 75.days.ago)

      get containers_url, params: {
        start_date: 90.days.ago.to_date.to_s,
        end_date: Date.current.to_s
      }

      expect(response).to be_successful
      expect(response.body).to include(old_container.number)
      expect(response.body).to include("Filtros activos:")
    end

    it "hides create/edit/destroy actions for tramitador users" do
      tramitador = create(:user, :tramitador)
      container = create(:container, number: "TRAM1234567")
      sign_in tramitador, scope: :user

      get containers_url

      expect(response).to be_successful
      expect(response.body).to include(container.number)
      expect(response.body).not_to include("Nuevo Contenedor")
      expect(response.body).not_to include(edit_container_path(container))
      expect(response.body).not_to include("Eliminar")
    end

    it "filters by consolidator" do
      selected_consolidator = create(:entity, :consolidator, name: "Consolidador Uno")
      other_consolidator = create(:entity, :consolidator, name: "Consolidador Dos")

      selected_container = create(:container, number: "ABCD1234511", consolidator_entity: selected_consolidator)
      other_container = create(:container, number: "ABCD1234512", consolidator_entity: other_consolidator)

      get containers_url, params: { consolidator_id: selected_consolidator.id }

      expect(response).to be_successful
      expect(response.body).to include(selected_container.number)
      expect(response.body).not_to include(other_container.number)
      expect(response.body).to include("Consolidador: #{selected_consolidator.name}")
    end

    it "filters by bl master" do
      selected_container = create(:container, number: "ABCD1234513", bl_master: "BLM-001-TEST")
      other_container = create(:container, number: "ABCD1234514", bl_master: "BLM-XYZ-999")

      get containers_url, params: { bl_master: "001" }

      expect(response).to be_successful
      expect(response.body).to include(selected_container.number)
      expect(response.body).not_to include(other_container.number)
      expect(response.body).to include("BL Master: 001")
    end

    it "filters by shipping line" do
      selected_line = create(:shipping_line, iso_code: "SEL")
      other_line = create(:shipping_line, iso_code: "OTH")

      selected_container = create(:container, number: "ABCD1234515", shipping_line: selected_line)
      other_container = create(:container, number: "ABCD1234516", shipping_line: other_line)

      get containers_url, params: { shipping_line_id: selected_line.id }

      expect(response).to be_successful
      expect(response.body).to include(selected_container.number)
      expect(response.body).not_to include(other_container.number)
      expect(response.body).to include("Línea: #{selected_line.iso_code}")
    end
  end

  describe "GET /containers/:id" do
    it "renders a successful response" do
      sign_in user, scope: :user
      container = create(:container)
      get container_url(container)
      expect(response).to be_successful
    end

    it "displays associated bl_house_lines" do
      sign_in user, scope: :user
      container = create(:container)
      bl_house_line = create(:bl_house_line, container: container)

      get container_url(container)
      expect(response).to be_successful
      expect(response.body).to include("Partidas")
      expect(response.body).to include(bl_house_line.partida.to_s)
    end

    it "shows create new partida link" do
      sign_in user, scope: :user
      container = create(:container)
      get container_url(container)
      expect(response).to be_successful
      expect(response.body).to include("Nueva Partida")
      expect(response.body).to include(new_bl_house_line_path(container_id: container.id))
    end

    it "shows add service controls" do
      sign_in user, scope: :user
      container = create(:container)

      get container_url(container)

      expect(response.body).to include("Agregar servicio")
      expect(response.body).to include("Agregar servicio a contenedor")
    end

    it "shows grouped invoice controls when services exist" do
      sign_in user, scope: :user
      allow(Rails.application.config.x.facturador).to receive(:enabled).and_return(true)
      allow(Rails.application.config.x.facturador).to receive(:manual_actions_enabled).and_return(true)
      container = create(:container)
      create(:container_service, container: container, factura: nil)

      get container_url(container)

      expect(response.body).to include("Facturar seleccionados")
    end

    it "shows delete service button only for non-invoiced services" do
      sign_in user, scope: :user
      container = create(:container)
      create(:container_service, container: container, factura: nil)

      get container_url(container)

      expect(response.body).to include("Editar servicio")
      expect(response.body).to include("Eliminar servicio")
    end

    it "hides delete service button for invoiced services" do
      sign_in user, scope: :user
      container = create(:container)
      create(:container_service, :facturado, container: container)

      get container_url(container)

      expect(response.body).not_to include("Editar servicio")
      expect(response.body).not_to include("Eliminar servicio")
    end

    it "shows restricted view for tramitador" do
      tramitador = create(:user, :tramitador)
      sign_in tramitador, scope: :user
      container = create(:container)

      get container_url(container)

      expect(response).to be_successful
      expect(response.body).not_to include("Editar")
      expect(response.body).not_to include("Eliminar")
      expect(response.body).not_to include("Servicios")
      expect(response.body).not_to include("Documentos")
      expect(response.body).not_to include("Historial")
      expect(response.body).to include("Fotografías del contenedor")
    end

    it "shows read-only view for consolidator on own container" do
      consolidator = create(:user, :consolidator)
      sign_in consolidator, scope: :user
      container = create(:container, consolidator_entity: consolidator.entity)

      get container_url(container)

      expect(response).to be_successful
      expect(response.body).not_to include("Editar")
      expect(response.body).not_to include("Eliminar")
      expect(response.body).not_to include("Agregar servicio")
      expect(response.body).to include("Fotografías del contenedor")
    end

    it "denies consolidator access to container from another consolidator" do
      consolidator = create(:user, :consolidator)
      sign_in consolidator, scope: :user
      other_container = create(:container)

      get container_url(other_container)

      expect(response).to redirect_to(containers_path)
    end

    it "allows admin to download import template for partidas" do
      sign_in user, scope: :user
      container = create(:container)

      get download_bl_house_lines_template_container_path(container)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")

      workbook = Roo::Spreadsheet.open(StringIO.new(response.body), extension: :xlsx)
      expect(workbook.row(1)).to eq(%w[blhouse cantidad embalaje contiene marcas peso volumen clase_imo tipo_imo])
    end

    it "denies consolidator from downloading import template" do
      consolidator = create(:user, :consolidator)
      sign_in consolidator, scope: :user
      own_container = create(:container, consolidator_entity: consolidator.entity)

      get download_bl_house_lines_template_container_path(own_container)

      expect(response).to redirect_to(containers_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "GET /containers for consolidator" do
    it "returns only own related containers" do
      consolidator = create(:user, :consolidator)
      own_container = create(:container, number: "CONS1234501", consolidator_entity: consolidator.entity)
      other_container = create(:container, number: "CONS1234502")
      sign_in consolidator, scope: :user

      get containers_url

      expect(response).to be_successful
      expect(response.body).to include(own_container.number)
      expect(response.body).not_to include(other_container.number)
      expect(response.body).not_to include("Nuevo Contenedor")
    end

    it "keeps consolidator filter fixed to current user consolidator" do
      consolidator = create(:user, :consolidator)
      other_consolidator = create(:entity, :consolidator, name: "Otro Consolidador")
      own_container = create(:container, number: "CONS1234510", consolidator_entity: consolidator.entity)
      other_container = create(:container, number: "CONS1234511", consolidator_entity: other_consolidator)
      sign_in consolidator, scope: :user

      get containers_url, params: { consolidator_id: other_consolidator.id }

      expect(response).to be_successful
      expect(response.body).to include(own_container.number)
      expect(response.body).not_to include(other_container.number)
      expect(response.body).to include("Consolidador: #{consolidator.entity.name}")
      expect(response.body).to include('name="consolidator_id"')
      expect(response.body).to include('disabled="disabled"')
    end

    it "filters by ETA for consolidator users" do
      consolidator = create(:user, :consolidator)
      own_entity = consolidator.entity
      sign_in consolidator, scope: :user

      selected_voyage = create(:voyage, eta: Time.zone.parse("2026-04-09 10:30:00"))
      other_voyage = create(:voyage, eta: Time.zone.parse("2026-04-11 10:30:00"))

      selected_container = create(:container, number: "ETAA1234501", consolidator_entity: own_entity, voyage: selected_voyage)
      other_container = create(:container, number: "ETAB1234502", consolidator_entity: own_entity, voyage: other_voyage)

      get containers_url, params: { eta: "2026-04-09" }

      expect(response).to be_successful
      expect(response.body).to include(selected_container.number)
      expect(response.body).not_to include(other_container.number)
      expect(response.body).to include("ETA")
      expect(response.body).not_to include("Línea Naviera")
      expect(response.body).to include("ETA:")
      expect(response.body).not_to include("Sin línea")
    end
  end

  describe "GET /containers shipping line filter for non-consolidator" do
    it "keeps filtering by shipping line for admin users" do
      sign_in user, scope: :user
      selected_line = create(:shipping_line, iso_code: "ADM")
      other_line = create(:shipping_line, iso_code: "OTH")

      selected_container = create(:container, number: "ADMN1234501", shipping_line: selected_line)
      other_container = create(:container, number: "ADMN1234502", shipping_line: other_line)

      get containers_url, params: { shipping_line_id: selected_line.id }

      expect(response).to be_successful
      expect(response.body).to include(selected_container.number)
      expect(response.body).not_to include(other_container.number)
      expect(response.body).to include("Línea Naviera")
      expect(response.body).to include("Línea")
    end
  end

  describe "GET /containers/shipping_lines_search" do
    before { sign_in user, scope: :user }

    it "returns empty results when query is too short" do
      get shipping_lines_search_containers_url, params: { q: "a" }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload["results"]).to eq([])
      expect(payload.dig("meta", "min_chars")).to eq(2)
    end

    it "returns up to 20 matching results" do
      25.times do |i|
        create(:shipping_line, name: "Naviera Stress #{i}", iso_code: format("%03d", i))
      end

      get shipping_lines_search_containers_url, params: { q: "Naviera Stress" }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload["results"].size).to eq(20)
      expect(payload.dig("meta", "limit")).to eq(20)
    end

    it "requires index permissions" do
      restricted_user = create(:user, :customs_broker)
      sign_in restricted_user, scope: :user

      get shipping_lines_search_containers_url, params: { q: "Naviera" }, as: :json

      expect(response).to have_http_status(:redirect)
    end

    it "allows tramitador users" do
      tramitador = create(:user, :tramitador)
      sign_in tramitador, scope: :user

      get shipping_lines_search_containers_url, params: { q: "Naviera" }, as: :json

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /containers/consolidators_search" do
    before { sign_in user, scope: :user }

    it "returns empty results when query is too short" do
      get consolidators_search_containers_url, params: { q: "a" }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload["results"]).to eq([])
      expect(payload.dig("meta", "min_chars")).to eq(2)
    end

    it "returns up to 20 matching consolidators" do
      25.times do |i|
        create(:entity, :consolidator, name: "Consolidador Stress #{i}")
      end

      get consolidators_search_containers_url, params: { q: "Consolidador Stress" }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload["results"].size).to eq(20)
      expect(payload.dig("meta", "limit")).to eq(20)
    end

    it "requires index permissions" do
      restricted_user = create(:user, :customs_broker)
      sign_in restricted_user, scope: :user

      get consolidators_search_containers_url, params: { q: "Consolidador" }, as: :json

      expect(response).to have_http_status(:redirect)
    end

    it "allows tramitador users" do
      tramitador = create(:user, :tramitador)
      sign_in tramitador, scope: :user

      get consolidators_search_containers_url, params: { q: "Consolidador" }, as: :json

      expect(response).to have_http_status(:ok)
    end

    it "limits consolidator users to their own consolidator" do
      consolidator_user = create(:user, :consolidator)
      own_entity = consolidator_user.entity
      other_entity = create(:entity, :consolidator, name: "Consolidador Externo")

      own_entity.update!(name: "Consolidador Propio")
      sign_in consolidator_user, scope: :user

      get consolidators_search_containers_url, params: { q: "Consolidador" }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      ids = payload.fetch("results").map { |result| result.fetch("id") }

      expect(ids).to include(own_entity.id)
      expect(ids).not_to include(other_entity.id)
    end
  end

  describe "GET /containers/vessels_search" do
    before { sign_in user, scope: :user }

    it "returns empty results when query is too short" do
      get vessels_search_containers_url, params: { q: "a" }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload["results"]).to eq([])
      expect(payload.dig("meta", "min_chars")).to eq(2)
    end

    it "returns up to 20 matching vessels" do
      25.times do |i|
        create(:vessel, name: "Buque Stress #{i}")
      end

      get vessels_search_containers_url, params: { q: "Buque Stress" }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload["results"].size).to eq(20)
      expect(payload.dig("meta", "limit")).to eq(20)
    end

    it "requires create permissions" do
      restricted_user = create(:user, :customs_broker)
      sign_in restricted_user, scope: :user

      get vessels_search_containers_url, params: { q: "Buque" }, as: :json

      expect(response).to have_http_status(:redirect)
    end
  end

  describe "GET /containers/voyages_search" do
    before { sign_in user, scope: :user }

    it "returns empty results when vessel is missing" do
      get voyages_search_containers_url, params: { q: "VOY" }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload["results"]).to eq([])
    end

    it "returns voyages only for the selected vessel" do
      selected_vessel = create(:vessel, name: "Buque Search")
      other_vessel = create(:vessel, name: "Buque Otro")
      destination = create(:port, :veracruz)

      selected_voyage = create(:voyage, vessel: selected_vessel, destination_port: destination, viaje: "VOY-001")
      create(:voyage, vessel: other_vessel, destination_port: destination, viaje: "VOY-002")

      get voyages_search_containers_url,
          params: { q: "VOY", vessel_id: selected_vessel.id },
          as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      ids = payload.fetch("results").map { |row| row.fetch("id") }

      expect(ids).to contain_exactly(selected_voyage.id)
    end

    it "requires create permissions" do
      restricted_user = create(:user, :customs_broker)
      sign_in restricted_user, scope: :user

      vessel = create(:vessel, name: "Buque Sin Permiso")
      get voyages_search_containers_url, params: { q: "VOY", vessel_id: vessel.id }, as: :json

      expect(response).to have_http_status(:redirect)
    end
  end

  describe "GET /containers/ports_search" do
    before { sign_in user, scope: :user }

    it "returns empty results when query is too short" do
      get ports_search_containers_url, params: { q: "a" }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload["results"]).to eq([])
      expect(payload.dig("meta", "min_chars")).to eq(2)
    end

    it "returns up to 20 matching ports" do
      25.times do |i|
        create(:port, name: "Puerto Stress #{i}", code: "PS#{i.to_s.rjust(3, '0')}")
      end

      get ports_search_containers_url, params: { q: "Puerto Stress" }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload["results"].size).to eq(20)
      expect(payload.dig("meta", "limit")).to eq(20)
    end

    it "requires create permissions" do
      restricted_user = create(:user, :customs_broker)
      sign_in restricted_user, scope: :user

      get ports_search_containers_url, params: { q: "Puerto" }, as: :json

      expect(response).to have_http_status(:redirect)
    end
  end

  describe "POST /containers" do
    before { sign_in user, scope: :user }

    it "resolves association ids from autocomplete search labels when ids are blank" do
      consolidator = create(:entity, :consolidator, name: "Consolidador Fallback")
      shipping_line = create(:shipping_line, name: "Linea Fallback")
      vessel = create(:vessel, name: "Buque Fallback")
      destination_port = create(:port, :veracruz)
      voyage = create(:voyage, vessel: vessel, destination_port: destination_port, viaje: "FB-001")
      origin_port = create(:port, name: "Puerto Fallback", code: "MXFBK")

      expect {
        post containers_url, params: {
          container: {
            number: "FALL1234567",
            status: "activo",
            tipo_maniobra: "importacion",
            type_size: "40HC",
            consolidator_entity_id: "",
            shipping_line_id: "",
            vessel_id: "",
            voyage_id: voyage.id,
            origin_port_id: "",
            bl_master: "BL-FB-001",
            recinto: "CICE",
            almacen: "CICE",
            archivo_nr: "NR-FB-001",
            sello: "SELLOFB",
            ejecutivo: "Usuario Fallback"
          },
          consolidator_search: consolidator.name,
          shipping_line_search: shipping_line.name,
          vessel_search: vessel.name,
          origin_port_search: origin_port.display_name
        }
      }.to change(Container, :count).by(1)

      created = Container.order(:id).last
      expect(created.consolidator_entity_id).to eq(consolidator.id)
      expect(created.shipping_line_id).to eq(shipping_line.id)
      expect(created.vessel_id).to eq(vessel.id)
      expect(created.origin_port_id).to eq(origin_port.id)
      expect(response).to redirect_to(container_url(created))
    end

    it "does not auto-assign shipping line when search label is ambiguous" do
      consolidator = create(:entity, :consolidator, name: "Consolidador Ambiguo")
      create(:shipping_line, name: "Linea Ambigua Uno")
      create(:shipping_line, name: "Linea Ambigua Dos")
      vessel = create(:vessel, name: "Buque Ambiguo")
      destination_port = create(:port, :veracruz)
      voyage = create(:voyage, vessel: vessel, destination_port: destination_port, viaje: "AMB-001")
      origin_port = create(:port, name: "Puerto Ambiguo", code: "MXAMB")

      expect {
        post containers_url, params: {
          container: {
            number: "AMBG1234567",
            status: "activo",
            tipo_maniobra: "importacion",
            type_size: "40HC",
            consolidator_entity_id: "",
            shipping_line_id: "",
            vessel_id: "",
            voyage_id: voyage.id,
            origin_port_id: "",
            bl_master: "BL-AMB-001",
            recinto: "CICE",
            almacen: "CICE",
            archivo_nr: "NR-AMB-001",
            sello: "SELLOAMB",
            ejecutivo: "Usuario Ambiguo"
          },
          consolidator_search: consolidator.name,
          shipping_line_search: "Linea Ambigua",
          vessel_search: vessel.name,
          origin_port_search: origin_port.display_name
        }
      }.not_to change(Container, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Shipping line no puede estar en blanco")
    end
  end

  describe "PATCH /containers/:id" do
    before { sign_in user, scope: :user }

    it "creates a service from show flow" do
      container = create(:container)
      service_catalog = create(:service_catalog, applies_to: "container", active: true)

      expect {
        patch container_url(container), params: {
          source: "show_services",
          service_action: "create",
          container: {
            container_services_attributes: {
              "0" => {
                service_catalog_id: service_catalog.id,
                amount: "321.50",
                billed_to_entity_id: container.consolidator_entity_id,
                observaciones: "Alta desde modal"
              }
            }
          }
        }
      }.to change(container.container_services, :count).by(1)

      expect(response).to redirect_to(container_url(container, anchor: "servicios"))
      expect(container.container_services.order(:id).last.amount).to eq(321.5)
    end

    it "deletes a non-invoiced service from show flow" do
      container = create(:container)
      service = create(:container_service, container: container, factura: nil)

      expect {
        patch container_url(container), params: {
          source: "show_services",
          service_action: "destroy",
          container: {
            container_services_attributes: {
              "0" => {
                id: service.id,
                _destroy: "1"
              }
            }
          }
        }
      }.to change(container.container_services, :count).by(-1)

      expect(response).to redirect_to(container_url(container, anchor: "servicios"))
    end

    it "updates a non-invoiced service from show flow" do
      container = create(:container)
      old_service_catalog = create(:service_catalog, applies_to: "container", active: true)
      new_service_catalog = create(:service_catalog, applies_to: "container", active: true)
      service = create(:container_service,
        container: container,
        service_catalog: old_service_catalog,
        factura: nil,
        observaciones: "Antes")

      patch container_url(container), params: {
        source: "show_services",
        service_action: "update",
        container: {
          container_services_attributes: {
            "0" => {
              id: service.id,
              service_catalog_id: new_service_catalog.id,
              amount: "999.99",
              billed_to_entity_id: container.consolidator_entity_id,
              observaciones: "Editado desde modal"
            }
          }
        }
      }

      expect(response).to redirect_to(container_url(container, anchor: "servicios"))
      expect(service.reload.service_catalog_id).to eq(new_service_catalog.id)
      expect(service.amount).to eq(999.99)
      expect(service.observaciones).to eq("Editado desde modal")
    end
  end

  describe "DELETE /containers/:id" do
    context "when container has no associated bl_house_lines" do
      it "destroys the requested container" do
        sign_in user, scope: :user
        container = create(:container)
        # Ensure the container has no BlHouseLines
        expect(container.bl_house_lines).to be_empty

        expect {
          delete container_url(container)
        }.to change(Container, :count).by(-1)
      end

      it "redirects to the containers list" do
        sign_in user, scope: :user
        container = create(:container)
        # Ensure the container has no BlHouseLines
        expect(container.bl_house_lines).to be_empty

        delete container_url(container)
        expect(response).to redirect_to(containers_url)
      end
    end

    context "when container has associated bl_house_lines" do
      it "does not destroy the container" do
        sign_in user, scope: :user
        container = create(:container)
        create(:bl_house_line, container: container)

        expect {
          delete container_url(container)
        }.not_to change(Container, :count)
      end

      it "redirects to containers list with alert message" do
        sign_in user, scope: :user
        container = create(:container)
        create(:bl_house_line, container: container)

        delete container_url(container)
        expect(response).to redirect_to(containers_url)
        expect(flash[:alert]).to eq("No se puede eliminar el contenedor porque tiene partidas asociadas.")
      end
    end
  end

  describe "DELETE /containers/:id/destroy_all_bl_house_lines" do
    before { sign_in user, scope: :user }

    it "deletes all BL house lines when none have attachments" do
      container = create(:container)
      create_list(:bl_house_line, 3, container: container)

      expect {
        delete destroy_all_bl_house_lines_container_path(container)
      }.to change { container.reload.bl_house_lines.count }.from(3).to(0)

      expect(response).to redirect_to(container_path(container))
      expect(flash[:notice]).to eq("Todas las partidas fueron eliminadas correctamente.")
    end

    it "does not delete any BL house line when at least one has attachments" do
      container = create(:container)
      lines = create_list(:bl_house_line, 2, container: container)

      # Attach a document to one line
      lines.first.bl_endosado_documento.attach(
        io: StringIO.new("doc"),
        filename: "bl.pdf",
        content_type: "application/pdf"
      )

      expect {
        delete destroy_all_bl_house_lines_container_path(container)
      }.not_to change { container.reload.bl_house_lines.count }

      expect(response).to redirect_to(container_path(container))
      expect(flash[:alert]).to eq("No se pueden eliminar las partidas porque alguna tiene documentos adjuntos.")
    end

    it "requires authorization (admin/executive)" do
      non_admin = create(:user, :customs_broker)
      sign_in non_admin, scope: :user
      container = create(:container)
      create(:bl_house_line, container: container)

      expect {
        delete destroy_all_bl_house_lines_container_path(container)
      }.not_to change { container.reload.bl_house_lines.count }

      expect(response).to redirect_to(customs_agents_dashboard_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "container lifecycle modals" do
    before { sign_in user, scope: :user }

    it "renders bl master lifecycle modal" do
      container = create(:container, status: "activo")

      get lifecycle_bl_master_modal_container_path(container), headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Cargar BL Master")
    end

    it "updates descarga date and auto advances to descargado" do
      container = create(:container, status: "bl_revalidado")

      patch lifecycle_descarga_update_container_path(container),
            params: { container: { fecha_descarga: Time.current.change(sec: 0) } },
            headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(container.reload.status).to eq("descargado")
    end

    it "updates transferencia data and auto advances to cita_transferencia" do
      container = create(:container, status: "descargado", fecha_descarga: Time.current.change(sec: 0))

      patch lifecycle_transferencia_update_container_path(container),
            params: {
              container: {
                fecha_transferencia: Time.current.change(sec: 0) + 1.day,
                almacen: "SSA"
              }
            },
            headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(container.reload.status).to eq("cita_transferencia")
    end

    it "allows marking transferencia as no aplica and advances to cita_transferencia" do
      container = create(:container, status: "descargado", fecha_descarga: Time.current.change(sec: 0))

      patch lifecycle_transferencia_update_container_path(container),
            params: {
              container: {
                transferencia_no_aplica: "1"
              }
            },
            headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      container.reload
      expect(container.transferencia_no_aplica).to be true
      expect(container.fecha_transferencia).to be_nil
      expect(container.almacen).to be_nil
      expect(container.status).to eq("cita_transferencia")
    end

    it "renders en proceso desconsolidación modal after fecha tentativa" do
      container = create(:container, status: "fecha_tentativa_desconsolidacion")

      get lifecycle_en_proceso_desconsolidacion_modal_container_path(container), headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Iniciar proceso de desconsolidación")
    end

    it "updates status to en_proceso_desconsolidacion" do
      container = create(:container, status: "fecha_tentativa_desconsolidacion")

      patch lifecycle_en_proceso_desconsolidacion_update_container_path(container),
            params: { container: { status: "en_proceso_desconsolidacion" } },
            headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(container.reload.status).to eq("en_proceso_desconsolidacion")
    end

    it "renders tarja modal from en_proceso_desconsolidacion" do
      container = create(:container, status: "en_proceso_desconsolidacion")

      get lifecycle_tarja_modal_container_path(container), headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Cargar tarja")
      expect(response.body).to include("Fecha de desconsolidación")
    end

    it "renders transferencia modal with no aplica option" do
      container = create(:container, status: "descargado")

      get lifecycle_transferencia_modal_container_path(container), headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No aplica transferencia")
    end
  end
end
