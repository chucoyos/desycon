require 'rails_helper'

RSpec.describe "Containers", type: :request do
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
end
