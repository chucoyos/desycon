require 'rails_helper'

RSpec.describe "Tutorials", type: :request do
  let(:role) { Role.find_or_create_by(name: "tutorial_role") }
  let(:user) { User.create!(email: "tutorial_user@example.com", password: "password123", password_confirmation: "password123", role: role) }

  describe "GET /tutorials" do
    context "when user is signed in" do
      before { login_as user }

      it "returns success and renders tutorial content" do
        get tutorials_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Video Tutoriales")
        expect(response.body).to include("Mj6YrvsIXD8")
        expect(response.body).to include("Ffo18-zaJCI")
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        get tutorials_path

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
