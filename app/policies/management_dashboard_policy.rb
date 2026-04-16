class ManagementDashboardPolicy < ApplicationPolicy
  def index?
    user.present? && user.admin?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user&.admin?

      scope.all
    end
  end
end
