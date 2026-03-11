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

  describe '#effective_status' do
    it 'returns issued for cancel_pending invoices with uuid' do
      invoice = create(:invoice, status: 'cancel_pending', sat_uuid: 'UUID-001')

      expect(invoice.effective_status).to eq('issued')
      expect(invoice.effectively_issued?).to be(true)
    end

    it 'returns issued for failed invoices with uuid when not cancelled' do
      invoice = create(:invoice, status: 'failed', sat_uuid: 'UUID-002')

      expect(invoice.effective_status).to eq('issued')
    end

    it 'keeps cancelled invoices as cancelled' do
      invoice = create(:invoice, status: 'cancelled', sat_uuid: 'UUID-003')

      expect(invoice.effective_status).to eq('cancelled')
    end
  end

  describe '#payment_status' do
    it 'returns pending when there are no payments' do
      invoice = create(:invoice, status: 'issued', total: 1000)

      expect(invoice.payment_status).to eq('pending')
      expect(invoice.payment_status_label).to eq('Pendiente')
    end

    it 'returns partial when paid amount is below total' do
      invoice = create(:invoice, status: 'issued', total: 1000)
      create(:invoice_payment, invoice: invoice, amount: 400, status: 'registered')

      expect(invoice.payment_status).to eq('partial')
      expect(invoice.payment_status_label).to eq('Parcial')
    end

    it 'returns paid when paid amount reaches total' do
      invoice = create(:invoice, status: 'issued', total: 1000)
      create(:invoice_payment, invoice: invoice, amount: 1000, status: 'registered')

      expect(invoice.payment_status).to eq('paid')
      expect(invoice.payment_status_label).to eq('Pagado')
    end
  end
end
