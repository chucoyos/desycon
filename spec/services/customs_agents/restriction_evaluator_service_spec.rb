require "rails_helper"

RSpec.describe CustomsAgents::RestrictionEvaluatorService, type: :service do
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
