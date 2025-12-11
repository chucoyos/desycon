require 'rails_helper'

RSpec.describe "/shipping_lines", type: :request do
  let(:user) { create(:user, :admin) }

  before do
    sign_in user, scope: :user
  end

  let(:valid_attributes) {
    { name: "Evergreen", scac_code: "EGLV" }
  }

  let(:invalid_attributes) {
    { name: nil }
  }

  describe "GET /index" do
    it "renders a successful response" do
      ShippingLine.create! valid_attributes
      get shipping_lines_url
      expect(response).to be_successful
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      shipping_line = ShippingLine.create! valid_attributes
      get shipping_line_url(shipping_line)
      expect(response).to be_successful
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_shipping_line_url
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      shipping_line = ShippingLine.create! valid_attributes
      get edit_shipping_line_url(shipping_line)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new ShippingLine" do
        expect {
          post shipping_lines_url, params: { shipping_line: valid_attributes }
        }.to change(ShippingLine, :count).by(1)
      end

      it "redirects to the created shipping_line" do
        post shipping_lines_url, params: { shipping_line: valid_attributes }
        expect(response).to redirect_to(shipping_line_url(ShippingLine.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new ShippingLine" do
        expect {
          post shipping_lines_url, params: { shipping_line: invalid_attributes }
        }.to change(ShippingLine, :count).by(0)
      end

      it "renders a response with 422 status (unprocessable entity)" do
        post shipping_lines_url, params: { shipping_line: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) {
        { name: "COSCO" }
      }

      it "updates the requested shipping_line" do
        shipping_line = ShippingLine.create! valid_attributes
        patch shipping_line_url(shipping_line), params: { shipping_line: new_attributes }
        shipping_line.reload
        expect(shipping_line.name).to eq("COSCO")
      end

      it "redirects to the shipping_line" do
        shipping_line = ShippingLine.create! valid_attributes
        patch shipping_line_url(shipping_line), params: { shipping_line: new_attributes }
        shipping_line.reload
        expect(response).to redirect_to(shipping_line_url(shipping_line))
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status (unprocessable entity)" do
        shipping_line = ShippingLine.create! valid_attributes
        patch shipping_line_url(shipping_line), params: { shipping_line: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested shipping_line" do
      shipping_line = ShippingLine.create! valid_attributes
      expect {
        delete shipping_line_url(shipping_line)
      }.to change(ShippingLine, :count).by(-1)
    end

    it "redirects to the shipping_lines list" do
      shipping_line = ShippingLine.create! valid_attributes
      delete shipping_line_url(shipping_line)
      expect(response).to redirect_to(shipping_lines_url)
    end
  end
end
