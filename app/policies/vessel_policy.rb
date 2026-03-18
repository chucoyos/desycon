class VesselPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.admin_or_executive? ? scope.all : scope.none
    end
  end

  def index?
    user.present? && user.admin_or_executive?
  end

  def show?
    user.present? && user.admin_or_executive?
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
end
