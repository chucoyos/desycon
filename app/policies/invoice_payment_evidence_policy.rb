class InvoicePaymentEvidencePolicy < ApplicationPolicy
  def create?
    consolidator_user? || manageable_user?
  end

  def new?
    create?
  end

  def index?
    manageable_user?
  end

  def show?
    manageable_user?
  end

  def update?
    manageable_user?
  end

  def reject?
    update?
  end

  def register_payment?
    update?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user.present?
      return scope.all if user.admin_or_executive?
      scope.none
    end
  end

  private

  def manageable_user?
    user.present? && user.admin_or_executive?
  end

  def consolidator_user?
    user.present? && user.consolidator? && user.entity&.role_consolidator?
  end
end
