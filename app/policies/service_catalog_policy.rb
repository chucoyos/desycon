class ServiceCatalogPolicy < ApplicationPolicy
  def index?
    user&.internal?
  end

  def show?
    user&.internal?
  end

  def create?
    user&.admin_or_executive?
  end

  def new?
    create?
  end

  def update?
    user&.admin_or_executive?
  end

  def edit?
    update?
  end

  def destroy?
    user&.admin_or_executive?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.internal?

      scope.all
    end
  end
end
