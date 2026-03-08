require 'rails_helper'

RSpec.describe Facturador::IssueInvoiceService, type: :service do
  describe '.call' do
    let(:issuer_entity) { create(:entity, :customs_agent, :with_fiscal_profile, :with_address) }
    let(:receiver_entity) { create(:entity, :client, :with_fiscal_profile, :with_address) }
    let(:service_catalog) do
      create(
        :service_catalog,
        sat_clave_prod_serv: '80151600',
        sat_clave_unidad: 'E48',
        sat_objeto_imp: '02'
      )
    end
    let(:invoiceable) { create(:container_service, service_catalog: service_catalog) }

    let(:invoice) do
      create(
        :invoice,
        invoiceable: invoiceable,
        issuer_entity: issuer_entity,
        receiver_entity: receiver_entity,
        status: 'draft',
        payload_snapshot: { 'sample' => 'payload' }
      )
    end

    let(:client_double) { instance_double(Facturador::Client) }

    before do
      allow(Facturador::Config).to receive(:enabled?).and_return(true)
      allow(Facturador::Config).to receive(:email_enabled?).and_return(false)
      allow(Facturador::AccessTokenService).to receive(:fetch!).and_return('token-123')
      allow(Facturador::EmisorService).to receive(:emisor_id!).and_return(208)
      allow(Facturador::Client).to receive(:new).with(access_token: 'token-123').and_return(client_double)
    end

    it 'marks invoice as issued when provider response is valid' do
      allow(client_double).to receive(:emitir_comprobante).and_return(
        {
          'esValido' => true,
          'uuid' => 'UUID-123',
          'idComprobante' => 10,
          'subEstatusId' => 2
        }
      )

      described_class.call(invoice_id: invoice.id)

      invoice.reload
      expect(invoice.status).to eq('issued')
      expect(invoice.sat_uuid).to eq('UUID-123')
      expect(invoice.facturador_comprobante_id).to eq(10)
      expect(invoice.invoice_events.order(:created_at).last.event_type).to eq('issue_succeeded')
    end

    it 'marks invoice as failed when provider response is invalid' do
      allow(client_double).to receive(:emitir_comprobante).and_return(
        {
          'esValido' => false,
          'descripcion' => 'Error de validación',
          'errores' => [ { 'mensaje' => 'RFC inválido' } ]
        }
      )

      described_class.call(invoice_id: invoice.id)

      invoice.reload
      expect(invoice.status).to eq('failed')
      expect(invoice.last_error_code).to eq('FACTURADOR_ISSUE_PROVIDER_ERROR')
      expect(invoice.last_error_message).to include('RFC inválido')
      expect(invoice.invoice_events.order(:created_at).last.event_type).to eq('issue_failed')
    end

    it 'raises transient issue error for FAC119 provider code so job can retry' do
      allow(client_double).to receive(:emitir_comprobante).and_return(
        {
          'esValido' => false,
          'errores' => [ { 'codigo' => 'FAC119', 'mensaje' => 'La serie del comprobante no esta disponible. Intentar mas tarde.' } ]
        }
      )

      expect {
        described_class.call(invoice_id: invoice.id)
      }.to raise_error(Facturador::TransientIssueError, /serie del comprobante/i)

      invoice.reload
      expect(invoice.status).to eq('failed')
      expect(invoice.last_error_code).to eq('FACTURADOR_ISSUE_PROVIDER_FAC119')
      expect(invoice.invoice_events.order(:created_at).last.event_type).to eq('issue_failed')
    end

    it 'marks invoice as failed and re-raises when request error happens' do
      allow(client_double).to receive(:emitir_comprobante).and_raise(Facturador::RequestError, 'timeout')

      expect {
        described_class.call(invoice_id: invoice.id)
      }.to raise_error(Facturador::RequestError, 'timeout')

      invoice.reload
      expect(invoice.status).to eq('failed')
      expect(invoice.last_error_code).to eq('FACTURADOR_ISSUE_TIMEOUT_ERROR')
      expect(invoice.last_error_message).to eq('timeout')
      expect(invoice.invoice_events.order(:created_at).last.event_type).to eq('issue_failed')
    end
  end
end
