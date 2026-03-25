class PhotoPolicy < ApplicationPolicy
  def index?
    user&.admin_or_executive?
  end

  def create?
    user&.admin_or_executive? || user&.tramitador?
  end

  def destroy?
    user&.admin_or_executive? || user&.tramitador?
  end

  def download?
    user&.admin_or_executive? || user&.tramitador?
  end

  class Scope < Scope
    def resolve
      if user&.admin_or_executive?
        scope.all
      else
        scope.none
      end
    end
  end
end
