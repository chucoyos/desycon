require 'rails_helper'

RSpec.describe BlHouseLinePolicy, type: :policy do
  subject { described_class.new(user, bl_house_line) }

  let(:bl_house_line) { create(:bl_house_line) }

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
      it "returns all bl_house_lines" do
        expect(BlHouseLinePolicy::Scope.new(user, BlHouseLine.all).resolve).to include(bl_house_line)
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
      it "returns all bl_house_lines" do
        expect(BlHouseLinePolicy::Scope.new(user, BlHouseLine.all).resolve).to include(bl_house_line)
      end
    end
  end

  context "for customs broker users" do
    let(:user) { create(:user, :customs_broker) }

    context "when bl_house_line belongs to the customs broker" do
      let(:bl_house_line) { create(:bl_house_line, customs_agent: user.entity) }

      it { is_expected.to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.not_to permit_action(:create) }
      it { is_expected.not_to permit_action(:new) }
      it { is_expected.to permit_action(:update) }
      it { is_expected.to permit_action(:edit) }
      it { is_expected.not_to permit_action(:destroy) }

      describe "scope" do
        it "returns the bl_house_line" do
          expect(BlHouseLinePolicy::Scope.new(user, BlHouseLine.all).resolve).to include(bl_house_line)
        end
      end
    end

    context "when bl_house_line is unassigned" do
      let(:bl_house_line) { create(:bl_house_line, customs_agent: nil) }
        it { is_expected.not_to permit_action(:index) }
      it { is_expected.to permit_action(:show) }
      it { is_expected.not_to permit_action(:create) }
      it { is_expected.not_to permit_action(:new) }
      it { is_expected.to permit_action(:update) }
      it { is_expected.to permit_action(:edit) }
      it { is_expected.not_to permit_action(:destroy) }

      describe "scope" do
        it "does not return the unassigned bl_house_line" do
          expect(BlHouseLinePolicy::Scope.new(user, BlHouseLine.all).resolve).not_to include(bl_house_line)
        end
      end
    end

    context "when bl_house_line does not belong to the customs broker" do
      let(:other_entity) { create(:entity) }
      let(:bl_house_line) { create(:bl_house_line, customs_agent: other_entity) }

      it { is_expected.not_to permit_action(:index) }
      it { is_expected.not_to permit_action(:show) }
      it { is_expected.not_to permit_action(:create) }
      it { is_expected.not_to permit_action(:new) }
      it { is_expected.not_to permit_action(:update) }
      it { is_expected.not_to permit_action(:edit) }
      it { is_expected.not_to permit_action(:destroy) }

      describe "scope" do
        it "returns no bl_house_lines" do
          expect(BlHouseLinePolicy::Scope.new(user, BlHouseLine.all).resolve).to be_empty
        end
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
      it "returns no bl_house_lines" do
        expect(BlHouseLinePolicy::Scope.new(user, BlHouseLine.all).resolve).to be_empty
      end
    end
  end
end
