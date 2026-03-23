require "rails_helper"

RSpec.describe Facturador::RegisterGroupedInvoicePaymentsService, type: :service do
  describe ".call" do
    let(:admin_user) { create(:user, :admin) }
    let(:customs_agent) { create(:entity, :customs_agent) }
    let(:receiver) { create(:entity, :client) }
    let(:paid_at) { Date.current.iso8601 }

    let(:first_invoice) do
      create(
        :invoice,
        status: "issued",
        sat_uuid: "UUID-REG-001",
        issuer_entity: customs_agent,
        receiver_entity: receiver,
        payload_snapshot: { metodoPago: "PPD" }
      )
    end

    let(:second_invoice) do
      create(
        :invoice,
        status: "issued",
        sat_uuid: "UUID-REG-002",
        issuer_entity: customs_agent,
        receiver_entity: receiver,
        payload_snapshot: { metodoPago: "PPD" }
      )
    end

    let(:evidence) do
      create(
        :invoice_payment_evidence,
        invoice: first_invoice,
        customs_agent: customs_agent,
        submitted_by: admin_user
      )
    end

    before do
      create(:invoice_payment_evidence_link, invoice_payment_evidence: evidence, invoice: first_invoice)
      create(:invoice_payment_evidence_link, invoice_payment_evidence: evidence, invoice: second_invoice)
      evidence.reload
      allow(Facturador::IssuePaymentComplementService).to receive(:call)
    end

    it "registers all payments and requests one grouped REP when all are PPD" do
      payment_one = create(:invoice_payment, invoice: first_invoice, amount: 500, paid_at: Time.current, payment_method: "03")
      payment_two = create(:invoice_payment, invoice: second_invoice, amount: 300, paid_at: Time.current, payment_method: "03")
      grouped_complement = create(
        :invoice,
        kind: "pago",
        status: "queued",
        issuer_entity: customs_agent,
        receiver_entity: receiver,
        subtotal: 800,
        tax_total: 0,
        total: 800
      )

      allow(Facturador::RegisterInvoicePaymentService).to receive(:call).and_return(payment_one, payment_two)
      allow(Facturador::IssueGroupedPaymentComplementService).to receive(:call).and_return(grouped_complement)

      result = described_class.call(
        evidence: evidence,
        invoice_amounts: {
          first_invoice.id.to_s => "500.00",
          second_invoice.id.to_s => "300.00"
        },
        paid_at: paid_at,
        payment_method: "03",
        reference: "REF-GROUP-001",
        tracking_key: "TRACK-GROUP-001",
        notes: "Registro agrupado",
        actor: admin_user
      )

      expect(result.payments).to match_array([ payment_one, payment_two ])
      expect(result.complement_invoice).to eq(grouped_complement)
      expect(Facturador::IssueGroupedPaymentComplementService).to have_received(:call).once
      expect(Facturador::IssuePaymentComplementService).not_to have_received(:call)
      expect(Facturador::RegisterInvoicePaymentService).to have_received(:call).with(hash_including(invoice: first_invoice, issue_payment_complement: false))
      expect(Facturador::RegisterInvoicePaymentService).to have_received(:call).with(hash_including(invoice: second_invoice, issue_payment_complement: false))
    end

    it "falls back to individual REP issuance for mixed eligibility" do
      second_invoice.update!(payload_snapshot: { metodoPago: "PUE" })

      payment_one = create(:invoice_payment, invoice: first_invoice, amount: 500, paid_at: Time.current, payment_method: "03")
      payment_two = create(:invoice_payment, invoice: second_invoice, amount: 300, paid_at: Time.current, payment_method: "03")

      allow(Facturador::RegisterInvoicePaymentService).to receive(:call).and_return(payment_one, payment_two)
      allow(Facturador::IssueGroupedPaymentComplementService).to receive(:call)

      result = described_class.call(
        evidence: evidence,
        invoice_amounts: {
          first_invoice.id.to_s => "500.00",
          second_invoice.id.to_s => "300.00"
        },
        paid_at: paid_at,
        payment_method: "03",
        actor: admin_user
      )

      expect(result.payments).to match_array([ payment_one, payment_two ])
      expect(result.complement_invoice).to be_nil
      expect(Facturador::IssueGroupedPaymentComplementService).not_to have_received(:call)
      expect(Facturador::IssuePaymentComplementService).to have_received(:call).with(payment: payment_one, actor: admin_user).once
      expect(Facturador::IssuePaymentComplementService).not_to have_received(:call).with(payment: payment_two, actor: admin_user)
    end

    it "fails when all selected amounts are zero" do
      expect do
        described_class.call(
          evidence: evidence,
          invoice_amounts: {
            first_invoice.id.to_s => "0",
            second_invoice.id.to_s => "0"
          },
          paid_at: paid_at,
          payment_method: "03",
          actor: admin_user
        )
      end.to raise_error(Facturador::RequestError, /monto mayor a cero/)
    end
  end
end
