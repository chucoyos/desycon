class InvoicePolicy < ApplicationPolicy
  def show?
    issue_manual? || customs_related_invoice?
  end

  def index?
    issue_manual? || customs_agency_user?
  end

  def issue_manual?
    user.present? && user.admin_or_executive?
  end

  def new?
    issue_manual?
  end

  def create?
    issue_manual?
  end

  def retry_issue?
    issue_manual?
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

  def send_email?
    issue_manual?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user.present?
      return scope.all if user.admin_or_executive?

      if user.customs_broker? && user.entity&.role_customs_agent?
        return scope
               .joins(:receiver_entity)
               .where(
                 "invoices.customs_agent_id = :agency_id OR entities.customs_agent_id = :agency_id",
                 agency_id: user.entity_id
               )
               .distinct
      end

      scope.none
    end
  end

  private

  def customs_agency_user?
    user.present? && user.customs_broker? && user.entity&.role_customs_agent?
  end

  def customs_related_invoice?
    return false unless customs_agency_user?
    return false unless record.is_a?(Invoice)

    record.customs_agent_id == user.entity_id || record.receiver_entity&.customs_agent_id == user.entity_id
  end
end
