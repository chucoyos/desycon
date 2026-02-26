require 'rails_helper'

RSpec.describe "Entity patent numbers", type: :request do
  let(:admin_role) { create(:role, name: "admin") }
  let(:customs_broker_role) { create(:role, name: "agente aduanal") }

  let(:admin_user) { create(:user, role: admin_role) }
  let(:customs_broker_entity) { create(:entity, :customs_broker, patent_number: "3001") }
  let(:customs_broker_user) { create(:user, role: customs_broker_role, entity: customs_broker_entity) }

  describe "PATCH /entities/:id" do
    let(:new_attributes) { { patent_number: "8888", role_kind: "customs_broker" } }

    context "as admin" do
      before { sign_in admin_user, scope: :user }

      it "updates the patent number and redirects to entity show" do
        patch entity_path(customs_broker_entity), params: { entity: new_attributes }
        customs_broker_entity.reload
        expect(customs_broker_entity.patent_number).to eq("8888")
        expect(response).to redirect_to(entity_path(customs_broker_entity))
      end
    end

    context "as customs broker owner" do
      before { sign_in customs_broker_user, scope: :user }

      it "updates the patent number and redirects to entity show" do
        patch entity_path(customs_broker_entity), params: { entity: new_attributes }
        customs_broker_entity.reload
        expect(customs_broker_entity.patent_number).to eq("8888")
        expect(response).to redirect_to(entity_path(customs_broker_entity))
      end
    end
  end
end
