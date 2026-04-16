require "rails_helper"

RSpec.describe "Admin::ManagementDashboard", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:executive_user) { create(:user, :executive) }
  let(:customs_user) { create(:user, :customs_broker) }

  describe "GET /admin/management_dashboard" do
    it "allows admin users" do
      sign_in admin_user, scope: :user

      get admin_management_dashboard_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Dashboard de Inteligencia Operativa y Financiera")
      expect(response.body).to include("Clasificación por Puerto Destino")
    end

    it "rejects executive users" do
      sign_in executive_user, scope: :user

      get admin_management_dashboard_path

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end

    it "rejects customs users" do
      sign_in customs_user, scope: :user

      get admin_management_dashboard_path

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end
  end

  describe "navbar management dashboard link" do
    it "shows the link for admin users" do
      sign_in admin_user, scope: :user

      get root_path
      follow_redirect! if response.redirect?

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Dashboard Gerencial")
      expect(response.body).to include(admin_management_dashboard_path)
    end

    it "hides the link for executive users" do
      sign_in executive_user, scope: :user

      get root_path
      follow_redirect! if response.redirect?

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Dashboard Gerencial")
      expect(response.body).not_to include(admin_management_dashboard_path)
    end

    it "hides the link for customs users" do
      sign_in customs_user, scope: :user

      get root_path
      follow_redirect! if response.redirect?

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Dashboard Gerencial")
      expect(response.body).not_to include(admin_management_dashboard_path)
    end
  end
end
