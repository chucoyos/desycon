require 'rails_helper'

RSpec.describe ContainerPolicy, type: :policy do
  subject { described_class.new(user, container) }

  let(:container) { create(:container) }

  context "for admin users" do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }

    describe "scope" do
      it "returns all containers" do
        expect(ContainerPolicy::Scope.new(user, Container.all).resolve).to include(container)
      end
    end
  end

  context "for executive users" do
    let(:user) { create(:user, :executive) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }

    describe "scope" do
      it "returns all containers" do
        expect(ContainerPolicy::Scope.new(user, Container.all).resolve).to include(container)
      end
    end
  end

  context "for customs broker users" do
    let(:user) { create(:user, :customs_broker) }

    it { is_expected.not_to permit_action(:index) }
    it { is_expected.not_to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }

    describe "scope" do
      it "returns no containers" do
        expect(ContainerPolicy::Scope.new(user, Container.all).resolve).to be_empty
      end
    end
  end

  context "for tramitador users" do
    let(:user) { create(:user, :tramitador) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }

    describe "scope" do
      it "returns all containers" do
        expect(ContainerPolicy::Scope.new(user, Container.all).resolve).to include(container)
      end
    end
  end

  context "for consolidator users" do
    let(:user) { create(:user, :consolidator) }
    let(:container) { create(:container, consolidator_entity: user.entity) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }

    describe "scope" do
      it "returns only own containers" do
        own_container = create(:container, consolidator_entity: user.entity)
        other_container = create(:container)

        resolved = ContainerPolicy::Scope.new(user, Container.all).resolve

        expect(resolved).to include(own_container)
        expect(resolved).not_to include(other_container)
      end
    end

    context "when container belongs to another consolidator" do
      let(:container) { create(:container) }

      it { is_expected.not_to permit_action(:show) }
    end
  end

  context "for unauthenticated users" do
    let(:user) { nil }

    it { is_expected.not_to permit_action(:index) }
    it { is_expected.not_to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }

    describe "scope" do
      it "returns no containers" do
        expect(ContainerPolicy::Scope.new(user, Container.all).resolve).to be_empty
      end
    end
  end
end
