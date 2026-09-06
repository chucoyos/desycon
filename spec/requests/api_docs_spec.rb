require "rails_helper"

RSpec.describe "Consolidator API docs", type: :request do
  describe "GET /docs/consolidator-api" do
    it "renders the documentation for an admin user" do
      sign_in create(:user, :admin), scope: :user

      get consolidator_api_docs_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Documentación API Consolidador")
      expect(response.body).to include("/api/v1/consolidator")
    end

    it "denies access to a consolidator user" do
      user = create(:user, :consolidator, entity: create(:entity, :consolidator))
      sign_in user, scope: :user

      get consolidator_api_docs_path

      expect(response).to redirect_to(containers_path)
    end

    it "requires authentication" do
      get consolidator_api_docs_path

      expect(response).to redirect_to(root_path)
    end
  end
end
