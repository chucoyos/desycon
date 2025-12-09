require 'rails_helper'

RSpec.describe "Containers", type: :request do
  let(:user) { create(:user, :admin) }
  let(:consolidator_entity) { create(:entity, :consolidator) }
  let(:shipping_line) { create(:shipping_line) }

  before do
    # Mock Pundit authorization
    allow_any_instance_of(ContainerPolicy).to receive(:destroy?).and_return(true)
  end

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
      container = create(:container)
      get container_url(container)
      expect(response).to be_successful
    end

    it "displays associated bl_house_lines" do
      container = create(:container)
      bl_house_line = create(:bl_house_line, container: container)

      get container_url(container)
      expect(response).to be_successful
      expect(response.body).to include("Partidas")
      expect(response.body).to include(bl_house_line.partida.to_s)
    end

    it "shows create new partida link" do
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
        container = create(:container)
        # Ensure the container has no BlHouseLines
        expect(container.bl_house_lines).to be_empty

        expect {
          delete container_url(container)
        }.to change(Container, :count).by(-1)
      end

      it "redirects to the containers list" do
        container = create(:container)
        # Ensure the container has no BlHouseLines
        expect(container.bl_house_lines).to be_empty

        delete container_url(container)
        expect(response).to redirect_to(containers_url)
      end
    end

    context "when container has associated bl_house_lines" do
      it "does not destroy the container" do
        container = create(:container)
        create(:bl_house_line, container: container)

        expect {
          delete container_url(container)
        }.not_to change(Container, :count)
      end

      it "redirects to containers list with alert message" do
        container = create(:container)
        create(:bl_house_line, container: container)

        delete container_url(container)
        expect(response).to redirect_to(containers_url)
        expect(flash[:alert]).to eq("No se puede eliminar el contenedor porque tiene registros asociados (líneas BL).")
      end
    end
  end
end
