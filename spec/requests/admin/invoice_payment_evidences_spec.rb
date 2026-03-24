require "rails_helper"
require "ostruct"

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

    it "limits evidences to the last week by default" do
      sign_in admin_user, scope: :user

      recent_evidence = create(
        :invoice_payment_evidence,
        invoice: invoice,
        customs_agent: customs_agent,
        submitted_by: customs_user,
        reference: "REF-RECENT-ONE-MONTH",
        created_at: 5.days.ago
      )
      create(
        :invoice_payment_evidence,
        invoice: invoice,
        customs_agent: customs_agent,
        submitted_by: customs_user,
        reference: "REF-OLD-OUTSIDE-MONTH",
        created_at: 2.months.ago
      )

      get admin_invoice_payment_evidences_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(recent_evidence.reference)
      expect(response.body).not_to include("REF-OLD-OUTSIDE-MONTH")
    end

    it "filters evidences by the selected date range" do
      sign_in admin_user, scope: :user

      target_date = 2.months.ago.to_date
      create(
        :invoice_payment_evidence,
        invoice: invoice,
        customs_agent: customs_agent,
        submitted_by: customs_user,
        reference: "REF-IN-RANGE",
        created_at: target_date.noon
      )
      create(
        :invoice_payment_evidence,
        invoice: invoice,
        customs_agent: customs_agent,
        submitted_by: customs_user,
        reference: "REF-OUT-RANGE",
        created_at: 5.days.ago
      )

      get admin_invoice_payment_evidences_path, params: {
        start_date: (target_date - 1.day).iso8601,
        end_date: (target_date + 1.day).iso8601
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("REF-IN-RANGE")
      expect(response.body).not_to include("REF-OUT-RANGE")
    end
  end

  describe "GET /admin/invoice_payment_evidences/:id" do
    it "renders linked invoice navigation to invoice show without selection link" do
      sign_in admin_user, scope: :user

      get admin_invoice_payment_evidence_path(evidence)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(invoice_path(invoice))
      expect(response.body).not_to include("Seleccionar")
    end
  end

  describe "PATCH /admin/invoice_payment_evidences/:id/reject" do
    it "rejects evidence with mandatory comment" do
      sign_in admin_user, scope: :user

      expect do
        patch reject_admin_invoice_payment_evidence_path(evidence), params: {
          review_comment: "Comprobante ilegible"
        }
      end.to change {
        Notification.where(recipient: customs_user, notifiable: evidence).count
      }.by(1)

      evidence.reload
      expect(response).to redirect_to(admin_invoice_payment_evidence_path(evidence))
      expect(evidence.status).to eq("rejected")
      expect(evidence.review_comment).to eq("Comprobante ilegible")

      rejection_notification = Notification.where(recipient: customs_user, notifiable: evidence).order(:id).last
      expect(rejection_notification.action).to include("rechazo evidencia de pago")
      expect(rejection_notification.action).to include("Motivo: Comprobante ilegible")
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
      expect(response).to redirect_to(invoice_invoice_payment_path(invoice, payment))
      expect(evidence.status).to eq("linked")
      expect(evidence.invoice_payment_id).to eq(payment.id)
      expect(evidence.review_comment).to include("Registrado por ejecutivo")
    end

    it "registers grouped payments for multi-invoice evidence" do
      sign_in admin_user, scope: :user

      second_invoice = create(:invoice, status: "issued", receiver_entity: client_entity)
      create(:invoice_payment_evidence_link, invoice_payment_evidence: evidence, invoice: invoice)
      create(:invoice_payment_evidence_link, invoice_payment_evidence: evidence, invoice: second_invoice)

      first_payment = create(:invoice_payment, invoice: invoice)
      grouped_result = OpenStruct.new(payments: [ first_payment ], complement_invoice: nil)

      expect(Facturador::RegisterGroupedInvoicePaymentsService).to receive(:call).with(
        evidence: evidence,
        invoice_amounts: {
          invoice.id.to_s => "500.00",
          second_invoice.id.to_s => "300.00"
        },
        paid_at: Date.current.iso8601,
        payment_method: "03",
        reference: "BLH-GROUP-001",
        tracking_key: "TRACK-GROUP-001",
        notes: "Pago agrupado",
        actor: admin_user
      ).and_return(grouped_result)

      post register_payment_admin_invoice_payment_evidence_path(evidence), params: {
        register_payment: {
          invoice_amounts: {
            invoice.id.to_s => "500.00",
            second_invoice.id.to_s => "300.00"
          },
          paid_at: Date.current.iso8601,
          payment_method: "03",
          reference: "BLH-GROUP-001",
          tracking_key: "TRACK-GROUP-001",
          notes: "Pago agrupado",
          review_comment: "Registrado en bloque"
        }
      }

      evidence.reload
      expect(response).to redirect_to(admin_invoice_payment_evidence_path(evidence))
      expect(evidence.status).to eq("linked")
      expect(evidence.invoice_payment_id).to eq(first_payment.id)
      expect(evidence.review_comment).to include("Registrado en bloque")
      expect(evidence.review_comment).to include("2 facturas")
    end
  end
end
