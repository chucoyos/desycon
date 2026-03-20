require 'rails_helper'

RSpec.describe Facturador::CancelInvoiceService, type: :service do
  describe '.call' do
    let(:invoice) { create(:invoice, status: 'issued', sat_uuid: 'UUID-CANCEL-001') }
    let(:actor) { create(:user, :admin) }
    let(:client_double) { instance_double(Facturador::Client) }

    before do
      allow(Facturador::Config).to receive(:enabled?).and_return(true)
      allow(Facturador::Config).to receive(:manual_actions_enabled?).and_return(true)
      allow(Facturador::AccessTokenService).to receive(:fetch!).and_return('token-123')
      allow(Facturador::EmisorService).to receive(:emisor_id!).and_return(208)
      allow(Facturador::Client).to receive(:new).with(access_token: 'token-123').and_return(client_double)
      allow(client_double).to receive(:buscar_comprobantes).and_return({ 'resumenComprobante' => [] })
    end

    it 'marks invoice as cancelled when PAC confirms immediate cancellation' do
      allow(client_double).to receive(:cancelar_comprobante).and_return(
        {
          'esValido' => true,
          'descripcion' => 'Cancelado (Directo)',
          'subEstatusId' => 3
        }
      )

      result = described_class.call(invoice: invoice, motive: '02', replacement_uuid: nil, actor: actor)

      expect(result).to eq(invoice)
      expect(invoice.reload.status).to eq('cancelled')
      expect(invoice.cancellation_motive).to be_blank
      expect(invoice.cancelled_at).to be_present
      expect(invoice.invoice_events.order(:created_at).last.event_type).to eq('cancel_succeeded')
    end

    it 'marks invoice as cancel_pending when PAC accepts but does not confirm final cancellation' do
      allow(client_double).to receive(:cancelar_comprobante).and_return(
        {
          'esValido' => true,
          'descripcion' => 'Emitido (Espera Cancelación)',
          'subEstatusId' => 4
        }
      )

      described_class.call(invoice: invoice, motive: '02', replacement_uuid: nil, actor: actor)

      invoice.reload
      expect(invoice.status).to eq('cancel_pending')
      expect(invoice.cancellation_motive).to eq('02')
      expect(invoice.invoice_events.order(:created_at).last.event_type).to eq('cancel_requested')
    end

    it 'keeps invoice issued and records failed cancel attempt when PAC rejects cancellation' do
      allow(client_double).to receive(:cancelar_comprobante).and_return(
        {
          'esValido' => false,
          'descripcion' => 'No se puede cancelar en este momento'
        }
      )

      expect {
        described_class.call(invoice: invoice, motive: '02', replacement_uuid: nil, actor: actor)
      }.not_to raise_error

      invoice.reload
      expect(invoice.status).to eq('issued')
      expect(invoice.last_error_code).to start_with('FACTURADOR_CANCEL_')
      expect(invoice.last_error_message).to be_present
      expect(invoice.invoice_events.order(:created_at).last.event_type).to eq('cancel_failed')
    end

    it 'raises for invalid motive and records a failed event' do
      expect {
        described_class.call(invoice: invoice, motive: '01', replacement_uuid: nil, actor: actor)
      }.to raise_error(Facturador::RequestError, /Only cancellation motive 02 is allowed/)

      invoice.reload
      expect(invoice.status).to eq('issued')
      expect(invoice.last_error_code).to start_with('FACTURADOR_CANCEL_')
      expect(invoice.invoice_events.order(:created_at).last.event_type).to eq('cancel_failed')
    end

    it 'allows cancellation retry for failed invoices caused by previous cancellation attempts' do
      invoice.update!(
        status: 'failed',
        sat_uuid: 'UUID-CANCEL-001',
        last_error_code: 'FACTURADOR_CANCEL_ERROR',
        last_error_message: 'Intento anterior fallido'
      )
      allow(client_double).to receive(:cancelar_comprobante).and_return(
        {
          'esValido' => true,
          'descripcion' => 'Cancelado (Directo)',
          'subEstatusId' => 3
        }
      )

      described_class.call(invoice: invoice, motive: '02', replacement_uuid: nil, actor: actor)

      invoice.reload
      expect(invoice.status).to eq('cancelled')
      expect(invoice.invoice_events.order(:created_at).last.event_type).to eq('cancel_succeeded')
    end

    it 'returns invoice unchanged when manual actions are disabled' do
      allow(Facturador::Config).to receive(:manual_actions_enabled?).and_return(false)

      result = described_class.call(invoice: invoice, motive: '02', replacement_uuid: nil, actor: actor)

      expect(result).to eq(invoice)
      expect(invoice.reload.status).to eq('issued')
      expect(invoice.invoice_events).to be_empty
    end

    it 'stores detailed cancel error context when provider raises request error' do
      allow(client_double).to receive(:cancelar_comprobante).and_raise(
        Facturador::RequestError,
        '500: An error has occurred. (DELETE /BusinessEmision/api/v1/emisores/208/comprobantes/UUID-CANCEL-001, query=motivo=02, request_id=abc-123)'
      )

      expect {
        described_class.call(invoice: invoice, motive: '02', replacement_uuid: nil, actor: actor)
      }.to raise_error(Facturador::RequestError, /request_id=abc-123/)

      invoice.reload
      expect(invoice.status).to eq('issued')
      event = invoice.invoice_events.order(:created_at).last
      expect(event.event_type).to eq('cancel_failed')
      expect(event.response_payload['sat_uuid']).to eq('UUID-CANCEL-001')
      expect(event.provider_error_message).to include('DELETE /BusinessEmision')
    end
  end
end
