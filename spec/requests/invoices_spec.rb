require 'rails_helper'

RSpec.describe 'Invoices', type: :request do
  let(:admin_user) { create(:user, :admin) }

  describe 'GET /invoices' do
    before { sign_in admin_user, scope: :user }

    it 'renders index successfully' do
      create(:invoice)

      get invoices_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Facturas')
    end

    it 'filters by status' do
      issued = create(:invoice, status: 'issued', sat_uuid: 'UUID-STATUS-ISSUED')
      failed = create(:invoice, status: 'failed', sat_uuid: 'UUID-STATUS-FAILED')

      get invoices_path, params: { status: 'issued' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(issued.receiver_entity.name)
      expect(response.body).to include(issued.sat_uuid)
      expect(response.body).not_to include(failed.sat_uuid)
    end

    it 'filters by uuid' do
      with_uuid = create(:invoice, sat_uuid: 'ABC-UUID-001')
      create(:invoice, sat_uuid: 'XYZ-UUID-999')

      get invoices_path, params: { uuid: 'ABC-UUID-001' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('ABC-UUID-001')
      expect(response.body).not_to include('XYZ-UUID-999')
      expect(response.body).to include(with_uuid.receiver_entity.name)
    end

    it 'filters by client' do
      client = create(:entity, :client)
      other_client = create(:entity, :client)
      client_invoice = create(:invoice, receiver_entity: client, sat_uuid: 'UUID-CLIENT-MATCH')
      other_invoice = create(:invoice, receiver_entity: other_client, sat_uuid: 'UUID-CLIENT-OTHER')

      get invoices_path, params: { client_id: client.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(client_invoice.receiver_entity.name)
      expect(response.body).to include(client_invoice.sat_uuid)
      expect(response.body).not_to include(other_invoice.sat_uuid)
    end

    it 'filters by date range' do
      recent_invoice = create(:invoice, sat_uuid: 'UUID-DATE-RECENT')
      old_invoice = create(:invoice, sat_uuid: 'UUID-DATE-OLD')
      old_invoice.update_column(:created_at, 120.days.ago)

      get invoices_path, params: {
        start_date: 90.days.ago.to_date.to_s,
        end_date: Date.current.to_s
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(recent_invoice.receiver_entity.name)
      expect(response.body).to include(recent_invoice.sat_uuid)
      expect(response.body).not_to include(old_invoice.sat_uuid)
    end
  end

  describe 'GET /invoices/:id' do
    before { sign_in admin_user, scope: :user }

    it 'renders show successfully' do
      invoice = create(:invoice, status: 'issued', sat_uuid: 'UUID-SHOW-001')

      get invoice_path(invoice)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Factura ##{invoice.id}")
      expect(response.body).to include('UUID-SHOW-001')
      expect(response.body).to include('Registrar nuevo pago')
      expect(response.body).to include('Registrar pago')
    end

    it 'shows complement uuid when payment has linked complement invoice' do
      invoice = create(:invoice, status: 'issued', sat_uuid: 'UUID-SHOW-002')
      complement = create(:invoice, kind: 'pago', status: 'issued', sat_uuid: 'UUID-COMP-001')
      complement.xml_file.attach(io: StringIO.new('<cfdi/>'), filename: 'comp.xml', content_type: 'application/xml')
      complement.pdf_file.attach(io: StringIO.new('%PDF-1.4 test'), filename: 'comp.pdf', content_type: 'application/pdf')
      create(:invoice_payment, invoice: invoice, status: 'complement_issued', complement_invoice: complement)

      get invoice_path(invoice)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Complemento')
      expect(response.body).to include('UUID-COMP-001')
      expect(response.body).to include('XML')
      expect(response.body).to include('PDF')
    end
  end

  describe 'authorization' do
    it 'denies customs broker users' do
      broker_user = create(:user, :customs_broker)
      sign_in broker_user, scope: :user

      get invoices_path

      expect(response).to redirect_to(customs_agents_dashboard_path)
      expect(flash[:alert]).to be_present
    end

    it 'denies customs broker users on show' do
      broker_user = create(:user, :customs_broker)
      sign_in broker_user, scope: :user
      invoice = create(:invoice)

      get invoice_path(invoice)

      expect(response).to redirect_to(customs_agents_dashboard_path)
      expect(flash[:alert]).to be_present
    end
  end
end
