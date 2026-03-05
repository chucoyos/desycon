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
      expect(policy.register_payment?).to eq(true)
    end
  end

  context 'when customs broker user' do
    let(:user) { create(:user, :customs_broker) }

    it 'denies manual issue and cancel' do
      expect(policy.show?).to eq(false)
      expect(policy.issue_manual?).to eq(false)
      expect(policy.cancel?).to eq(false)
      expect(policy.sync_documents?).to eq(false)
      expect(policy.register_payment?).to eq(false)
    end
  end
end
