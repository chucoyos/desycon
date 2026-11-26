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
        tracking_key: 'TRACK-EVID-001',
        review_comment: 'Validado por ejecutivo con referencia coincidente'
      )

      get invoice_invoice_payment_path(invoice, payment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Evidencia enviada por agencia')
      expect(response.body).to include(evidence.reference)
      expect(response.body).to include(evidence.tracking_key)
      expect(response.body).to include('Comentario de revision')
      expect(response.body).to include('Validado por ejecutivo con referencia coincidente')
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

    it 'keeps editing blocked when the linked REP has been cancelled' do
      complement = create(:invoice, kind: 'pago', status: 'cancelled', sat_uuid: 'UUID-COMP-CANCELLED-EDIT')
      payment.update!(status: 'complement_issued', complement_invoice: complement)

      patch invoice_invoice_payment_path(invoice, payment), params: {
        invoice_payment: { amount: 600, reference: 'NO-EDIT' }
      }

      expect(response).to redirect_to(invoice_path(invoice, anchor: 'payments-section'))
      expect(flash[:alert]).to be_present
      expect(payment.reload.amount.to_f).to eq(500.0)
      expect(payment.reference).to eq('REF-001')
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

    it 'deletes a payment linked to a confirmed-cancelled REP and preserves the REP and other linked payments' do
      complement = create(:invoice, kind: 'pago', status: 'cancelled', sat_uuid: 'UUID-COMP-CANCELLED')
      target = create(:invoice_payment, invoice: invoice, status: 'complement_issued', complement_invoice: complement)
      other_payment = create(:invoice_payment, invoice: invoice, status: 'complement_issued', complement_invoice: complement)

      expect {
        delete invoice_invoice_payment_path(invoice, target)
      }.to change(InvoicePayment, :count).by(-1)

      expect(response).to redirect_to(invoice_path(invoice, anchor: 'payments-section'))
      expect(flash[:notice]).to eq('Pago eliminado correctamente.')
      expect(Invoice.exists?(complement.id)).to be(true)
      expect(complement.reload.status).to eq('cancelled')
      expect(complement.payment_complements).to contain_exactly(other_payment)
      expect(other_payment.reload.complement_invoice_id).to eq(complement.id)
    end

    %w[issued cancel_pending].each do |rep_status|
      it "blocks deleting a payment while its REP is #{rep_status}" do
        complement = create(:invoice, kind: 'pago', status: rep_status)
        target = create(:invoice_payment, invoice: invoice, status: 'complement_issued', complement_invoice: complement)

        expect {
          delete invoice_invoice_payment_path(invoice, target)
        }.not_to change(InvoicePayment, :count)

        expect(response).to redirect_to(invoice_path(invoice, anchor: 'payments-section'))
        expect(flash[:alert]).to include('mientras su REP no esté cancelado')
        expect(target.reload.complement_invoice_id).to eq(complement.id)
      end
    end
  end

  describe 'POST /invoices/:invoice_id/invoice_payments/:id/issue_rep' do
    it 'requests REP manually and redirects to payments section' do
      expect(Facturador::RequestPaymentComplementService).to receive(:call).with(payment: payment, actor: admin_user)

      post issue_rep_invoice_invoice_payment_path(invoice, payment)

      expect(response).to redirect_to(invoice_path(invoice, anchor: 'payments-section'))
      expect(flash[:notice]).to include('Solicitud de REP encolada')
    end

    it 'shows alert when manual REP request fails' do
      allow(Facturador::RequestPaymentComplementService).to receive(:call).and_raise(Facturador::RequestError, 'bloqueado por duplicado')

      post issue_rep_invoice_invoice_payment_path(invoice, payment)

      expect(response).to redirect_to(invoice_path(invoice, anchor: 'payments-section'))
      expect(flash[:alert]).to include('No fue posible solicitar el REP')
      expect(flash[:alert]).to include('bloqueado por duplicado')
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

    it 'denies customs broker users for manual REP request' do
      sign_out admin_user
      broker_user = create(:user, :customs_broker)
      sign_in broker_user, scope: :user

      post issue_rep_invoice_invoice_payment_path(invoice, payment)

      expect(response).to redirect_to(customs_agents_dashboard_path)
      expect(flash[:alert]).to be_present
    end

    it 'denies customs broker users deleting a payment with a cancelled REP' do
      sign_out admin_user
      broker_user = create(:user, :customs_broker)
      sign_in broker_user, scope: :user
      complement = create(:invoice, kind: 'pago', status: 'cancelled', sat_uuid: 'UUID-COMP-CANCELLED-AUTH')
      target = create(:invoice_payment, invoice: invoice, status: 'complement_issued', complement_invoice: complement)

      expect {
        delete invoice_invoice_payment_path(invoice, target)
      }.not_to change(InvoicePayment, :count)

      expect(response).to redirect_to(customs_agents_dashboard_path)
      expect(flash[:alert]).to be_present
      expect(target.reload).to be_persisted
    end
  end
end
