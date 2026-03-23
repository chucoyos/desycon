require "rails_helper"

RSpec.describe "ConsolidatorPaymentEvidences", type: :request do
  let(:consolidator_user) { create(:user, :consolidator) }
  let(:consolidator_entity) { consolidator_user.entity }
  let(:invoice_one) { create(:invoice, status: "issued", receiver_entity: consolidator_entity) }
  let(:invoice_two) { create(:invoice, status: "issued", receiver_entity: consolidator_entity) }

  def uploaded_receipt
    file = Tempfile.new([ "receipt", ".pdf" ])
    file.write("%PDF-1.4 fake test receipt")
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "application/pdf")
  end

  describe "GET /consolidators/payment_evidences/new" do
    it "renders modal for selected consolidator invoices" do
      sign_in consolidator_user, scope: :user

      get new_consolidators_payment_evidence_path, params: { invoice_ids: [ invoice_one.id, invoice_two.id ] }, headers: { "Turbo-Frame" => "payment_evidence_modal" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Adjuntar comprobante para múltiples facturas")
      expect(response.body).to include(invoice_one.id.to_s)
      expect(response.body).to include(invoice_two.id.to_s)
    end
  end

  describe "POST /consolidators/payment_evidences" do
    it "creates one evidence and links multiple invoices" do
      sign_in consolidator_user, scope: :user

      expect do
        post consolidators_payment_evidences_path, params: {
          payment_evidence: {
            invoice_ids: [ invoice_one.id, invoice_two.id ],
            reference: "BLH-MULTI-100",
            tracking_key: "TRACK-MULTI-100",
            receipt_file: uploaded_receipt
          }
        }
      end.to change(InvoicePaymentEvidence, :count).by(1)
        .and change(InvoicePaymentEvidenceLink, :count).by(2)

      evidence = InvoicePaymentEvidence.order(:id).last
      expect(response).to redirect_to(invoices_path)
      expect(evidence.status).to eq("pending")
      expect(evidence.receipt_file).to be_attached
      expect(evidence.invoice_payment_evidence_links.pluck(:invoice_id)).to match_array([ invoice_one.id, invoice_two.id ])
    end

    it "rejects when one invoice does not belong to consolidator" do
      sign_in consolidator_user, scope: :user
      outsider = create(:invoice, status: "issued")

      expect do
        post consolidators_payment_evidences_path, params: {
          payment_evidence: {
            invoice_ids: [ invoice_one.id, outsider.id ],
            reference: "BLH-MULTI-OUT",
            receipt_file: uploaded_receipt
          }
        }
      end.not_to change(InvoicePaymentEvidence, :count)

      expect(response).to redirect_to(invoices_path)
      expect(flash[:alert]).to include("no son válidas")
    end
  end
end
