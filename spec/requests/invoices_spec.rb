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

    it 'filters by customs agent' do
      selected_agent = create(:entity, :customs_agent)
      other_agent = create(:entity, :customs_agent)
      selected_client = create(:entity, :client, customs_agent: selected_agent)
      other_client = create(:entity, :client, customs_agent: other_agent)

      selected_invoice = create(:invoice, receiver_entity: selected_client, sat_uuid: 'UUID-AGENCY-MATCH')
      other_invoice = create(:invoice, receiver_entity: other_client, sat_uuid: 'UUID-AGENCY-OTHER')

      get invoices_path, params: { customs_agent_id: selected_agent.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(selected_invoice.sat_uuid)
      expect(response.body).not_to include(other_invoice.sat_uuid)
    end

    it 'filters by consolidator' do
      selected_consolidator = create(:entity, :consolidator)
      other_consolidator = create(:entity, :consolidator)

      selected_container = create(:container, consolidator_entity: selected_consolidator)
      other_container = create(:container, consolidator_entity: other_consolidator)

      selected_service = create(:container_service, container: selected_container)
      other_service = create(:container_service, container: other_container)

      selected_invoice = create(:invoice, invoiceable: selected_service, sat_uuid: 'UUID-CONS-MATCH')
      other_invoice = create(:invoice, invoiceable: other_service, sat_uuid: 'UUID-CONS-OTHER')

      get invoices_path, params: { consolidator_id: selected_consolidator.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(selected_invoice.sat_uuid)
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

  describe 'PATCH /invoices/:id/cancel' do
    let(:invoice) { create(:invoice, status: 'issued', sat_uuid: 'UUID-CANCEL-REQ-001') }

    it 'cancels invoice for admin users' do
      sign_in admin_user, scope: :user
      invoice.update!(status: 'cancel_pending')
      expect(Facturador::CancelInvoiceService).to receive(:call).with(
        invoice: invoice,
        motive: '02',
        replacement_uuid: nil,
        actor: admin_user
      ).and_return(invoice)

      patch cancel_invoice_path(invoice)

      expect(response).to redirect_to(containers_path)
      expect(flash[:notice]).to include('Cancelación de CFDI solicitada. La factura se mantiene emitida hasta confirmación final de SAT/PAC.')
    end

    it 'shows specific alert when cancellation attempt fails but invoice remains issued' do
      sign_in admin_user, scope: :user
      invoice.update!(status: 'issued', last_error_message: 'PAC devolvió error 500')
      allow(Facturador::CancelInvoiceService).to receive(:call).and_return(invoice)

      patch cancel_invoice_path(invoice)

      expect(response).to redirect_to(containers_path)
      expect(flash[:alert]).to include('No se pudo cancelar el CFDI en este intento')
    end

    it 'shows alert when cancellation fails' do
      sign_in admin_user, scope: :user
      allow(Facturador::CancelInvoiceService).to receive(:call).and_raise(Facturador::RequestError, 'PAC timeout')

      patch cancel_invoice_path(invoice)

      expect(response).to redirect_to(containers_path)
      expect(flash[:alert]).to include('Error al cancelar CFDI: PAC timeout')
    end

    it 'shows friendly alert when provider is temporarily unavailable' do
      sign_in admin_user, scope: :user
      allow(Facturador::CancelInvoiceService).to receive(:call).and_raise(
        Facturador::RequestError,
        '500: An error has occurred. | System.Net.Http.HttpRequestException'
      )

      patch cancel_invoice_path(invoice)

      expect(response).to redirect_to(containers_path)
      expect(flash[:alert]).to include('PAC no está disponible temporalmente')
    end

    it 'denies customs broker users' do
      broker_user = create(:user, :customs_broker)
      sign_in broker_user, scope: :user

      patch cancel_invoice_path(invoice)

      expect(response).to redirect_to(customs_agents_dashboard_path)
      expect(flash[:alert]).to be_present
    end
  end
end
