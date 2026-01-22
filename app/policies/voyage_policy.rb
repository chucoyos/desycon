class VoyagePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if user.nil?

      if user.admin_or_executive?
        scope.all
      else
        scope.none
      end
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
