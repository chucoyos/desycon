class BlHouseLinePolicy < ApplicationPolicy
  def index?
    user.present? && (!user.customs_broker? || owned_by_customs_agent? || record.customs_agent.nil?)
  end

  def show?
    user.present? && (!user.customs_broker? || owned_by_customs_agent? || record.customs_agent.nil?)
  end

  def create?
    user.present? && !user.customs_broker?
  end

  def new?
    create?
  end

  def update?
    user.present? && (!user.customs_broker? || owned_by_customs_agent? || record.customs_agent.nil?)
  end

  def edit?
    update?
  end

  def destroy?
    user.present? && !user.customs_broker?
  end

  class Scope < Scope
    def resolve
      if user.nil? || user.customs_broker?
        # For customs brokers, return their assigned BL House Lines or unassigned ones
        if user&.customs_broker?
          scope.where(customs_agent: user.entity).or(scope.where(customs_agent: nil))
        else
          scope.none
        end
      else
        scope.all
      end
    end
  end

  private

  def owned_by_customs_agent?
    user.customs_broker? && record.customs_agent == user.entity
  end
end
