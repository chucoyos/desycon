require 'rails_helper'

RSpec.describe "CustomsAgents", type: :request do
  let(:customs_user) { create(:user, :customs_broker) }

  describe "GET /dashboard" do
    it "returns http success for authenticated customs agent" do
      sign_in customs_user, scope: :user
      get customs_agents_dashboard_path
      expect(response).to have_http_status(:success)
    end

    it "redirects unauthenticated users" do
      get customs_agents_dashboard_path
      expect(response).to have_http_status(:redirect)
    end

    it "redirects non-customs agent users" do
      operator_user = create(:user, :operator)
      sign_in operator_user, scope: :user
      get customs_agents_dashboard_path
      expect(response).to have_http_status(:redirect)
    end
  end
end
