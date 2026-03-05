class InvoicePolicy < ApplicationPolicy
  def index?
    issue_manual?
  end

  def issue_manual?
    user.present? && user.admin_or_executive?
  end

  def cancel?
    issue_manual?
  end

  def sync_documents?
    issue_manual?
  end

  def register_payment?
    issue_manual?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user.present?
      return scope.all if user.admin_or_executive?

      scope.none
    end
  end
end
