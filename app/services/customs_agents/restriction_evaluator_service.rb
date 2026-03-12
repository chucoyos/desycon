module CustomsAgents
  class RestrictionEvaluatorService
    Result = Struct.new(:restricted, :overdue_unpaid_count, keyword_init: true)

    BUSINESS_HOURS_TO_RESTRICT = 72

    class << self
      def call(customs_agent:)
        return Result.new(restricted: false, overdue_unpaid_count: 0) unless applicable_customs_agent?(customs_agent)

        overdue_unpaid = overdue_unpaid_invoices_for(customs_agent)
        should_restrict = overdue_unpaid.any?

        if should_restrict
          customs_agent.set_restricted_access!(
            enabled: true,
            reason: Entity::RESTRICTED_ACCESS_REASON_OVERDUE_INVOICES
          ) unless customs_agent.restricted_access_for_overdue_rule?
        elsif customs_agent.restricted_access_for_overdue_rule?
          customs_agent.set_restricted_access!(enabled: false, reason: nil)
        end

        Result.new(restricted: should_restrict, overdue_unpaid_count: overdue_unpaid.size)
      end

      private

      def applicable_customs_agent?(customs_agent)
        customs_agent.present? && customs_agent.role_customs_agent? && customs_agent.enforce_overdue_payment_rule?
      end

      def overdue_unpaid_invoices_for(customs_agent)
        base_invoices_for(customs_agent).select do |invoice|
          overdue_by_business_hours?(invoice) && unpaid?(invoice)
        end
      end

      def base_invoices_for(customs_agent)
        Invoice
          .joins(:receiver_entity)
          .where(
            "invoices.customs_agent_id = :agency_id OR entities.customs_agent_id = :agency_id",
            agency_id: customs_agent.id
          )
          .where.not(status: "cancelled")
          .where.not(issued_at: nil)
          .distinct
      end

      def overdue_by_business_hours?(invoice)
        deadline = BusinessHoursService.add_weekday_hours(
          from_time: invoice.issued_at,
          hours: BUSINESS_HOURS_TO_RESTRICT
        )

        Time.zone.now >= deadline
      end

      def unpaid?(invoice)
        invoice.payment_status != "paid"
      end
    end
  end
end
