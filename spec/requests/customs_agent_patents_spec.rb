require 'rails_helper'

RSpec.describe "CustomsAgentPatents", type: :request do
  let(:admin_role) { create(:role, name: 'admin') }
  let(:customs_broker_role) { create(:role, name: 'agente aduanal') }
  let(:client_role) { create(:role, name: 'client') }

  let(:admin_user) { create(:user, role: admin_role) }
  let(:customs_agent_entity) { create(:entity, :customs_agent) }
  let(:customs_agent_user) { create(:user, role: customs_broker_role, entity: customs_agent_entity) }
  let(:other_entity) { create(:entity, :customs_agent) }
  let(:other_user) { create(:user, role: customs_broker_role, entity: other_entity) }

  let!(:patent) { create(:customs_agent_patent, entity: customs_agent_entity) }

  describe "GET /index" do
    context "as admin" do
      before { sign_in admin_user, scope: :user }

      it "returns http success" do
        get entity_customs_agent_patents_path(customs_agent_entity)
        expect(response).to have_http_status(:success)
      end
    end

    context "as owner customs agent" do
      before { sign_in customs_agent_user, scope: :user }

      it "redirects due to lack of permissions" do
        get entity_customs_agent_patents_path(customs_agent_entity)
        expect(response).to have_http_status(:redirect)
      end
    end

    context "as other user" do
      before { sign_in other_user, scope: :user }

      it "redirects to root or back" do
        get entity_customs_agent_patents_path(customs_agent_entity)
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "POST /create" do
    let(:valid_attributes) { { patent_number: "9999" } }

    context "as admin" do
      before { sign_in admin_user, scope: :user }

      it "creates a new patent and redirects to entity show" do
        expect {
          post entity_customs_agent_patents_path(customs_agent_entity), params: { customs_agent_patent: valid_attributes }
        }.to change(CustomsAgentPatent, :count).by(1)
        expect(response).to redirect_to(entity_path(customs_agent_entity))
      end
    end

    context "as owner customs agent" do
      before { sign_in customs_agent_user, scope: :user }

      it "does not create a patent and redirects away" do
        expect {
          post entity_customs_agent_patents_path(customs_agent_entity), params: { customs_agent_patent: valid_attributes }
        }.not_to change(CustomsAgentPatent, :count)
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "PATCH /update" do
    let(:new_attributes) { { patent_number: "8888" } }

    context "as admin" do
      before { sign_in admin_user, scope: :user }

      it "updates the patent and redirects to entity show" do
        patch entity_customs_agent_patent_path(customs_agent_entity, patent), params: { customs_agent_patent: new_attributes }
        patent.reload
        expect(patent.patent_number).to eq("8888")
        expect(response).to redirect_to(entity_path(customs_agent_entity))
      end
    end

    context "as owner customs agent" do
      before { sign_in customs_agent_user, scope: :user }

      it "does not update the patent and redirects away" do
        original_number = patent.patent_number
        patch entity_customs_agent_patent_path(customs_agent_entity, patent), params: { customs_agent_patent: new_attributes }
        patent.reload
        expect(patent.patent_number).to eq(original_number)
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "DELETE /destroy" do
    context "as admin" do
      before { sign_in admin_user, scope: :user }

      it "destroys the patent and redirects back" do
        # Simulate coming from entity show page
        headers = { "HTTP_REFERER" => entity_path(customs_agent_entity) }
        expect {
          delete entity_customs_agent_patent_path(customs_agent_entity, patent), headers: headers
        }.to change(CustomsAgentPatent, :count).by(-1)
        expect(response).to redirect_to(entity_path(customs_agent_entity))
      end
    end

    context "as owner customs agent" do
      before { sign_in customs_agent_user, scope: :user }

      it "does not destroy the patent and redirects away" do
        headers = { "HTTP_REFERER" => entity_customs_agent_patents_path(customs_agent_entity) }
        expect {
          delete entity_customs_agent_patent_path(customs_agent_entity, patent), headers: headers
        }.not_to change(CustomsAgentPatent, :count)
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
