require 'rails_helper'

RSpec.describe UserPolicy, type: :policy do
  subject(:policy) { described_class }

  let(:admin_role) { Role.find_or_create_by!(name: Role::ADMIN) }
  let(:executive_role) { Role.find_or_create_by!(name: Role::EXECUTIVE) }
  let(:admin) { create(:user, role: admin_role) }
  let(:executive) { create(:user, role: executive_role) }
  let(:other_user) { create(:user, :customs_broker) }

  permissions ".scope" do
    it "returns all users for admin/executive" do
      user = create(:user)

      scope = described_class::Scope.new(admin, User).resolve
      expect(scope).to include(user, admin)

      scope = described_class::Scope.new(executive, User).resolve
      expect(scope).to include(user, executive)
    end

    it "returns only the current user for non-admin" do
      scope = described_class::Scope.new(other_user, User).resolve
      expect(scope).to contain_exactly(other_user)
    end
  end

  permissions :show? do
    it "allows viewing self" do
      expect(policy).to permit(other_user, other_user)
    end

    it "allows admin/executive to view others" do
      expect(policy).to permit(admin, other_user)
      expect(policy).to permit(executive, other_user)
    end

    it "denies non-admin viewing others" do
      expect(policy).not_to permit(other_user, admin)
    end
  end

  permissions :create? do
    it "allows admin/executive" do
      expect(policy).to permit(admin, User.new)
      expect(policy).to permit(executive, User.new)
    end

    it "denies non-admin" do
      expect(policy).not_to permit(other_user, User.new)
    end
  end

  permissions :update? do
    it "allows updating self" do
      expect(policy).to permit(other_user, other_user)
    end

    it "allows admin/executive to update others" do
      expect(policy).to permit(admin, other_user)
      expect(policy).to permit(executive, other_user)
    end

    it "denies non-admin updating others" do
      expect(policy).not_to permit(other_user, admin)
    end
  end

  permissions :destroy? do
    it "allows admin/executive" do
      expect(policy).to permit(admin, other_user)
      expect(policy).to permit(executive, other_user)
    end

    it "denies non-admin" do
      expect(policy).not_to permit(other_user, admin)
    end
  end
end
