module CustomsAgents
  class RecalculateAccessRestrictionsJob < ApplicationJob
    queue_as :default

    RECURRING_TASK_KEY = "customs_agents_recalculate_access_restrictions".freeze
    MIN_GLOBAL_RECALC_INTERVAL = 7.hours
    ADVISORY_LOCK_KEY = 1_204_202_601

    def perform(customs_agent_id: nil, force: false)
      if customs_agent_id.present?
        customs_agent = Entity.find_by(id: customs_agent_id)
        return unless customs_agent

        CustomsAgents::RestrictionEvaluatorService.call(customs_agent: customs_agent)
        return
      end

      with_global_lock do
        if !force && global_recently_executed?
          Rails.logger.info("[CustomsAgents::RecalculateAccessRestrictionsJob] Skipping: recently executed")
          next
        end

        Entity.customs_agents.with_overdue_rule_enabled.find_each do |customs_agent|
          CustomsAgents::RestrictionEvaluatorService.call(customs_agent: customs_agent)
        end
      end
    end

    private

    def with_global_lock
      return yield unless postgres_database?

      conn = ActiveRecord::Base.connection
      lock_acquired = conn.select_value("SELECT pg_try_advisory_lock(#{ADVISORY_LOCK_KEY})")
      return unless ActiveRecord::Type::Boolean.new.cast(lock_acquired)

      yield
    ensure
      conn&.select_value("SELECT pg_advisory_unlock(#{ADVISORY_LOCK_KEY})") if lock_acquired
    end

    def global_recently_executed?
      last_run_at = last_recurring_execution_at
      return false if last_run_at.blank?

      last_run_at >= MIN_GLOBAL_RECALC_INTERVAL.ago
    end

    def last_recurring_execution_at
      SolidQueue::RecurringExecution.where(task_key: RECURRING_TASK_KEY).maximum(:run_at)
    rescue StandardError
      nil
    end

    def postgres_database?
      ActiveRecord::Base.connection.adapter_name.casecmp("PostgreSQL").zero?
    end
  end
end
