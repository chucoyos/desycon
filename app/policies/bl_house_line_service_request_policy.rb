class BlHouseLineServiceRequestPolicy < ApplicationPolicy
  def index?
    user&.admin_or_executive?
  end

  def new?
    user&.customs_broker? && user.entity&.role_customs_agent? &&
      record.bl_house_line&.customs_agent_id == user.entity_id &&
      !record.bl_house_line.hidden_from_customs_agent?
  end

  def create?
    new?
  end

  def review?
    user&.admin_or_executive?
  end

  def preview_pdf?
    return true if user&.admin_or_executive?

    user&.customs_broker? && user.entity&.role_customs_agent? &&
      record.customs_agent_id == user.entity_id &&
      record.bl_house_line&.customs_agent_id == user.entity_id &&
      !record.bl_house_line.hidden_from_customs_agent?
  end
end
