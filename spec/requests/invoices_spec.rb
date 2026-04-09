require 'rails_helper'

RSpec.describe 'Invoices', type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:consolidator_user) { create(:user, :consolidator) }

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

    it 'filters by serie from provider response or payload snapshot' do
      provider_invoice = create(:invoice, provider_response: { 'serie' => 'GVRZ' }, sat_uuid: 'UUID-SERIE-PROVIDER')
      snapshot_invoice = create(:invoice, payload_snapshot: { 'serie_override' => 'MZ' }, sat_uuid: 'UUID-SERIE-SNAPSHOT')
      other_invoice = create(:invoice, provider_response: { 'serie' => 'ZZZ' }, sat_uuid: 'UUID-SERIE-OTHER')

      get invoices_path, params: { serie: 'MZ' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(snapshot_invoice.sat_uuid)
      expect(response.body).not_to include(provider_invoice.sat_uuid)
      expect(response.body).not_to include(other_invoice.sat_uuid)
    end

    it 'filters by container number and blhouse' do
      matching_container = create(:container, number: 'ABCD1234567')
      non_matching_container = create(:container, number: 'WXYZ7654321')

      matching_bl = create(:bl_house_line, container: matching_container, blhouse: 'BLH-FILTER-001')
      non_matching_bl = create(:bl_house_line, container: non_matching_container, blhouse: 'BLH-FILTER-999')

      matching_service = create(:bl_house_line_service, bl_house_line: matching_bl)
      non_matching_service = create(:bl_house_line_service, bl_house_line: non_matching_bl)

      matching_invoice = create(:invoice, invoiceable: matching_service, sat_uuid: 'UUID-CONT-BLH-MATCH')
      non_matching_invoice = create(:invoice, invoiceable: non_matching_service, sat_uuid: 'UUID-CONT-BLH-OTHER')

      get invoices_path, params: { container_number: 'ABCD1234567', blhouse: 'BLH-FILTER-001' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matching_invoice.sat_uuid)
      expect(response.body).not_to include(non_matching_invoice.sat_uuid)
      expect(response.body).to include('BLH-FILTER-001')
      expect(response.body).to include('ABCD1234567')
    end

    it 'filters by comprobante type' do
      factura_invoice = create(:invoice, kind: 'ingreso', sat_uuid: 'UUID-KIND-FACTURA')
      pago_invoice = create(:invoice, kind: 'pago', sat_uuid: 'UUID-KIND-PAGO')

      get invoices_path, params: { kind: 'pago' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(pago_invoice.sat_uuid)
      expect(response.body).not_to include(factura_invoice.sat_uuid)
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

    it 'filters by payment status' do
      pending_invoice = create(:invoice, status: 'issued', total: 1000, sat_uuid: 'UUID-PAYMENT-PENDING')
      partial_invoice = create(:invoice, status: 'issued', total: 1000, sat_uuid: 'UUID-PAYMENT-PARTIAL')
      paid_invoice = create(:invoice, status: 'issued', total: 1000, sat_uuid: 'UUID-PAYMENT-PAID')

      create(:invoice_payment, invoice: partial_invoice, amount: 300, status: 'registered')
      create(:invoice_payment, invoice: paid_invoice, amount: 1000, status: 'registered')

      get invoices_path, params: { payment_status: 'partial' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(partial_invoice.sat_uuid)
      expect(response.body).not_to include(pending_invoice.sat_uuid)
      expect(response.body).not_to include(paid_invoice.sat_uuid)
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
      expect(response.body).to include('Generar CFDI')
      expect(response.body).to include('Serie')
    end
  end

  describe 'GET /invoices as consolidator' do
    before { sign_in consolidator_user, scope: :user }

    it 'returns only invoices where consolidator is receiver' do
      own_invoice = create(:invoice, receiver_entity: consolidator_user.entity, sat_uuid: 'UUID-CONS-OWN-001')
      other_invoice = create(:invoice, sat_uuid: 'UUID-CONS-OTHER-001')

      get invoices_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(own_invoice.sat_uuid)
      expect(response.body).not_to include(other_invoice.sat_uuid)
      expect(response.body).not_to include('Nuevo CFDI')
    end
  end

  describe 'GET /invoices/receivers_search' do
    before { sign_in admin_user, scope: :user }

    it 'returns empty results when query is too short' do
      get receivers_search_invoices_path, params: { q: 'a' }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload['results']).to eq([])
      expect(payload.dig('meta', 'min_chars')).to eq(2)
    end

    it 'returns up to 20 matching receivers' do
      25.times do |i|
        receiver = create(:entity, :client, name: "Receptor Stress #{i}")
        create(:invoice, receiver_entity: receiver)
      end

      get receivers_search_invoices_path, params: { q: 'Receptor Stress' }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload['results'].size).to eq(20)
      expect(payload.dig('meta', 'limit')).to eq(20)
    end

    it 'returns empty results for consolidator users under client-only receiver filter' do
      own_user = create(:user, :consolidator)
      own_entity = own_user.entity
      own_entity.update!(name: 'Consolidador Receptor')
      other_receiver = create(:entity, :client, name: 'Consolidador Receptor Externo')

      create(:invoice, receiver_entity: own_entity)
      create(:invoice, receiver_entity: other_receiver)

      sign_in own_user, scope: :user

      get receivers_search_invoices_path, params: { q: 'Consolidador Receptor' }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      ids = payload.fetch('results').map { |result| result.fetch('id') }

      expect(ids).to eq([])
      expect(ids).not_to include(other_receiver.id)
    end

    it 'returns only agency-related receivers for customs broker users' do
      customs_broker = create(:user, :customs_broker)
      own_agency = customs_broker.entity
      own_client = create(:entity, :client, name: 'Cliente Agencia Propia', customs_agent: own_agency)
      other_agency = create(:entity, :customs_agent)
      other_client = create(:entity, :client, name: 'Cliente Agencia Externa', customs_agent: other_agency)

      create(:invoice, receiver_entity: own_client)
      create(:invoice, receiver_entity: other_client)

      sign_in customs_broker, scope: :user

      get receivers_search_invoices_path, params: { q: 'Cliente Agencia' }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      ids = payload.fetch('results').map { |result| result.fetch('id') }

      expect(ids).to include(own_client.id)
      expect(ids).not_to include(other_client.id)
    end

    it 'rejects users without invoices index permission' do
      tramitador = create(:user, :tramitador)
      sign_in tramitador, scope: :user

      get receivers_search_invoices_path, params: { q: 'Receptor' }, as: :json

      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'GET /invoices/customs_agents_search' do
    before { sign_in admin_user, scope: :user }

    it 'returns empty results when query is too short' do
      get customs_agents_search_invoices_path, params: { q: 'a' }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload['results']).to eq([])
      expect(payload.dig('meta', 'min_chars')).to eq(2)
    end

    it 'returns up to 20 matching customs agencies' do
      25.times do |i|
        create(:entity, :customs_agent, name: "Agencia Search #{i}")
      end

      get customs_agents_search_invoices_path, params: { q: 'Agencia Search' }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload['results'].size).to eq(20)
      expect(payload.dig('meta', 'limit')).to eq(20)
    end

    it 'returns forbidden for consolidator users' do
      sign_in consolidator_user, scope: :user

      get customs_agents_search_invoices_path, params: { q: 'Agencia' }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns forbidden for customs broker users' do
      customs_broker = create(:user, :customs_broker)
      sign_in customs_broker, scope: :user

      get customs_agents_search_invoices_path, params: { q: 'Agencia' }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects users without invoices index permission' do
      tramitador = create(:user, :tramitador)
      sign_in tramitador, scope: :user

      get customs_agents_search_invoices_path, params: { q: 'Agencia' }, as: :json

      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'GET /invoices/consolidators_search' do
    before { sign_in admin_user, scope: :user }

    it 'returns empty results when query is too short' do
      get consolidators_search_invoices_path, params: { q: 'a' }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload['results']).to eq([])
      expect(payload.dig('meta', 'min_chars')).to eq(2)
    end

    it 'returns up to 20 matching consolidators' do
      25.times do |i|
        create(:entity, :consolidator, name: "Consolidador Search #{i}")
      end

      get consolidators_search_invoices_path, params: { q: 'Consolidador Search' }, as: :json

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload['results'].size).to eq(20)
      expect(payload.dig('meta', 'limit')).to eq(20)
    end

    it 'returns forbidden for consolidator users' do
      sign_in consolidator_user, scope: :user

      get consolidators_search_invoices_path, params: { q: 'Consolidador' }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns forbidden for customs broker users' do
      customs_broker = create(:user, :customs_broker)
      sign_in customs_broker, scope: :user

      get consolidators_search_invoices_path, params: { q: 'Consolidador' }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects users without invoices index permission' do
      tramitador = create(:user, :tramitador)
      sign_in tramitador, scope: :user

      get consolidators_search_invoices_path, params: { q: 'Consolidador' }, as: :json

      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'GET /invoices/:id as consolidator' do
    before { sign_in consolidator_user, scope: :user }

    it 'allows own receiver invoice with sync and download actions' do
      own_invoice = create(:invoice, receiver_entity: consolidator_user.entity, status: 'issued', sat_uuid: 'UUID-CONS-SHOW-001')
      own_invoice.xml_file.attach(io: StringIO.new('<cfdi/>'), filename: 'cons.xml', content_type: 'application/xml')
      own_invoice.pdf_file.attach(io: StringIO.new('%PDF-1.4 test'), filename: 'cons.pdf', content_type: 'application/pdf')

      get invoice_path(own_invoice)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Re-sincronizar XML/PDF')
      expect(response.body).to include('Descargar XML')
      expect(response.body).to include('Descargar PDF')
      expect(response.body).not_to include('Cancelar CFDI')
      expect(response.body).not_to include('Reintentar emisión CFDI')
      expect(response.body).not_to include('Registrar nuevo pago')
    end

    it 'denies access to invoice not related as receiver' do
      other_invoice = create(:invoice)

      get invoice_path(other_invoice)

      expect(response).to redirect_to(containers_path)
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
          serie: 'MZ',
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

      expect(Facturador::CreateManualInvoiceService).to have_received(:call).with(
        hash_including(
          actor: admin_user,
          receiver_entity_id: receiver.id.to_s,
          customs_agent_id: '',
          serie: 'MZ'
        )
      )
      expect(response).to redirect_to(invoice_path(invoice, from_manual_create: 1))
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
          serie: '',
          line_items: []
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Nuevo CFDI')
    end
  end

  describe 'POST /invoices/issue_manual_batch' do
    before { sign_in admin_user, scope: :user }

    it 'issues one grouped invoice for selected container services' do
      receiver = create(:entity, :client, :with_fiscal_profile, :with_address)
      container = create(:container, consolidator_entity: receiver)
      first_service = create(:container_service, container: container, billed_to_entity: receiver, factura: nil)
      second_service = create(:container_service, container: container, billed_to_entity: receiver, factura: nil)
      grouped_invoice = create(:invoice, invoiceable: nil)

      allow(Facturador::IssueGroupedServicesService).to receive(:call)
        .and_return(Facturador::IssueGroupedServicesService::Result.new(invoice: grouped_invoice))

      post issue_manual_batch_invoices_path, params: {
        invoiceable_type: 'ContainerService',
        invoiceable_ids: [ first_service.id, second_service.id ]
      }

      expect(Facturador::IssueGroupedServicesService).to have_received(:call) do |args|
        expect(args[:serviceables].map(&:id)).to match_array([ first_service.id, second_service.id ])
        expect(args[:actor]).to eq(admin_user)
      end
      expect(response).to redirect_to(invoice_path(grouped_invoice))
    end

    it 'rejects request when no valid services are selected' do
      post issue_manual_batch_invoices_path, params: {
        invoiceable_type: 'ContainerService',
        invoiceable_ids: []
      }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('Selecciona al menos un servicio válido')
    end
  end

  describe 'POST /invoices/issue_manual' do
    before { sign_in admin_user, scope: :user }

    it 'redirects to the newly created invoice when issuing one service' do
      service = create(:container_service, factura: nil)
      issued_invoice = create(:invoice, invoiceable: service)

      allow(Facturador::ManualIssueService).to receive(:call).and_return(issued_invoice)

      post issue_manual_invoices_path, params: {
        invoiceable_type: 'ContainerService',
        invoiceable_id: service.id
      }

      expect(Facturador::ManualIssueService).to have_received(:call).with(invoiceable: service, actor: admin_user)
      expect(response).to redirect_to(invoice_path(issued_invoice))
      expect(flash[:notice]).to include('Emisión manual encolada/ejecutada correctamente')
    end
  end

  describe 'GET /invoices/:id' do
    before { sign_in admin_user, scope: :user }

    it 'renders show successfully' do
      invoice = create(:invoice, status: 'issued', sat_uuid: 'UUID-SHOW-001')
      invoice.invoice_events.create!(
        event_type: 'issue_requested',
        created_by: admin_user,
        request_payload: {},
        response_payload: {}
      )

      get invoice_path(invoice)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("##{invoice.id}")
      expect(response.body).to include('UUID-SHOW-001')
      expect(response.body).to include('Registrar nuevo pago')
      expect(response.body).to include('Registrar pago')
      expect(response.body).to include('Sincronizar XML/PDF')
      expect(response.body).not_to include('Re-sincronizar XML/PDF')
      expect(response.body).to include('Actor:')
      expect(response.body).to include(admin_user.email)
    end

    it 'shows re-sync label for admin when xml and pdf are already attached' do
      invoice = create(:invoice, status: 'issued', sat_uuid: 'UUID-SHOW-001A')
      invoice.xml_file.attach(io: StringIO.new('<cfdi/>'), filename: 'invoice.xml', content_type: 'application/xml')
      invoice.pdf_file.attach(io: StringIO.new('%PDF-1.4 test'), filename: 'invoice.pdf', content_type: 'application/pdf')

      get invoice_path(invoice)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Re-sincronizar XML/PDF')
      expect(response.body).not_to include('Sincronizar XML/PDF')
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

    it 'shows included CFDIs table for REP with one row per related document' do
      receiver = create(:entity, :client, name: 'Cliente Receptor Con Nombre Muy Largo Para Probar Tabla REP Sin Romper Layout')
      source_invoice_one = create(
        :invoice,
        status: 'issued',
        sat_uuid: 'UUID-REL-001',
        receiver_entity: receiver,
        provider_response: { 'serie' => 'A', 'folio' => '1001' },
        total: 1160
      )
      source_invoice_two = create(
        :invoice,
        status: 'issued',
        sat_uuid: 'UUID-REL-002',
        receiver_entity: receiver,
        provider_response: { 'serie' => 'B', 'folio' => '1002' },
        total: 2320
      )

      rep_invoice = create(
        :invoice,
        kind: 'pago',
        status: 'issued',
        sat_uuid: 'UUID-REP-001',
        payload_snapshot: {
          complemento: {
            complementoPago20: {
              pago: [
                {
                  doctoRelacionado: [
                    {
                      folio: '1001',
                      idDocumento: source_invoice_one.sat_uuid
                    },
                    {
                      serie: 'B',
                      folio: '1002',
                      idDocumento: source_invoice_two.sat_uuid
                    }
                  ]
                }
              ]
            }
          }
        }
      )

      get invoice_path(rep_invoice)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('CFDIs incluidos en este REP')
      expect(response.body).to include('RECEPTOR')
      expect(response.body).to include('Saldo')
      expect(response.body).to include('UUID-REL-001')
      expect(response.body).to include('UUID-REL-002')
      expect(response.body).to include('A')
      expect(response.body).to include('1001')
      expect(response.body).to include('B')
      expect(response.body).to include('1002')
      expect(response.body).to include('Cliente Receptor Con Nombre')
      expect(response.body).to include(invoice_path(source_invoice_one))
      expect(response.body).to include(invoice_path(source_invoice_two))
      expect(response.body).to include('$1,160.00')
      expect(response.body).to include('$2,320.00')
    end

    it 'keeps payment registration form available for PUE invoices' do
      invoice = create(
        :invoice,
        status: 'issued',
        sat_uuid: 'UUID-SHOW-003',
        payload_snapshot: { metodoPago: 'PUE' }
      )

      get invoice_path(invoice)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Registrar nuevo pago')
      expect(response.body).to include('Se registrará el pago sin emitir REP')
      expect(response.body).to include('Registrar pago')
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
      expect(response.body).to include(retry_issue_invoice_path(invoice))
    end

    it 'shows processing banner for queued invoices' do
      invoice = create(:invoice, status: 'queued', sat_uuid: nil)

      get invoice_path(invoice)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Emisión del CFDI en proceso')
      expect(response.body).to include('se actualizará automáticamente')
    end

    it 'does not show processing banner when returning from manual create flow if invoice is not queued' do
      invoice = create(:invoice, status: 'failed', sat_uuid: nil, last_error_code: 'FACTURADOR_ISSUE_NETWORK_ERROR')

      get invoice_path(invoice, from_manual_create: 1)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Emisión del CFDI en proceso')
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
    it 'allows customs broker users on index and only shows related invoices' do
      agency = create(:entity, :customs_agent)
      broker_user = create(:user, :customs_broker, entity: agency)
      sign_in broker_user, scope: :user

      related_invoice = create(:invoice, receiver_entity: create(:entity, :client, customs_agent: agency), sat_uuid: 'UUID-RELATED-BROKER')
      unrelated_invoice = create(:invoice, receiver_entity: create(:entity, :client, customs_agent: create(:entity, :customs_agent)), sat_uuid: 'UUID-UNRELATED-BROKER')

      get invoices_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(related_invoice.sat_uuid)
      expect(response.body).not_to include(unrelated_invoice.sat_uuid)
      expect(response.body).not_to include('Nuevo CFDI')
    end

    it 'allows customs broker users on show for related invoice with read-only view' do
      agency = create(:entity, :customs_agent)
      broker_user = create(:user, :customs_broker, entity: agency)
      sign_in broker_user, scope: :user
      invoice = create(:invoice, receiver_entity: create(:entity, :client, customs_agent: agency), status: 'issued', sat_uuid: 'UUID-BROKER-SHOW-001')

      get invoice_path(invoice)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('UUID-BROKER-SHOW-001')
      expect(response.body).not_to include('Registrar nuevo pago')
      expect(response.body).not_to include('Cancelar CFDI')
      expect(response.body).not_to include('Enviar CFDI por correo')
      expect(response.body).not_to include('Re-sincronizar XML/PDF')
      expect(response.body).to include('Sincronizar XML/PDF')
    end

    it 'hides customs broker sync button when xml and pdf are already attached' do
      agency = create(:entity, :customs_agent)
      broker_user = create(:user, :customs_broker, entity: agency)
      sign_in broker_user, scope: :user
      invoice = create(:invoice, receiver_entity: create(:entity, :client, customs_agent: agency), status: 'issued', sat_uuid: 'UUID-BROKER-SHOW-002')
      invoice.xml_file.attach(io: StringIO.new('<cfdi/>'), filename: 'invoice.xml', content_type: 'application/xml')
      invoice.pdf_file.attach(io: StringIO.new('%PDF-1.4 test'), filename: 'invoice.pdf', content_type: 'application/pdf')

      get invoice_path(invoice)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Sincronizar XML/PDF')
      expect(response.body).to include('Descargar XML')
      expect(response.body).to include('Descargar PDF')
    end

    it 'denies customs broker users on unrelated invoice show' do
      agency = create(:entity, :customs_agent)
      broker_user = create(:user, :customs_broker, entity: agency)
      sign_in broker_user, scope: :user
      other_agency = create(:entity, :customs_agent)
      invoice = create(:invoice, receiver_entity: create(:entity, :client, customs_agent: other_agency))

      get invoice_path(invoice)

      expect(response).to redirect_to(customs_agents_dashboard_path)
      expect(flash[:alert]).to be_present
    end

    it 'keeps index and show access when customs agency is restricted' do
      agency = create(:entity, :customs_agent, restricted_access_enabled: true)
      broker_user = create(:user, :customs_broker, entity: agency)
      sign_in broker_user, scope: :user
      related_invoice = create(:invoice, receiver_entity: create(:entity, :client, customs_agent: agency), status: 'issued', sat_uuid: 'UUID-BROKER-RESTRICTED-001')

      get invoices_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('UUID-BROKER-RESTRICTED-001')

      get invoice_path(related_invoice)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('UUID-BROKER-RESTRICTED-001')
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

    it 'reconciles cancel_pending invoice explicitly before syncing documents' do
      invoice.update!(status: 'cancel_pending')
      sign_in admin_user, scope: :user
      expect(Facturador::ReconcileInvoicesService).to receive(:call_for_invoice).with(invoice: invoice, actor: admin_user)
      expect(Facturador::SyncInvoiceDocumentsService).to receive(:call).with(invoice: invoice, actor: admin_user)

      post sync_documents_invoice_path(invoice)

      expect(response).to redirect_to(containers_path)
    end
  end

  describe 'POST /invoices/:id/sync_files' do
    let(:invoice) { create(:invoice, status: 'issued', sat_uuid: 'UUID-SYNC-FILES-001') }

    it 'syncs documents without reconciliation for admin users' do
      sign_in admin_user, scope: :user
      expect(Facturador::ReconcileInvoicesService).not_to receive(:call_for_invoice)
      expect(Facturador::SyncInvoiceDocumentsService).to receive(:call).with(invoice: invoice, actor: admin_user)

      post sync_files_invoice_path(invoice)

      expect(response).to redirect_to(invoice_path(invoice))
      expect(flash[:notice]).to include('XML y PDF sincronizados correctamente.')
    end

    it 'allows customs broker users when invoice is related to their agency' do
      agency = create(:entity, :customs_agent)
      broker_user = create(:user, :customs_broker, entity: agency)
      related_invoice = create(:invoice, status: 'issued', sat_uuid: 'UUID-SYNC-FILES-BROKER', receiver_entity: create(:entity, :client, customs_agent: agency))
      sign_in broker_user, scope: :user

      expect(Facturador::SyncInvoiceDocumentsService).to receive(:call).with(invoice: related_invoice, actor: broker_user)
      post sync_files_invoice_path(related_invoice)

      expect(response).to redirect_to(invoice_path(related_invoice))
      expect(flash[:notice]).to include('XML y PDF sincronizados correctamente.')
    end

    it 'denies customs broker users when invoice is not related to their agency' do
      agency = create(:entity, :customs_agent)
      broker_user = create(:user, :customs_broker, entity: agency)
      unrelated_invoice = create(:invoice, status: 'issued', sat_uuid: 'UUID-SYNC-FILES-DENY', receiver_entity: create(:entity, :client, customs_agent: create(:entity, :customs_agent)))
      sign_in broker_user, scope: :user

      post sync_files_invoice_path(unrelated_invoice)

      expect(response).to redirect_to(customs_agents_dashboard_path)
      expect(flash[:alert]).to be_present
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

  describe 'POST /invoices/:id/register_payment' do
    let(:invoice) { create(:invoice, status: 'issued', sat_uuid: 'UUID-PAY-REQ-001', payload_snapshot: { metodoPago: 'PPD' }) }

    let(:valid_payment_params) do
      receipt = Tempfile.new([ 'receipt', '.pdf' ])
      receipt.write('%PDF-1.4 payment receipt')
      receipt.rewind

      {
        payment: {
          amount: '250.00',
          paid_at: Time.zone.parse('2026-03-09 12:00:00').iso8601,
          payment_method: '03',
          reference: 'PAY-REQ-001',
          tracking_key: 'TRACK-REQ-001',
          receipt_file: Rack::Test::UploadedFile.new(receipt.path, 'application/pdf'),
          notes: 'Pago parcial'
        }
      }
    end

    it 'registers payment and redirects with success notice' do
      sign_in admin_user, scope: :user
      allow(Facturador::IssuePaymentComplementService).to receive(:call)

      post register_payment_invoice_path(invoice), params: valid_payment_params

      expect(response).to redirect_to(containers_path)
      expect(flash[:notice]).to include('Pago registrado')
      expect(invoice.invoice_payments.count).to eq(1)
      payment = invoice.invoice_payments.last
      expect(payment.tracking_key).to eq('TRACK-REQ-001')
      expect(payment.receipt_file).to be_attached
    end

    it 'registers payment for PUE invoices without blocking the operation' do
      sign_in admin_user, scope: :user
      invoice.update!(payload_snapshot: { metodoPago: 'PUE' })

      post register_payment_invoice_path(invoice), params: valid_payment_params

      expect(response).to redirect_to(containers_path)
      expect(flash[:notice]).to include('Pago registrado')
      expect(invoice.invoice_payments.count).to eq(1)
    end

    it 'shows friendly alert when outstanding amount is zero' do
      sign_in admin_user, scope: :user
      create(:invoice_payment, invoice: invoice, amount: invoice.total, status: 'complement_issued')

      post register_payment_invoice_path(invoice), params: valid_payment_params

      expect(response).to redirect_to(containers_path)
      expect(flash[:alert]).to include('no tiene saldo pendiente')
    end

    it 'denies customs broker users' do
      agency = create(:entity, :customs_agent)
      broker_user = create(:user, :customs_broker, entity: agency)
      related_invoice = create(:invoice, status: 'issued', sat_uuid: 'UUID-PAY-BROKER-001', receiver_entity: create(:entity, :client, customs_agent: agency))
      sign_in broker_user, scope: :user

      post register_payment_invoice_path(related_invoice), params: valid_payment_params

      expect(response).to redirect_to(customs_agents_dashboard_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe 'DELETE /invoices/:id' do
    it 'allows admin to delete non-stamped invoice and its own related payments' do
      sign_in admin_user, scope: :user
      invoice = create(:invoice, status: 'failed', sat_uuid: nil)
      create(:invoice_payment, invoice: invoice, status: 'registered')

      expect {
        delete invoice_path(invoice)
      }.to change(Invoice, :count).by(-1)
        .and change(InvoicePayment, :count).by(-1)

      expect(response).to redirect_to(invoices_path)
      expect(flash[:notice]).to include('Factura no timbrada eliminada correctamente')
    end

    it 'does not allow admin to delete stamped invoice' do
      sign_in admin_user, scope: :user
      invoice = create(:invoice, status: 'issued', sat_uuid: 'UUID-ISSUED-DELETE-001')

      expect {
        delete invoice_path(invoice)
      }.not_to change(Invoice, :count)

      expect(response).to redirect_to(containers_path)
      expect(flash[:alert]).to be_present
    end

    it 'allows deleting non-stamped REP and resets linked payments for regeneration' do
      sign_in admin_user, scope: :user
      source_invoice = create(:invoice, status: 'issued', sat_uuid: 'UUID-SOURCE-REP-001')
      rep_invoice = create(:invoice, kind: 'pago', status: 'failed', sat_uuid: nil)
      payment = create(:invoice_payment, invoice: source_invoice, complement_invoice: rep_invoice, status: 'complement_queued')

      expect {
        delete invoice_path(rep_invoice)
      }.to change(Invoice, :count).by(-1)

      payment.reload
      expect(payment.complement_invoice_id).to be_nil
      expect(payment.status).to eq('registered')
      expect(response).to redirect_to(invoices_path)
      expect(flash[:notice]).to include('listos para regenerar REP')
    end

    it 'denies customs broker users' do
      agency = create(:entity, :customs_agent)
      broker_user = create(:user, :customs_broker, entity: agency)
      sign_in broker_user, scope: :user
      invoice = create(:invoice, status: 'failed', sat_uuid: nil, receiver_entity: create(:entity, :client, customs_agent: agency))

      expect {
        delete invoice_path(invoice)
      }.not_to change(Invoice, :count)

      expect(response).to redirect_to(customs_agents_dashboard_path)
      expect(flash[:alert]).to be_present
    end
  end
end
