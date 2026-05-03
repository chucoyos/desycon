require "rails_helper"

RSpec.describe Facturador::RequestPaymentComplementService, type: :service do
  describe ".call" do
    let(:admin_user) { create(:user, :admin) }
    let(:invoice) do
      create(
        :invoice,
        status: "issued",
        sat_uuid: "UUID-SOURCE-REQ-REP-001",
        payload_snapshot: { metodoPago: "PPD" }
      )
    end
    let(:payment) { create(:invoice_payment, invoice: invoice, status: "registered") }

    before do
      allow(Facturador::Config).to receive(:enabled?).and_return(true)
      allow(Facturador::Config).to receive(:payment_complements_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:manual_actions_enabled?).and_return(true)
      allow(Facturador::IssuePaymentComplementService).to receive(:call).and_return(payment)
    end

    it "queues REP manually for an eligible payment" do
      described_class.call(payment: payment, actor: admin_user)

      expect(Facturador::IssuePaymentComplementService).to have_received(:call).with(payment: payment, actor: admin_user)
      expect(invoice.invoice_events.where(event_type: "payment_complement_manual_requested")).to be_present
      expect(invoice.invoice_events.where(event_type: "payment_complement_manual_queued")).to be_present
    end

    it "blocks manual request when payment already has a complement invoice" do
      complement = create(:invoice, kind: "pago", status: "failed", sat_uuid: nil)
      payment.update!(complement_invoice: complement)

      expect do
        described_class.call(payment: payment, actor: admin_user)
      end.to raise_error(Facturador::RequestPaymentComplementService::DuplicateComplementError)

      expect(Facturador::IssuePaymentComplementService).not_to have_received(:call)
      expect(invoice.invoice_events.where(event_type: "payment_complement_manual_blocked_duplicate")).to be_present
    end

    it "rejects when complements are disabled" do
      allow(Facturador::Config).to receive(:payment_complements_enabled?).and_return(false)

      expect do
        described_class.call(payment: payment, actor: admin_user)
      end.to raise_error(Facturador::RequestError, /deshabilitados/)

      expect(Facturador::IssuePaymentComplementService).not_to have_received(:call)
    end

    it "rejects non-PPD invoices" do
      invoice.update!(payload_snapshot: { metodoPago: "PUE" })

      expect do
        described_class.call(payment: payment, actor: admin_user)
      end.to raise_error(Facturador::RequestError, /PPD/)

      expect(Facturador::IssuePaymentComplementService).not_to have_received(:call)
    end
  end
end
