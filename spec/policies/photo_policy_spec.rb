require "rails_helper"

RSpec.describe PhotoPolicy, type: :policy do
  subject { described_class.new(user, photo) }

  let(:photo) { build(:photo) }

  context "for admin users" do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:destroy) }
  end

  context "for executive users" do
    let(:user) { create(:user, :executive) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:destroy) }
  end

  context "for customs broker users" do
    let(:user) { create(:user, :customs_broker) }

    it { is_expected.not_to permit_action(:index) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:destroy) }
  end

  context "for unauthenticated users" do
    let(:user) { nil }

    it { is_expected.not_to permit_action(:index) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:destroy) }
  end
end
