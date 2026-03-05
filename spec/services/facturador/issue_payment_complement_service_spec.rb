require 'rails_helper'

RSpec.describe Facturador::IssuePaymentComplementService, type: :service do
  describe '.call' do
    let(:invoice) { create(:invoice, status: 'issued', sat_uuid: 'UUID-I') }
    let(:payment) { create(:invoice_payment, invoice: invoice, amount: 200) }

    before do
      allow(Facturador::Config).to receive(:enabled?).and_return(true)
      allow(Facturador::Config).to receive(:payment_complements_enabled?).and_return(true)
      allow_any_instance_of(Invoice).to receive(:queue_issue!).and_return(true)
    end

    it 'creates complement invoice and queues issue' do
      described_class.call(payment: payment)

      payment.reload
      expect(payment.complement_invoice).to be_present
      expect(payment.status).to eq('complement_queued')
      expect(payment.complement_invoice.kind).to eq('pago')
    end
  end
end
