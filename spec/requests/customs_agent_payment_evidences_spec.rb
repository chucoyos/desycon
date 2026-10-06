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

  it "shows batch selection for eligible invoices in the invoice list" do
    sign_in customs_user, scope: :user
    agency_invoice = invoice

    get invoices_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("customs-agent-payment-evidence-batch-form")
    expect(response.body).to include(%(form="customs-agent-payment-evidence-batch-form"))
    expect(response.body).to include(%(value="#{agency_invoice.id}"))
  end

  it "renders the modal with multiple selected agency invoices" do
    sign_in customs_user, scope: :user
    second_invoice = create(:invoice, status: "issued", receiver_entity: client_entity)

    get new_customs_agents_payment_evidence_path,
      params: { invoice_ids: [ invoice.id, second_invoice.id ] },
      headers: { "Turbo-Frame" => "payment_evidence_modal" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Facturas seleccionadas")
    expect(response.body).to include("payment_evidence[invoice_ids][]")
    expect(response.body).to include(%(value="#{invoice.id}"))
    expect(response.body).to include(%(value="#{second_invoice.id}"))
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

  it "creates one payment evidence linked to multiple invoices in the agency scope" do
    sign_in customs_user, scope: :user
    second_invoice = create(:invoice, status: "issued", receiver_entity: client_entity)

    expect do
      post customs_agents_payment_evidences_path, params: {
        payment_evidence: {
          invoice_ids: [ invoice.id, second_invoice.id ],
          reference: "BLH-MULTI-100",
          tracking_key: "TRACK-MULTI-100",
          receipt_file: uploaded_receipt
        }
      }
    end.to change(InvoicePaymentEvidence, :count).by(1)
      .and change(InvoicePaymentEvidenceLink, :count).by(2)
      .and change(InvoicePayment, :count).by(0)

    evidence = InvoicePaymentEvidence.order(:id).last
    expect(response).to redirect_to(invoices_path)
    expect(evidence.status).to eq("pending")
    expect(evidence.receipt_file).to be_attached
    expect(evidence.invoice_payment_evidence_links.pluck(:invoice_id)).to match_array([ invoice.id, second_invoice.id ])
  end

  it "rejects a batch when one invoice is outside the customs agent scope" do
    sign_in customs_user, scope: :user
    outsider_client = create(:entity, :client)
    outsider_invoice = create(:invoice, status: "issued", receiver_entity: outsider_client)

    expect do
      post customs_agents_payment_evidences_path, params: {
        payment_evidence: {
          invoice_ids: [ invoice.id, outsider_invoice.id ],
          reference: "BLH-MULTI-OUT",
          receipt_file: uploaded_receipt
        }
      }
    end.not_to change(InvoicePaymentEvidence, :count)

    expect(response).to redirect_to(invoices_path)
    expect(flash[:alert]).to include("no son válidas")
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

  it "rejects REP invoices for payment evidence submission" do
    sign_in customs_user, scope: :user
    rep_invoice = create(:invoice, status: "issued", kind: "pago", receiver_entity: client_entity)

    expect do
      post customs_agents_payment_evidences_path, params: {
        payment_evidence: {
          invoice_id: rep_invoice.id,
          reference: "BLH-REP-001",
          receipt_file: uploaded_receipt
        }
      }
    end.not_to change(InvoicePaymentEvidence, :count)

    expect(response).to redirect_to(new_customs_agents_payment_evidence_path)
    expect(flash[:alert]).to include("Factura no valida")
  end
end
