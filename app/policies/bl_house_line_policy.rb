class BlHouseLinePolicy < ApplicationPolicy
  def index?
    # When authorizing the collection route we may receive the policy with
    # the class as the record (for controller#index) or with an instance
    # (some specs call the policy with a record). If we get the class,
    # rely on the scope to limit results; if we get an instance, apply the
    # same ownership rules used by `show?`/`update?` so specs behave correctly.
    return false unless user.present?

    if user.consolidator?
      return true if record.is_a?(Class)

      return owned_by_consolidator?
    end

    return true unless user.customs_broker?

    # If `record` is the class (policy for collection), allow — scope will filter.
    return true if record.is_a?(Class)

    # For instance records, only allow index if the bl is assigned to the
    # user's entity.
    owned_by_customs_agent?
  end

  def show?
    return false unless user.present?

    return owned_by_consolidator? if user.consolidator?

    return true unless user.customs_broker?

    return false if record.hidden_from_customs_agent?

    owned_by_customs_agent? || record.customs_agent.nil?
  end

  def documents?
    return false if user&.tramitador?

    show?
  end

  def create?
    user.present? && user.admin_or_executive?
  end

  def new?
    create?
  end

  def update?
    return false unless user.present?
    return false if user.tramitador? || user.consolidator?

    return true unless user.customs_broker?

    return false if record.hidden_from_customs_agent?

    owned_by_customs_agent? || record.customs_agent.nil?
  end

  def edit?
    update?
  end

  def destroy?
    user.present? && user.admin_or_executive?
  end

  def import_from_container?
    create?
  end

  def approve_revalidation?
    user.present? && user.admin_or_executive?
  end

  def reassign?
    user.present? && user.admin_or_executive?
  end

  def perform_reassign?
    reassign?
  end

  class Scope < Scope
    def resolve
      if user.nil?
        scope.none
      elsif user.customs_broker?
        # For customs brokers, return only BL House Lines assigned to their entity
        scope.where(customs_agent: user.entity, hidden_from_customs_agent: false)
      elsif user.consolidator?
        return scope.none if user.entity_id.blank?

        scope.joins(:container).where(containers: { consolidator_entity_id: user.entity_id })
      else
        scope.all
      end
    end
  end

  private

  def owned_by_customs_agent?
    user.customs_broker? && record.customs_agent == user.entity
  end

  def owned_by_consolidator?
    user.consolidator? && user.entity_id.present? && record.container&.consolidator_entity_id == user.entity_id
  end
end
