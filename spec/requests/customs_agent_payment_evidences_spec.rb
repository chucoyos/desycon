require "rails_helper"

RSpec.describe "CustomsAgentPaymentEvidences", type: :request do
  let(:customs_user) { create(:user, :customs_broker) }
  let(:customs_agent) { customs_user.entity }
  let(:client_entity) { create(:entity, :client, customs_agent: customs_agent) }
  let(:invoice) { create(:invoice, status: "issued", receiver_entity: client_entity) }
  let(:admin_user) { create(:user, :admin) }

  before do
    admin_user
  end

  it "renders dedicated payment evidence page" do
    sign_in customs_user, scope: :user

    get new_customs_agents_payment_evidence_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Adjuntar comprobante de pago")
  end

  def uploaded_receipt
    file = Tempfile.new([ "receipt", ".pdf" ])
    file.write("%PDF-1.4 fake test receipt")
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "application/pdf")
  end

  it "creates payment evidence without creating invoice payment" do
    sign_in customs_user, scope: :user

    expect do
      post customs_agents_payment_evidences_path, params: {
        payment_evidence: {
          invoice_id: invoice.id,
          reference: "BLH-10001",
          tracking_key: "TRACK-10001",
          receipt_file: uploaded_receipt
        }
      }
    end.to change(InvoicePaymentEvidence, :count).by(1)
      .and change(InvoicePayment, :count).by(0)

    expect(response).to redirect_to(new_customs_agents_payment_evidence_path)
    expect(flash[:notice]).to include("ha sido enviado")

    evidence = InvoicePaymentEvidence.order(:id).last
    expect(evidence.invoice_id).to eq(invoice.id)
    expect(evidence.reference).to eq("BLH-10001")
    expect(evidence.status).to eq("pending")
    expect(evidence.receipt_file).to be_attached
  end

  it "rejects invoice outside customs agent scope" do
    sign_in customs_user, scope: :user
    outsider_client = create(:entity, :client)
    outsider_invoice = create(:invoice, status: "issued", receiver_entity: outsider_client)

    expect do
      post customs_agents_payment_evidences_path, params: {
        payment_evidence: {
          invoice_id: outsider_invoice.id,
          reference: "BLH-OUTSIDE",
          receipt_file: uploaded_receipt
        }
      }
    end.not_to change(InvoicePaymentEvidence, :count)

    expect(response).to redirect_to(new_customs_agents_payment_evidence_path)
    expect(flash[:alert]).to include("Factura no valida")
  end

  it "rejects fully paid invoice even if it belongs to customs agent scope" do
    sign_in customs_user, scope: :user
    fully_paid_invoice = create(:invoice, status: "issued", receiver_entity: client_entity)
    create(:invoice_payment, invoice: fully_paid_invoice, amount: fully_paid_invoice.total, status: "complement_issued")

    expect do
      post customs_agents_payment_evidences_path, params: {
        payment_evidence: {
          invoice_id: fully_paid_invoice.id,
          reference: "BLH-FULL-PAID",
          receipt_file: uploaded_receipt
        }
      }
    end.not_to change(InvoicePaymentEvidence, :count)

    expect(response).to redirect_to(new_customs_agents_payment_evidence_path)
    expect(flash[:alert]).to include("Factura no valida")
  end
end
