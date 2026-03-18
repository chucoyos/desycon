class ConsolidatorPolicy < ApplicationPolicy
  def index?
    user.present? && user.admin_or_executive?
  end

  def show?
    user.present? && user.admin_or_executive?
  end

  def create?
    user.present? && user.admin_or_executive?
  end

  def update?
    user.present? && user.admin_or_executive?
  end

  def destroy?
    user.present? && user.admin_or_executive?
  end

  class Scope < Scope
    def resolve
      user&.admin_or_executive? ? scope.all : scope.none
    end
  end
end
