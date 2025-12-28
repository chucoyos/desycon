require 'rails_helper'

RSpec.describe "BlHouseLines", type: :request do
  let(:user) { create(:user, :executive) }
  let(:customs_agent) { create(:entity, :customs_agent) }
  let(:client) { create(:entity, :client) }
  let(:container) { create(:container) }
  let(:packaging) { create(:packaging) }

  let(:valid_attributes) {
    {
      blhouse: "BLH001234",
      partida: 1,
      cantidad: 10,
      contiene: "Contenido de prueba",
      marcas: "Marcas de prueba",
      peso: 100.5,
      volumen: 2.5,
      customs_agent_id: customs_agent.id,
      client_id: client.id,
      container_id: container.id,
      packaging_id: packaging.id,
      status: "activo"
    }
  }

  let(:invalid_attributes) {
    {
      blhouse: "",
      partida: nil,
      cantidad: 0,
      customs_agent_id: nil,
      client_id: nil,
      container_id: nil,
      packaging_id: nil
    }
  }

  describe "GET /bl_house_lines" do
    it "renders a successful response" do
      sign_in user, scope: :user
      create(:bl_house_line)
      get bl_house_lines_url
      expect(response).to be_successful
    end
  end

  describe "GET /bl_house_lines/:id" do
    it "renders a successful response" do
      sign_in user, scope: :user
      bl_house_line = create(:bl_house_line)
      get bl_house_line_url(bl_house_line)
      expect(response).to be_successful
    end
  end

  describe "GET /bl_house_lines/new" do
    it "renders a successful response" do
      sign_in user, scope: :user
      get new_bl_house_line_url
      expect(response).to be_successful
    end
  end

  describe "GET /bl_house_lines/:id/edit" do
    it "renders a successful response" do
      sign_in user, scope: :user
      bl_house_line = create(:bl_house_line)
      get edit_bl_house_line_url(bl_house_line)
      expect(response).to be_successful
    end
  end

  describe "POST /bl_house_lines" do
    context "with valid parameters" do
      it "creates a new BlHouseLine" do
        sign_in user, scope: :user
        expect {
          post bl_house_lines_url, params: { bl_house_line: valid_attributes }
        }.to change(BlHouseLine, :count).by(1)
      end

      it "redirects to the created bl_house_line" do
        sign_in user, scope: :user
        post bl_house_lines_url, params: { bl_house_line: valid_attributes }
        expect(response).to redirect_to(bl_house_line_url(BlHouseLine.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new BlHouseLine" do
        sign_in user, scope: :user
        expect {
          post bl_house_lines_url, params: { bl_house_line: invalid_attributes }
        }.to change(BlHouseLine, :count).by(0)
      end

      it "renders a response with 422 status (i.e. to display the 'new' template)" do
        sign_in user, scope: :user
        post bl_house_lines_url, params: { bl_house_line: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /bl_house_lines/:id" do
    context "with valid parameters" do
      let(:new_attributes) {
        {
          blhouse: "BLH009876",
          cantidad: 20
        }
      }

      it "updates the requested bl_house_line" do
        sign_in user, scope: :user
        bl_house_line = create(:bl_house_line)
        patch bl_house_line_url(bl_house_line), params: { bl_house_line: new_attributes }
        bl_house_line.reload
        expect(bl_house_line.blhouse).to eq("BLH009876")
        expect(bl_house_line.cantidad).to eq(20)
      end

      it "redirects to the bl_house_line" do
        sign_in user, scope: :user
        bl_house_line = create(:bl_house_line)
        patch bl_house_line_url(bl_house_line), params: { bl_house_line: new_attributes }
        bl_house_line.reload
        expect(response).to redirect_to(bl_house_line_url(bl_house_line))
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status (i.e. to display the 'edit' template)" do
        sign_in user, scope: :user
        bl_house_line = create(:bl_house_line)
        patch bl_house_line_url(bl_house_line), params: { bl_house_line: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /bl_house_lines/:id" do
    it "destroys the requested bl_house_line" do
      sign_in user, scope: :user
      bl_house_line = create(:bl_house_line)
      expect {
        delete bl_house_line_url(bl_house_line)
      }.to change(BlHouseLine, :count).by(-1)
    end

    it "redirects to the bl_house_lines list" do
      sign_in user, scope: :user
      bl_house_line = create(:bl_house_line)
      delete bl_house_line_url(bl_house_line)
      expect(response).to redirect_to(bl_house_lines_url)
    end
  end
end
