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

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:edit) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.to permit_action(:new_address) }

    describe "scope" do
      let(:customs_agent) { user.entity }
      let!(:client) { create(:entity, :client, customs_agent: customs_agent) }
      let!(:other_entity) { create(:entity) }

      it "returns only associated clients" do
        resolved = EntityPolicy::Scope.new(user, Entity.all).resolve
        expect(resolved).to include(client)
        expect(resolved).not_to include(other_entity)
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
