require 'rails_helper'

RSpec.describe "Entities", type: :request do
  let(:user) { create(:user, :admin) }
  let(:entity) { create(:entity) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /index" do
    let!(:consolidator) { create(:entity, :consolidator, name: "ABC Consolidators") }
    let!(:customs_agent) { create(:entity, :customs_agent, name: "XYZ Customs") }
    let!(:forwarder) { create(:entity, :forwarder, name: "Fast Forwarder") }
    let!(:client) { create(:entity, :client, name: "Client Company") }

    it "returns http success" do
      get entities_path
      expect(response).to have_http_status(:success)
    end

    it "filters by name" do
      get entities_path, params: { name: "ABC" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("ABC Consolidators")
      expect(response.body).not_to include("XYZ Customs")
    end

    it "filters by role consolidator" do
      get entities_path, params: { role: "consolidator" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("ABC Consolidators")
      expect(response.body).not_to include("XYZ Customs")
    end

    it "filters by role customs_agent" do
      get entities_path, params: { role: "customs_agent" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("XYZ Customs")
      expect(response.body).not_to include("ABC Consolidators")
    end

    it "filters by role forwarder" do
      get entities_path, params: { role: "forwarder" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Fast Forwarder")
      expect(response.body).not_to include("ABC Consolidators")
    end

    it "filters by role client" do
      get entities_path, params: { role: "client" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Client Company")
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get entity_path(entity)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get new_entity_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      get edit_entity_path(entity)
      expect(response).to have_http_status(:success)
    end
  end
end
