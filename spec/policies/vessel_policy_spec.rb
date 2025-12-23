require 'rails_helper'

RSpec.describe VesselPolicy, type: :policy do
  subject { described_class.new(user, vessel) }

  let(:vessel) { create(:vessel) }

  context "for admin users" do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:edit) }
    it { is_expected.to permit_action(:destroy) }

    describe "scope" do
      it "returns all vessels" do
        expect(VesselPolicy::Scope.new(user, Vessel.all).resolve).to include(vessel)
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

    describe "scope" do
      it "returns all vessels" do
        expect(VesselPolicy::Scope.new(user, Vessel.all).resolve).to include(vessel)
      end
    end
  end

  context "for customs broker users" do
    let(:user) { create(:user, :customs_broker) }

    it { is_expected.not_to permit_action(:index) }
    it { is_expected.not_to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:new) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:edit) }
    it { is_expected.not_to permit_action(:destroy) }

    describe "scope" do
      it "returns no vessels" do
        expect(VesselPolicy::Scope.new(user, Vessel.all).resolve).to be_empty
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

    describe "scope" do
      it "returns no vessels" do
        expect(VesselPolicy::Scope.new(user, Vessel.all).resolve).to be_empty
      end
    end
  end
end
