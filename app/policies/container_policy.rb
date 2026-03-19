class ContainerPolicy < ApplicationPolicy
  def index?
    user.present? && !user.customs_broker?
  end

  def show?
    return false unless user.present? && !user.customs_broker?

    return true unless user.consolidator?

    owned_by_consolidator?
  end

  def create?
    user.present? && user.admin_or_executive?
  end

  def new?
    create?
  end

  def update?
    user.present? && user.admin_or_executive?
  end

  def edit?
    update?
  end

  def destroy?
    user.present? && user.admin_or_executive?
  end

  def destroy_all_bl_house_lines?
    destroy?
  end

  class Scope < Scope
    def resolve
      if user.nil? || user.customs_broker?
        scope.none
      elsif user.consolidator?
        return scope.none if user.entity_id.blank?

        scope.where(consolidator_entity_id: user.entity_id)
      else
        scope.all
      end
    end
  end

  private

  def owned_by_consolidator?
    user.entity_id.present? && record.respond_to?(:consolidator_entity_id) && record.consolidator_entity_id == user.entity_id
  end
end
