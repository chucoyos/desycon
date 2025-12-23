require 'rails_helper'

RSpec.describe PackagingPolicy, type: :policy do
  subject { described_class.new(user, packaging) }

  let(:packaging) { create(:packaging) }

  context "for admin users" do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }

    describe "scope" do
      it "returns all packagings" do
        expect(PackagingPolicy::Scope.new(user, Packaging.all).resolve).to include(packaging)
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
      it "returns all packagings" do
        expect(PackagingPolicy::Scope.new(user, Packaging.all).resolve).to include(packaging)
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
      it "returns no packagings" do
        expect(PackagingPolicy::Scope.new(user, Packaging.all).resolve).to be_empty
      end
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
      it "returns no packagings" do
        expect(PackagingPolicy::Scope.new(user, Packaging.all).resolve).to be_empty
      end
    end
  end
end
