class BlHouseLinePolicy < ApplicationPolicy
  def index?
    # When authorizing the collection route we may receive the policy with
    # the class as the record (for controller#index) or with an instance
    # (some specs call the policy with a record). If we get the class,
    # rely on the scope to limit results; if we get an instance, apply the
    # same ownership rules used by `show?`/`update?` so specs behave correctly.
    return false unless user.present?

    return true unless user.customs_broker?

    # If `record` is the class (policy for collection), allow — scope will filter.
    return true if record.is_a?(Class)

    # For instance records, only allow index if the bl is assigned to the
    # user's entity or it's unassigned.
    owned_by_customs_agent? || record.customs_agent.nil?
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
