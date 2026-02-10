class EntityPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def create?
    user.present?
  end

  def new?
    create?
  end

  def update?
    user.present?
  end

  def edit?
    update?
  end

  def destroy?
    user.present? && !user.customs_broker?
  end

  def new_address?
    user.present?
  end

  def manage_brokers?
    user.present? && user.admin_or_executive?
  end

  class Scope < Scope
    def resolve
      if user.nil?
        scope.none
      elsif user.customs_broker?
        if user.entity&.is_customs_agent?
          scope.where(customs_agent_id: user.entity.id)
        else
          scope.none
        end
      else
        scope.all
      end
    end
  end
end
