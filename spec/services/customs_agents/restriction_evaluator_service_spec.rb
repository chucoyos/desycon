require "rails_helper"

RSpec.describe CustomsAgents::RestrictionEvaluatorService, type: :service do
  include ActiveJob::TestHelper

  describe ".call" do
    let(:agency) { create(:entity, :customs_agent, enforce_overdue_payment_rule: true) }

    it "does not restrict when only overdue invoices are cancel_pending" do
      create(
        :invoice,
        status: "cancel_pending",
        issued_at: 10.days.ago,
        total: 1_000,
        customs_agent: agency,
        receiver_entity: create(:entity, :client)
      )

      result = described_class.call(customs_agent: agency)

      expect(result.restricted).to eq(false)
      expect(result.overdue_unpaid_count).to eq(0)
      expect(agency.reload.restricted_access_for_overdue_rule?).to eq(false)
    end

    it "does not restrict when only overdue invoices are cancelled" do
      create(
        :invoice,
        status: "cancelled",
        issued_at: 10.days.ago,
        total: 1_000,
        customs_agent: agency,
        receiver_entity: create(:entity, :client)
      )

      result = described_class.call(customs_agent: agency)

      expect(result.restricted).to eq(false)
      expect(result.overdue_unpaid_count).to eq(0)
      expect(agency.reload.restricted_access_for_overdue_rule?).to eq(false)
    end

    %w[cancel_pending cancelled].each do |cancellation_status|
      it "removes an existing overdue restriction after the invoice becomes #{cancellation_status}" do
        invoice = create(
          :invoice,
          status: "issued",
          issued_at: 10.days.ago,
          total: 1_000,
          customs_agent: agency,
          receiver_entity: create(:entity, :client)
        )

        result = described_class.call(customs_agent: agency)
        expect(result.restricted).to eq(true)
        expect(agency.reload.restricted_access_for_overdue_rule?).to eq(true)

        if cancellation_status == "cancel_pending"
          invoice.mark_cancel_pending!(motive: "02")
        else
          invoice.mark_cancelled!(cancelled_at: Time.current)
        end

        result = described_class.call(customs_agent: agency)
        expect(result.restricted).to eq(false)
        expect(result.overdue_unpaid_count).to eq(0)
        expect(agency.reload.restricted_access_enabled?).to eq(false)
        expect(agency.restricted_access_reason).to be_nil
      end

      it "reevaluates the agency after committing a change to #{cancellation_status}" do
        invoice = create(:invoice, status: "issued", issued_at: 10.days.ago, total: 1_000,
          customs_agent: agency, receiver_entity: create(:entity, :client))
        described_class.call(customs_agent: agency)
        expect(agency.reload.restricted_access_for_overdue_rule?).to eq(true)

        perform_enqueued_jobs(only: CustomsAgents::RecalculateAccessRestrictionsJob) do
          if cancellation_status == "cancel_pending"
            invoice.mark_cancel_pending!(motive: "02")
          else
            invoice.mark_cancelled!(cancelled_at: Time.current)
          end
        end

        expect(agency.reload.restricted_access_enabled?).to eq(false)
      end
    end

    it "reevaluates when a pending cancellation returns to issued" do
      invoice = create(:invoice, status: "cancel_pending", issued_at: 10.days.ago, total: 1_000,
        customs_agent: agency, receiver_entity: create(:entity, :client))

      perform_enqueued_jobs(only: CustomsAgents::RecalculateAccessRestrictionsJob) do
        invoice.mark_cancel_failed_attempt!(error_code: "FACTURADOR_CANCEL_ERROR", error_message: "Rechazada")
      end

      expect(agency.reload.restricted_access_for_overdue_rule?).to eq(true)
    end

    it "keeps the restriction when another overdue unpaid invoice remains after cancellation" do
      invoices = create_list(
        :invoice, 2,
        status: "issued",
        issued_at: 10.days.ago,
        total: 1_000,
        customs_agent: agency,
        receiver_entity: create(:entity, :client)
      )
      expect(described_class.call(customs_agent: agency).overdue_unpaid_count).to eq(2)

      invoices.first.mark_cancelled!(cancelled_at: Time.current)
      result = described_class.call(customs_agent: agency)

      expect(result.restricted).to eq(true)
      expect(result.overdue_unpaid_count).to eq(1)
      expect(agency.reload.restricted_access_for_overdue_rule?).to eq(true)
    end

    it "keeps restricting for overdue unpaid issued invoices" do
      create(
        :invoice,
        status: "issued",
        issued_at: 10.days.ago,
        total: 1_000,
        customs_agent: agency,
        receiver_entity: create(:entity, :client)
      )

      result = described_class.call(customs_agent: agency)

      expect(result.restricted).to eq(true)
      expect(result.overdue_unpaid_count).to eq(1)
      expect(agency.reload.restricted_access_for_overdue_rule?).to eq(true)
    end

    it "does not restrict for overdue issued egreso invoices" do
      create(
        :invoice,
        kind: "egreso",
        status: "issued",
        issued_at: 10.days.ago,
        total: 1_000,
        customs_agent: agency,
        receiver_entity: create(:entity, :client)
      )

      result = described_class.call(customs_agent: agency)

      expect(result.restricted).to eq(false)
      expect(result.overdue_unpaid_count).to eq(0)
      expect(agency.reload.restricted_access_for_overdue_rule?).to eq(false)
    end

    it "restricts for overdue unpaid invoices where agency is the receiver's customs_agent (indirect)" do
      client = create(:entity, :client, customs_agent: agency)
      create(
        :invoice,
        status: "issued",
        issued_at: 10.days.ago,
        total: 1_000,
        receiver_entity: client
      )

      result = described_class.call(customs_agent: agency)

      expect(result.restricted).to eq(true)
      expect(result.overdue_unpaid_count).to eq(1)
      expect(agency.reload.restricted_access_for_overdue_rule?).to eq(true)
    end
  end
end
