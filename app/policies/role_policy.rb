class RolePolicy < ApplicationPolicy
  def index?
    user.present? && user.admin?
  end

  def show?
    user.present? && user.admin?
  end

  def create?
    user.present? && user.admin?
  end

  def new?
    create?
  end

  def update?
    user.present? && user.admin?
  end

  def edit?
    update?
  end

  def destroy?
    user.present? && user.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.none
      end
    end
  end
end
