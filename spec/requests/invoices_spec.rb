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
      expect(response.body).to include('Nuevo CFDI')
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

  describe 'GET /invoices/new' do
    before { sign_in admin_user, scope: :user }

    it 'renders new manual invoice form' do
      create(:service_catalog)
      create(:entity, :customs_agent)
      create(:entity, :consolidator)
      create(:entity, :client)

      get new_invoice_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Nuevo CFDI')
      expect(response.body).to include('Crear y emitir CFDI')
    end
  end

  describe 'POST /invoices' do
    let(:receiver) { create(:entity, :client, :with_fiscal_profile, :with_address) }
    let(:issuer) { create(:entity, :customs_agent, :with_fiscal_profile, :with_address) }
    let(:invoice) { create(:invoice, invoiceable: nil, issuer_entity: issuer, receiver_entity: receiver, status: 'queued') }

    before do
      sign_in admin_user, scope: :user
    end

    it 'creates manual invoice and redirects to show' do
      allow(Facturador::CreateManualInvoiceService).to receive(:call)
        .and_return(Facturador::CreateManualInvoiceService::Result.new(invoice: invoice))

      post invoices_path, params: {
        manual_invoice: {
          receiver_kind: 'client',
          receiver_entity_id: receiver.id,
          customs_agent_id: '',
          line_items: [
            {
              service_catalog_id: create(:service_catalog).id,
              description: 'Concepto manual',
              quantity: '1',
              unit_price: '100.00'
            }
          ]
        }
      }

      expect(response).to redirect_to(invoice_path(invoice))
      expect(flash[:notice]).to include('CFDI manual creado')
    end

    it 'renders new when service returns error' do
      allow(Facturador::CreateManualInvoiceService).to receive(:call)
        .and_return(Facturador::CreateManualInvoiceService::Result.new(error_message: 'Debes agregar al menos un concepto'))

      post invoices_path, params: {
        manual_invoice: {
          receiver_kind: 'client',
          receiver_entity_id: receiver.id,
          customs_agent_id: '',
          line_items: []
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Nuevo CFDI')
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

    it 'shows retry issue button for issue-related failed invoice' do
      service = create(:container_service)
      invoice = create(
        :invoice,
        invoiceable: service,
        status: 'failed',
        sat_uuid: nil,
        last_error_code: 'FACTURADOR_ISSUE_PROVIDER_FAC119',
        last_error_message: 'FAC119: La serie del comprobante no esta disponible. Intentar mas tarde.'
      )

      get invoice_path(invoice)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Reintentar emisión CFDI')
    end

    it 'shows retry issue button for failed manual invoice without invoiceable' do
      issuer = create(:entity, :customs_agent)
      receiver = create(:entity, :client)
      invoice = create(
        :invoice,
        invoiceable: nil,
        issuer_entity: issuer,
        receiver_entity: receiver,
        status: 'failed',
        sat_uuid: nil,
        last_error_code: 'FACTURADOR_ISSUE_NETWORK_ERROR',
        last_error_message: 'Failed to open TCP connection'
      )

      get invoice_path(invoice)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Reintentar emisión CFDI')
    end

    it 'does not show retry issue button for non-issue failed codes' do
      service = create(:container_service)
      invoice = create(
        :invoice,
        invoiceable: service,
        status: 'failed',
        sat_uuid: nil,
        last_error_code: 'FACTURADOR_CANCEL_PROVIDER_ERROR',
        last_error_message: 'PAC/SAT no confirmó cancelación'
      )

      get invoice_path(invoice)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Reintentar emisión CFDI')
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

    it 'enqueues cancellation for admin users' do
      sign_in admin_user, scope: :user
      expect(Facturador::CancelInvoiceJob).to receive(:perform_later).with(
        invoice_id: invoice.id,
        motive: '02',
        replacement_uuid: nil,
        actor_id: admin_user.id
      )

      patch cancel_invoice_path(invoice)

      expect(response).to redirect_to(containers_path)
      expect(flash[:notice]).to include('Cancelación de CFDI en proceso')
    end

    it 'shows alert when invoice is not cancellable before enqueuing' do
      sign_in admin_user, scope: :user
      invoice.update!(status: 'draft', sat_uuid: nil)

      patch cancel_invoice_path(invoice)

      expect(response).to redirect_to(containers_path)
      expect(flash[:alert]).to include('Error al cancelar CFDI')
    end

    it 'denies customs broker users' do
      broker_user = create(:user, :customs_broker)
      sign_in broker_user, scope: :user

      patch cancel_invoice_path(invoice)

      expect(response).to redirect_to(customs_agents_dashboard_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe 'POST /invoices/:id/retry_issue' do
    let(:invoice) do
      create(
        :invoice,
        status: 'failed',
        sat_uuid: nil,
        last_error_code: 'FACTURADOR_ISSUE_NETWORK_ERROR',
        last_error_message: 'Temporary failure in name resolution'
      )
    end

    it 'requeues failed issue invoice for admin users' do
      sign_in admin_user, scope: :user
      expect_any_instance_of(Invoice).to receive(:queue_issue!).with(actor: admin_user).and_return(true)

      post retry_issue_invoice_path(invoice)

      expect(response).to redirect_to(invoice_path(invoice))
      expect(flash[:notice]).to include('Reintento de emisión CFDI encolado')
    end

    it 'denies customs broker users' do
      broker_user = create(:user, :customs_broker)
      sign_in broker_user, scope: :user

      post retry_issue_invoice_path(invoice)

      expect(response).to redirect_to(customs_agents_dashboard_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe 'POST /invoices/:id/sync_documents' do
    let(:invoice) { create(:invoice, status: 'issued', sat_uuid: 'UUID-SYNC-001') }

    it 'reconciles issued invoice explicitly before syncing documents' do
      sign_in admin_user, scope: :user
      expect(Facturador::ReconcileInvoicesService).to receive(:call_for_invoice).with(invoice: invoice, actor: admin_user)
      expect(Facturador::SyncInvoiceDocumentsService).to receive(:call).with(invoice: invoice, actor: admin_user)

      post sync_documents_invoice_path(invoice)

      expect(response).to redirect_to(containers_path)
      expect(flash[:notice]).to include('XML y PDF sincronizados correctamente.')
    end

    it 'still syncs xml/pdf when explicit reconciliation changes invoice status to cancelled' do
      sign_in admin_user, scope: :user
      allow(Facturador::ReconcileInvoicesService).to receive(:call_for_invoice) do
        invoice.update!(status: 'cancelled')
      end
      expect(Facturador::SyncInvoiceDocumentsService).to receive(:call).with(invoice: invoice, actor: admin_user)

      post sync_documents_invoice_path(invoice)

      expect(response).to redirect_to(containers_path)
      expect(flash[:notice]).to include('XML/PDF sincronizados (factura cancelada).')
    end
  end

  describe 'POST /invoices/:id/send_email' do
    let(:invoice) { create(:invoice, status: 'issued', sat_uuid: 'UUID-EMAIL-REQ-001') }

    it 'sends invoice email for admin users' do
      sign_in admin_user, scope: :user
      expect(Facturador::SendInvoiceEmailService).to receive(:call).with(invoice: invoice, actor: admin_user, trigger: 'manual')

      post send_email_invoice_path(invoice)

      expect(response).to redirect_to(invoice_path(invoice))
      expect(flash[:notice]).to include('CFDI enviado por correo exitosamente.')
    end

    it 'shows friendly alert when PAC is temporarily unavailable' do
      sign_in admin_user, scope: :user
      allow(Facturador::SendInvoiceEmailService).to receive(:call).and_raise(
        Facturador::RequestError,
        '500: An error has occurred. | System.Net.Http.HttpRequestException'
      )

      post send_email_invoice_path(invoice)

      expect(response).to redirect_to(invoice_path(invoice))
      expect(flash[:alert]).to include('PAC no está disponible temporalmente')
    end

    it 'shows clear alert when email feature is disabled' do
      sign_in admin_user, scope: :user
      allow(Facturador::SendInvoiceEmailService).to receive(:call).and_raise(
        Facturador::ValidationError,
        'Email sending via PAC is disabled'
      )

      post send_email_invoice_path(invoice)

      expect(response).to redirect_to(invoice_path(invoice))
      expect(flash[:alert]).to include('esta deshabilitado')
    end

    it 'denies customs broker users' do
      broker_user = create(:user, :customs_broker)
      sign_in broker_user, scope: :user

      post send_email_invoice_path(invoice)

      expect(response).to redirect_to(customs_agents_dashboard_path)
      expect(flash[:alert]).to be_present
    end
  end
end
