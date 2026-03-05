require 'rails_helper'

RSpec.describe Facturador::ReconcileInvoicesService, type: :service do
  describe '.call' do
    let(:client_double) { instance_double(Facturador::Client) }

    before do
      allow(Facturador::Config).to receive(:enabled?).and_return(true)
      allow(Facturador::Config).to receive(:reconciliation_enabled?).and_return(true)
      allow(Facturador::AccessTokenService).to receive(:fetch!).and_return('token-123')
      allow(Facturador::EmisorService).to receive(:emisor_id!).and_return(208)
      allow(Facturador::Client).to receive(:new).with(access_token: 'token-123').and_return(client_double)
    end

    it 'marks invoice as cancelled when provider reports cancelado' do
      invoice = create(:invoice, status: 'issued', sat_uuid: 'UUID-CANCEL')
      allow(client_double).to receive(:buscar_comprobantes).and_return([
        {
          'uuid' => 'UUID-CANCEL',
          'subestatus' => 'Cancelado',
          'descripcion' => 'Cancelado (Directo)',
          'subestatusId' => 3
        }
      ])

      described_class.call(limit: 10)

      invoice.reload
      expect(invoice.status).to eq('cancelled')
      expect(invoice.invoice_events.order(:created_at).last.event_type).to eq('reconcile_synced')
    end

    it 'marks invoice as cancel_pending when provider is waiting cancellation acceptance' do
      invoice = create(:invoice, status: 'issued', sat_uuid: 'UUID-PENDING')
      allow(client_double).to receive(:buscar_comprobantes).and_return([
        {
          'uuid' => 'UUID-PENDING',
          'subestatus' => 'Emitido (Espera Cancelación)',
          'descripcion' => 'Emitido (Espera Cancelación)',
          'subestatusId' => 4
        }
      ])

      described_class.call(limit: 10)

      invoice.reload
      expect(invoice.status).to eq('cancel_pending')
      expect(invoice.invoice_events.order(:created_at).last.event_type).to eq('reconcile_synced')
    end
  end
end
