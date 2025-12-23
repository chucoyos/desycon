class UserPolicy < ApplicationPolicy
  def index?
    user.present? && user.admin_or_executive?
  end

  def show?
    user.present? && (user == record || user.admin_or_executive?)
  end

  def create?
    user.present? && user.admin_or_executive?
  end

  def new?
    create?
  end

  def update?
    user.present? && (user == record || user.admin_or_executive?)
  end

  def edit?
    update?
  end

  def destroy?
    user.present? && user.admin_or_executive?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin_or_executive?
        scope.all
      else
        scope.where(id: user.id)
      end
    end
  end
end
