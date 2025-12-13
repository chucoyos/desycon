class PackagingPolicy < ApplicationPolicy
  def index?
    user.present? && !user.customs_broker?
  end

  def show?
    user.present? && !user.customs_broker?
  end

  def create?
    user.present? && !user.customs_broker?
  end

  def new?
    create?
  end

  def update?
    user.present? && !user.customs_broker?
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
        scope.none
      else
        scope.all
      end
    end
  end
end
