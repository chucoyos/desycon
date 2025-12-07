require 'rails_helper'

RSpec.describe "/ports", type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    sign_in admin, scope: :user
  end

  let(:valid_attributes) {
    { name: "Veracruz", code: "MXVER", country_code: "MX" }
  }

  let(:invalid_attributes) {
    { name: "", code: "", country_code: "" }
  }

  describe "GET /index" do
    it "renders a successful response" do
      Port.create! valid_attributes
      get ports_url
      expect(response).to be_successful
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      port = Port.create! valid_attributes
      get port_url(port)
      expect(response).to be_successful
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_port_url
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      port = Port.create! valid_attributes
      get edit_port_url(port)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Port" do
        expect {
          post ports_url, params: { port: valid_attributes }
        }.to change(Port, :count).by(1)
      end

      it "redirects to the created port" do
        post ports_url, params: { port: valid_attributes }
        expect(response).to redirect_to(port_url(Port.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new Port" do
        expect {
          post ports_url, params: { port: invalid_attributes }
        }.to change(Port, :count).by(0)
      end

      it "renders a response with 422 status (i.e. to display the 'new' template)" do
        post ports_url, params: { port: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) {
        { name: "Puerto Nuevo", code: "MXNEW", country_code: "MX" }
      }

      it "updates the requested port" do
        port = Port.create! valid_attributes
        patch port_url(port), params: { port: new_attributes }
        port.reload
        expect(port.name).to eq("Puerto Nuevo")
        expect(port.code).to eq("MXNEW")
      end

      it "redirects to the port" do
        port = Port.create! valid_attributes
        patch port_url(port), params: { port: new_attributes }
        port.reload
        expect(response).to redirect_to(port_url(port))
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status (i.e. to display the 'edit' template)" do
        port = Port.create! valid_attributes
        patch port_url(port), params: { port: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested port" do
      port = Port.create! valid_attributes
      expect {
        delete port_url(port)
      }.to change(Port, :count).by(-1)
    end

    it "redirects to the ports list" do
      port = Port.create! valid_attributes
      delete port_url(port)
      expect(response).to redirect_to(ports_url)
    end
  end
end
