require 'rails_helper'

RSpec.describe EntityPolicy, type: :policy do
  subject { described_class.new(user, entity) }

  let(:entity) { create(:entity) }

  context "for admin users" do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:edit) }
    it { is_expected.to permit_action(:destroy) }
    it { is_expected.to permit_action(:new_address) }

    describe "scope" do
      it "returns all entities" do
        expect(EntityPolicy::Scope.new(user, Entity.all).resolve).to include(entity)
      end
    end
  end

  context "for executive users" do
    let(:user) { create(:user, :executive) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:edit) }
    it { is_expected.to permit_action(:destroy) }
    it { is_expected.to permit_action(:new_address) }

    describe "scope" do
      it "returns all entities" do
        expect(EntityPolicy::Scope.new(user, Entity.all).resolve).to include(entity)
      end
    end
  end

  context "for customs broker users" do
    let(:user) { create(:user, :customs_broker) }
    let(:entity) { create(:entity, :client, customs_agent: user.entity) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:edit) }
    it { is_expected.to permit_action(:destroy) }
    it { is_expected.to permit_action(:new_address) }

    it "does not allow managing clients from other customs agents" do
      other_client = create(:entity, :client)

      expect(described_class.new(user, other_client)).not_to permit_action(:show)
      expect(described_class.new(user, other_client)).not_to permit_action(:update)
      expect(described_class.new(user, other_client)).not_to permit_action(:destroy)
      expect(described_class.new(user, other_client)).not_to permit_action(:new_address)
    end

    it "does not allow managing customs broker entities" do
      customs_broker_entity = create(:entity, :customs_broker)

      expect(described_class.new(user, customs_broker_entity)).not_to permit_action(:show)
      expect(described_class.new(user, customs_broker_entity)).not_to permit_action(:update)
      expect(described_class.new(user, customs_broker_entity)).not_to permit_action(:destroy)
    end

    describe "scope" do
      let(:customs_agent) { user.entity }
      let!(:client) { create(:entity, :client, customs_agent: customs_agent) }
      let!(:other_entity) { create(:entity) }
      let!(:same_agent_non_client) { create(:entity, :consolidator, customs_agent: customs_agent) }

      it "returns only associated clients" do
        resolved = EntityPolicy::Scope.new(user, Entity.all).resolve
        expect(resolved).to include(client)
        expect(resolved).not_to include(other_entity)
        expect(resolved).not_to include(same_agent_non_client)
      end
    end
  end

  context "for tramitador users" do
    let(:user) { create(:user, :tramitador) }

    it { is_expected.not_to permit_action(:index) }
    it { is_expected.not_to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:new) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:edit) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:new_address) }

    describe "scope" do
      it "returns no entities" do
        expect(EntityPolicy::Scope.new(user, Entity.all).resolve).to be_empty
      end
    end
  end

  context "for unauthenticated users" do
    let(:user) { nil }

    it { is_expected.not_to permit_action(:index) }
    it { is_expected.not_to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:new) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:edit) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:new_address) }

    describe "scope" do
      it "returns no entities" do
        expect(EntityPolicy::Scope.new(user, Entity.all).resolve).to be_empty
      end
    end
  end
end
