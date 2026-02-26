require "rails_helper"

RSpec.describe "Voyages", type: :request do
  let(:user) { create(:user, :admin) }

  describe "GET /voyages" do
    before { sign_in user, scope: :user }

    it "shows only recent voyages by default (last 30 days)" do
      recent_voyage = create(:voyage, viaje: "VREC001")
      old_voyage = create(:voyage, viaje: "VOLD001")
      old_voyage.update_column(:created_at, 45.days.ago)

      get voyages_path

      expect(response).to be_successful
      expect(response.body).to include(recent_voyage.viaje)
      expect(response.body).not_to include(old_voyage.viaje)
    end

    it "includes old voyages when explicit date range is provided" do
      old_voyage = create(:voyage, viaje: "VOLD002")
      old_voyage.update_column(:created_at, 45.days.ago)

      get voyages_path, params: {
        start_date: 60.days.ago.to_date.to_s,
        end_date: Date.current.to_s
      }

      expect(response).to be_successful
      expect(response.body).to include(old_voyage.viaje)
      expect(response.body).to include("Filtros activos:")
    end
  end
end
