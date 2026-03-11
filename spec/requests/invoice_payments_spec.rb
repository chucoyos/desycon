require 'rails_helper'

RSpec.describe 'InvoicePayments', type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:invoice) { create(:invoice, status: 'issued') }
  let(:payment) { create(:invoice_payment, invoice: invoice, status: 'registered') }

  before { sign_in admin_user, scope: :user }

  describe 'GET /invoices/:invoice_id/invoice_payments/:id' do
    it 'renders show successfully' do
      get invoice_invoice_payment_path(invoice, payment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Pago ##{payment.id}")
      expect(response.body).to include(payment.reference)
      expect(response.body).to include('Volver a evidencias')
    end

    it 'shows agency evidence details when payment has linked evidence' do
      customs_user = create(:user, :customs_broker)
      evidence = create(
        :invoice_payment_evidence,
        invoice: invoice,
        invoice_payment: payment,
        customs_agent: customs_user.entity,
        submitted_by: customs_user,
        reference: 'BLH-EVID-001',
        tracking_key: 'TRACK-EVID-001'
      )

      get invoice_invoice_payment_path(invoice, payment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Evidencia enviada por agencia')
      expect(response.body).to include(evidence.reference)
      expect(response.body).to include(evidence.tracking_key)
      expect(response.body).to include('Ver comprobante')
      expect(response.body).to include('Descargar comprobante')
    end
  end

  describe 'GET /invoices/:invoice_id/invoice_payments/:id/edit' do
    it 'renders edit successfully' do
      get edit_invoice_invoice_payment_path(invoice, payment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Editar pago ##{payment.id}")
    end

    it 'blocks editing when payment is linked to complement' do
      complement = create(:invoice, kind: 'pago', status: 'issued')
      payment.update!(status: 'complement_issued', complement_invoice: complement)

      get edit_invoice_invoice_payment_path(invoice, payment)

      expect(response).to redirect_to(invoice_path(invoice, anchor: 'payments-section'))
      expect(flash[:alert]).to be_present
    end
  end

  describe 'PATCH /invoices/:invoice_id/invoice_payments/:id' do
    it 'updates payment' do
      patch invoice_invoice_payment_path(invoice, payment), params: {
        invoice_payment: {
          amount: 650.25,
          reference: 'REF-UPDATED'
        }
      }

      expect(response).to redirect_to(invoice_path(invoice, anchor: 'payments-section'))
      expect(payment.reload.amount.to_f).to eq(650.25)
      expect(payment.reference).to eq('REF-UPDATED')
    end

    it 'updates tracking key and attaches receipt file' do
      receipt = Tempfile.new([ 'payment-edit-receipt', '.pdf' ])
      receipt.write('%PDF-1.4 edited receipt')
      receipt.rewind

      patch invoice_invoice_payment_path(invoice, payment), params: {
        invoice_payment: {
          tracking_key: 'TRACK-EDIT-001',
          receipt_file: Rack::Test::UploadedFile.new(receipt.path, 'application/pdf')
        }
      }

      expect(response).to redirect_to(invoice_path(invoice, anchor: 'payments-section'))
      expect(payment.reload.tracking_key).to eq('TRACK-EDIT-001')
      expect(payment.receipt_file).to be_attached
    end
  end

  describe 'DELETE /invoices/:invoice_id/invoice_payments/:id' do
    it 'deletes payment' do
      target = create(:invoice_payment, invoice: invoice, status: 'registered')

      expect {
        delete invoice_invoice_payment_path(invoice, target)
      }.to change(InvoicePayment, :count).by(-1)

      expect(response).to redirect_to(invoice_path(invoice, anchor: 'payments-section'))
    end
  end

  describe 'authorization' do
    it 'denies customs broker users' do
      sign_out admin_user
      broker_user = create(:user, :customs_broker)
      sign_in broker_user, scope: :user

      get invoice_invoice_payment_path(invoice, payment)

      expect(response).to redirect_to(customs_agents_dashboard_path)
      expect(flash[:alert]).to be_present
    end
  end
end
