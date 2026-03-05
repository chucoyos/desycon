require 'rails_helper'

RSpec.describe Facturador::RegisterInvoicePaymentService, type: :service do
  describe '.call' do
    let(:invoice) { create(:invoice, status: 'issued', sat_uuid: 'UUID-PAY') }

    before do
      allow(Facturador::IssuePaymentComplementService).to receive(:call)
    end

    it 'registers payment and triggers complement service' do
      payment = described_class.call(
        invoice: invoice,
        amount: 300,
        paid_at: Time.current,
        payment_method: '03',
        reference: 'PAY-123',
        notes: 'partial',
        actor: nil
      )

      expect(payment).to be_persisted
      expect(payment.invoice).to eq(invoice)
      expect(payment.amount.to_d).to eq(300.to_d)
      expect(Facturador::IssuePaymentComplementService).to have_received(:call).with(payment: payment, actor: nil)
    end
  end
end
