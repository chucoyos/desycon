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

      it "shows the revalidations and services tutorial in second place" do
        get tutorials_path

        cards = Nokogiri::HTML(response.body).css("article")
        expect(cards.map { |card| card.at_css("iframe")["src"].split("/").last }).to eq(
          %w[jnvhU0_Jmmk 7l8pZE-4S1E 2cqTxOh3n_4 Mj6YrvsIXD8 Ffo18-zaJCI]
        )
        expect(cards[1].at_css("h2").text).to eq("Cómo solicitar revalidaciones y servicios")
        expect(cards[1].text).to include("previos, etiquetado, emplaye y maniobras", "Video 2")
        expect(cards[1].at_css("a")["href"]).to eq("https://youtu.be/7l8pZE-4S1E")
        expect(cards.map { |card| card.at_css("span").text }).to eq([ "Video 1", "Video 2", "Video 3", "Video 4", "Video 5" ])
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
