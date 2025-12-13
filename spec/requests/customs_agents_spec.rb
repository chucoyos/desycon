require 'rails_helper'

RSpec.describe "CustomsAgents", type: :request do
  let(:customs_user) { create(:user, :customs_broker) }
  let(:assigned_bl_house_line) { create(:bl_house_line, customs_agent: customs_user.entity) }
  let(:unassigned_bl_house_line) { create(:bl_house_line, customs_agent: nil) }

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

    it "shows assigned BL House Lines" do
      assigned_bl_house_line
      sign_in customs_user, scope: :user
      get customs_agents_dashboard_path
      expect(response.body).to include(assigned_bl_house_line.blhouse)
    end

    it "shows unassigned BL House Lines" do
      unassigned_bl_house_line
      sign_in customs_user, scope: :user
      get customs_agents_dashboard_path
      expect(response.body).to include(unassigned_bl_house_line.blhouse)
    end

    context "search by blhouse" do
      it "redirects to edit when blhouse is found and assigned" do
        assigned_bl_house_line
        sign_in customs_user, scope: :user
        get customs_agents_dashboard_path, params: { blhouse: assigned_bl_house_line.blhouse }
        expect(response).to redirect_to(edit_bl_house_line_path(assigned_bl_house_line))
      end

      it "redirects to edit when blhouse is found and unassigned" do
        unassigned_bl_house_line
        sign_in customs_user, scope: :user
        get customs_agents_dashboard_path, params: { blhouse: unassigned_bl_house_line.blhouse }
        expect(response).to redirect_to(edit_bl_house_line_path(unassigned_bl_house_line))
      end

      it "shows alert when blhouse is not found" do
        sign_in customs_user, scope: :user
        get customs_agents_dashboard_path, params: { blhouse: "NONEXISTENT" }
        expect(response).to have_http_status(:success)
        expect(flash[:alert]).to eq("BL House no encontrado.")
      end

      it "ignores case and strips whitespace in search" do
        assigned_bl_house_line
        sign_in customs_user, scope: :user
        get customs_agents_dashboard_path, params: { blhouse: " #{assigned_bl_house_line.blhouse.downcase} " }
        expect(response).to redirect_to(edit_bl_house_line_path(assigned_bl_house_line))
      end
    end
  end
end
