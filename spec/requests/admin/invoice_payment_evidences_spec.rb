require "rails_helper"

RSpec.describe "Admin::InvoicePaymentEvidences", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:executive_user) { create(:user, :executive) }
  let(:customs_user) { create(:user, :customs_broker) }
  let(:customs_agent) { customs_user.entity }
  let(:client_entity) { create(:entity, :client, customs_agent: customs_agent) }
  let(:invoice) { create(:invoice, status: "issued", receiver_entity: client_entity) }
  let!(:evidence) do
    create(
      :invoice_payment_evidence,
      invoice: invoice,
      customs_agent: customs_agent,
      submitted_by: customs_user,
      status: "pending"
    )
  end

  describe "GET /admin/invoice_payment_evidences" do
    it "allows admin users" do
      sign_in admin_user, scope: :user

      get admin_invoice_payment_evidences_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Evidencias de pago")
    end

    it "allows executive users" do
      sign_in executive_user, scope: :user

      get admin_invoice_payment_evidences_path

      expect(response).to have_http_status(:success)
    end

    it "rejects customs users" do
      sign_in customs_user, scope: :user

      get admin_invoice_payment_evidences_path

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end
  end

  describe "PATCH /admin/invoice_payment_evidences/:id/link_payment" do
    it "links evidence to existing payment from same invoice" do
      sign_in admin_user, scope: :user
      payment = create(:invoice_payment, invoice: invoice)

      patch link_payment_admin_invoice_payment_evidence_path(evidence), params: {
        invoice_payment_id: payment.id,
        review_comment: "Validado contra movimiento bancario"
      }

      evidence.reload
      expect(response).to redirect_to(admin_invoice_payment_evidence_path(evidence))
      expect(evidence.status).to eq("linked")
      expect(evidence.invoice_payment_id).to eq(payment.id)
    end
  end

  describe "PATCH /admin/invoice_payment_evidences/:id/reject" do
    it "rejects evidence with mandatory comment" do
      sign_in admin_user, scope: :user

      patch reject_admin_invoice_payment_evidence_path(evidence), params: {
        review_comment: "Comprobante ilegible"
      }

      evidence.reload
      expect(response).to redirect_to(admin_invoice_payment_evidence_path(evidence))
      expect(evidence.status).to eq("rejected")
      expect(evidence.review_comment).to eq("Comprobante ilegible")
    end
  end

  describe "POST /admin/invoice_payment_evidences/:id/register_payment" do
    it "registers a payment and links the evidence" do
      sign_in admin_user, scope: :user

      payment = create(:invoice_payment, invoice: invoice)
      expect(Facturador::RegisterInvoicePaymentService).to receive(:call).with(
        invoice: evidence.invoice,
        amount: "500.00",
        paid_at: Date.current.iso8601,
        payment_method: "03",
        reference: "BLH-20001",
        tracking_key: "TRACK-ADMIN-001",
        notes: "Pago confirmado",
        actor: admin_user
      ).and_return(payment)

      post register_payment_admin_invoice_payment_evidence_path(evidence), params: {
        register_payment: {
          amount: "500.00",
          paid_at: Date.current.iso8601,
          payment_method: "03",
          reference: "BLH-20001",
          tracking_key: "TRACK-ADMIN-001",
          notes: "Pago confirmado",
          review_comment: "Registrado por ejecutivo"
        }
      }

      evidence.reload
      expect(response).to redirect_to(admin_invoice_payment_evidence_path(evidence))
      expect(evidence.status).to eq("linked")
      expect(evidence.invoice_payment_id).to eq(payment.id)
      expect(evidence.review_comment).to include("Registrado por ejecutivo")
    end
  end
end
