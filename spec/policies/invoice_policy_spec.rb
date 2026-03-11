require 'rails_helper'

RSpec.describe InvoicePolicy, type: :policy do
  subject(:policy) { described_class.new(user, invoice) }

  let(:invoice) { build(:invoice) }

  context 'when admin/executive user' do
    let(:user) { create(:user, :executive) }

    it 'allows manual issue and cancel' do
      expect(policy.show?).to eq(true)
      expect(policy.issue_manual?).to eq(true)
      expect(policy.cancel?).to eq(true)
      expect(policy.sync_documents?).to eq(true)
      expect(policy.sync_files?).to eq(true)
      expect(policy.register_payment?).to eq(true)
      expect(policy.send_email?).to eq(true)
    end
  end

  context 'when customs broker user' do
    let(:agency) { create(:entity, :customs_agent) }
    let(:user) { create(:user, :customs_broker, entity: agency) }

    it 'allows show only for related invoices and denies management actions' do
      related_invoice = build(:invoice, receiver_entity: build(:entity, :client, customs_agent: agency))
      unrelated_invoice = build(:invoice, receiver_entity: build(:entity, :client, customs_agent: build(:entity, :customs_agent)))

      expect(described_class.new(user, related_invoice).show?).to eq(true)
      expect(described_class.new(user, unrelated_invoice).show?).to eq(false)
      expect(described_class.new(user, related_invoice).sync_files?).to eq(true)
      expect(described_class.new(user, unrelated_invoice).sync_files?).to eq(false)
      expect(policy.index?).to eq(true)
      expect(policy.issue_manual?).to eq(false)
      expect(policy.cancel?).to eq(false)
      expect(policy.sync_documents?).to eq(false)
      expect(policy.register_payment?).to eq(false)
      expect(policy.send_email?).to eq(false)
    end

    it 'limits scope to related invoices only' do
      related_invoice = create(:invoice, receiver_entity: create(:entity, :client, customs_agent: agency))
      unrelated_invoice = create(:invoice, receiver_entity: create(:entity, :client, customs_agent: create(:entity, :customs_agent)))

      resolved = described_class::Scope.new(user, Invoice.all).resolve

      expect(resolved).to include(related_invoice)
      expect(resolved).not_to include(unrelated_invoice)
    end
  end
end
