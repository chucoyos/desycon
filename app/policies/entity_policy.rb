class EntityPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    can_manage_record?
  end

  def create?
    user.present? && (user.admin_or_executive? || customs_agent_user?)
  end

  def new?
    create?
  end

  def update?
    can_manage_record?
  end

  def edit?
    update?
  end

  def destroy?
    can_manage_record?
  end

  def new_address?
    update?
  end

  def manage_brokers?
    user.present? && user.admin_or_executive?
  end

  class Scope < Scope
    def resolve
      if user.nil?
        scope.none
      elsif user.customs_broker?
        if user.entity&.role_customs_agent?
          scope.where(customs_agent_id: user.entity.id, role_kind: "client")
        else
          scope.none
        end
      else
        scope.all
      end
    end
  end

  private

  def can_manage_record?
    return false unless user.present?
    return true if user.admin_or_executive?

    manageable_client_for_customs_broker?
  end

  def customs_agent_user?
    user.customs_broker? && user.entity&.role_customs_agent?
  end

  def manageable_client_for_customs_broker?
    customs_agent_user? && record.role_client? && record.customs_agent_id == user.entity_id
  end
end
