require 'rails_helper'

RSpec.describe Invoice, type: :model do
  describe 'associations' do
    it 'belongs to invoiceable' do
      invoice = build(:invoice)
      expect(invoice).to respond_to(:invoiceable)
    end

    it 'has many invoice_events' do
      invoice = create(:invoice)
      expect(invoice).to respond_to(:invoice_events)
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(build(:invoice)).to be_valid
    end

    it 'generates idempotency_key before validation' do
      invoice = build(:invoice, idempotency_key: nil)
      invoice.validate

      expect(invoice.idempotency_key).to be_present
    end
  end

  describe '#queue_issue!' do
    it 'returns false when facturador is disabled' do
      allow(Facturador::Config).to receive(:enabled?).and_return(false)

      invoice = create(:invoice)
      expect(invoice.queue_issue!).to eq(false)
      expect(invoice.status).to eq('draft')
    end
  end
end
