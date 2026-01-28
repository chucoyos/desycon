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

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_present
    end
  end
end
