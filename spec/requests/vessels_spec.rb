require 'rails_helper'

RSpec.describe "Vessels", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:shipping_line) { create(:shipping_line) }
  let(:valid_attributes) { { name: "Test Vessel", shipping_line_id: shipping_line.id } }
  let(:invalid_attributes) { { name: nil, shipping_line_id: nil } }

  before do
    sign_in admin, scope: :user
  end

  describe "GET /index" do
    it "renders a successful response" do
      create(:vessel, shipping_line: shipping_line)
      get vessels_url
      expect(response).to be_successful
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      vessel = create(:vessel, shipping_line: shipping_line)
      get vessel_url(vessel)
      expect(response).to be_successful
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_vessel_url
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      vessel = create(:vessel, shipping_line: shipping_line)
      get edit_vessel_url(vessel)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Vessel" do
        expect {
          post vessels_url, params: { vessel: valid_attributes }
        }.to change(Vessel, :count).by(1)
      end

      it "redirects to the created vessel" do
        post vessels_url, params: { vessel: valid_attributes }
        expect(response).to redirect_to(vessel_url(Vessel.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new Vessel" do
        expect {
          post vessels_url, params: { vessel: invalid_attributes }
        }.to change(Vessel, :count).by(0)
      end

      it "renders a response with 422 status" do
        post vessels_url, params: { vessel: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) { { name: "Updated Vessel" } }

      it "updates the requested vessel" do
        vessel = create(:vessel, shipping_line: shipping_line)
        patch vessel_url(vessel), params: { vessel: new_attributes }
        vessel.reload
        expect(vessel.name).to eq("Updated Vessel")
      end

      it "redirects to the vessel" do
        vessel = create(:vessel, shipping_line: shipping_line)
        patch vessel_url(vessel), params: { vessel: new_attributes }
        vessel.reload
        expect(response).to redirect_to(vessel_url(vessel))
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status" do
        vessel = create(:vessel, shipping_line: shipping_line)
        patch vessel_url(vessel), params: { vessel: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested vessel" do
      vessel = create(:vessel, shipping_line: shipping_line)
      expect {
        delete vessel_url(vessel)
      }.to change(Vessel, :count).by(-1)
    end

    it "redirects to the vessels list" do
      vessel = create(:vessel, shipping_line: shipping_line)
      delete vessel_url(vessel)
      expect(response).to redirect_to(vessels_url)
    end
  end
end
