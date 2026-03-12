module CustomsAgents
  class RecalculateAccessRestrictionsJob < ApplicationJob
    queue_as :default

    def perform(customs_agent_id: nil)
      if customs_agent_id.present?
        customs_agent = Entity.find_by(id: customs_agent_id)
        return unless customs_agent

        CustomsAgents::RestrictionEvaluatorService.call(customs_agent: customs_agent)
        return
      end

      Entity.customs_agents.with_overdue_rule_enabled.find_each do |customs_agent|
        CustomsAgents::RestrictionEvaluatorService.call(customs_agent: customs_agent)
      end
    end
  end
end
