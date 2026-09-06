class ApiDocPolicy < ApplicationPolicy
  def consolidator?
    user.present? && user.admin_or_executive?
  end
end
