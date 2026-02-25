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

    it "renders tarja modal with manual fecha de desconsolidación field" do
      container = create(:container, status: "fecha_tentativa_desconsolidacion")

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
