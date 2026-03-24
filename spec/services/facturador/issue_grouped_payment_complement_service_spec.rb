require "rails_helper"

RSpec.describe Facturador::IssueGroupedPaymentComplementService, type: :service do
  describe ".call" do
    let(:issuer) { create(:entity, :customs_agent) }
    let(:receiver) { create(:entity, :client) }
    let(:paid_at) { Time.zone.parse("2026-03-23 10:30:00") }

    let(:first_invoice) do
      create(
        :invoice,
        status: "issued",
        sat_uuid: "UUID-GROUP-001",
        issuer_entity: issuer,
        receiver_entity: receiver,
        payload_snapshot: { metodoPago: "PPD" }
      )
    end

    let(:second_invoice) do
      create(
        :invoice,
        status: "issued",
        sat_uuid: "UUID-GROUP-002",
        issuer_entity: issuer,
        receiver_entity: receiver,
        payload_snapshot: { metodoPago: "PPD" }
      )
    end

    let!(:first_payment) { create(:invoice_payment, invoice: first_invoice, amount: 300, paid_at: paid_at, payment_method: "03") }
    let!(:second_payment) { create(:invoice_payment, invoice: second_invoice, amount: 200, paid_at: paid_at, payment_method: "03") }

    before do
      allow_any_instance_of(Invoice).to receive(:queue_issue!).and_return(true)
    end

    it "creates one grouped complement invoice and queues all payments" do
      complement = described_class.call(payments: [ first_payment, second_payment ])

      expect(complement).to be_persisted
      expect(complement.kind).to eq("pago")
      expect(complement.total.to_d).to eq(500.to_d)

      grouped = complement.payload_snapshot.dig("metadataInterna", "grouped_payments")
      expect(grouped).to be_an(Array)
      expect(grouped.size).to eq(2)
      expect(grouped.map { |item| item["payment_id"] }).to match_array([ first_payment.id, second_payment.id ])

      expect(first_payment.reload.status).to eq("complement_queued")
      expect(second_payment.reload.status).to eq("complement_queued")
      expect(first_payment.complement_invoice_id).to eq(complement.id)
      expect(second_payment.complement_invoice_id).to eq(complement.id)
    end

    it "marks payments as failed when payments are incompatible" do
      second_payment.update!(payment_method: "28")

      expect do
        described_class.call(payments: [ first_payment, second_payment ])
      end.to raise_error(Facturador::RequestError, /same payment method/)

      expect(first_payment.reload.status).to eq("failed")
      expect(second_payment.reload.status).to eq("failed")
    end

    it "marks payments as failed when payment currencies are mixed" do
      second_payment.update_column(:currency, "USD")

      expect do
        described_class.call(payments: [ first_payment, second_payment ])
      end.to raise_error(Facturador::RequestError, /same payment currency/)

      expect(first_payment.reload.status).to eq("failed")
      expect(second_payment.reload.status).to eq("failed")
    end

    it "marks payments as failed when payment and invoice currencies do not match" do
      first_payment.update_column(:currency, "USD")
      second_payment.update_column(:currency, "USD")

      expect do
        described_class.call(payments: [ first_payment, second_payment ])
      end.to raise_error(Facturador::RequestError, /match source invoice currency/)

      expect(first_payment.reload.status).to eq("failed")
      expect(second_payment.reload.status).to eq("failed")
    end
  end
end
