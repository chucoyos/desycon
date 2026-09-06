require "rails_helper"

RSpec.describe "Consolidator API credentials", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:consolidator_entity) { create(:entity, :consolidator) }

  describe "POST /entities/:id/api_credentials" do
    it "generates a key for an authorized internal user" do
      sign_in admin_user, scope: :user

      post api_credentials_entity_path(consolidator_entity), params: { name: "ERP production" }

      expect(response).to redirect_to(entity_path(consolidator_entity))
      expect(flash[:api_key]).to start_with("dsc_test_")
      expect(consolidator_entity.consolidator_api_credentials.find_by(name: "ERP production")).to be_present
    end

    it "does not generate a key for a consolidator user" do
      user = create(:user, :consolidator, entity: consolidator_entity)
      sign_in user, scope: :user

      post api_credentials_entity_path(consolidator_entity)

      expect(response).to redirect_to(containers_path)
      expect(consolidator_entity.consolidator_api_credentials).to be_empty
    end

    it "does not generate a key for a non-consolidator entity" do
      entity = create(:entity, :client)
      sign_in admin_user, scope: :user

      post api_credentials_entity_path(entity)

      expect(response).to redirect_to(entity_path(entity))
      expect(flash[:api_key]).to be_nil
      expect(entity.consolidator_api_credentials).to be_empty
    end
  end
end
