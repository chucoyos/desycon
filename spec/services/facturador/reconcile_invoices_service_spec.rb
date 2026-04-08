require 'rails_helper'

RSpec.describe Facturador::ReconcileInvoicesService, type: :service do
  describe '.call' do
    let(:client_double) { instance_double(Facturador::Client) }

    before do
      allow(Facturador::Config).to receive(:enabled?).and_return(true)
      allow(Facturador::Config).to receive(:reconciliation_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:auto_sync_documents_on_reconcile_enabled?).and_return(false)
      allow(Facturador::Config).to receive(:reconciliation_max_age_days).and_return(60)
      allow(Facturador::AccessTokenService).to receive(:fetch!).and_return('token-123')
      allow(Facturador::EmisorService).to receive(:emisor_id!).and_return(208)
      allow(Facturador::Client).to receive(:new).with(access_token: 'token-123').and_return(client_double)
    end

    it 'marks invoice as cancelled when provider reports cancelado' do
      invoice = create(:invoice, status: 'cancel_pending', sat_uuid: 'UUID-CANCEL')
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
      invoice = create(:invoice, status: 'cancel_pending', sat_uuid: 'UUID-PENDING')
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

    it 'supports hash payload with resumenComprobante array' do
      invoice = create(:invoice, status: 'cancel_pending', sat_uuid: 'UUID-HASH')
      allow(client_double).to receive(:buscar_comprobantes).and_return(
        {
          'numeroComprobantes' => 1,
          'resumenComprobante' => [
            {
              'uuid' => 'UUID-HASH',
              'subestatus' => 'Cancelado',
              'descripcion' => 'Cancelado (Directo)',
              'subestatusId' => 3
            }
          ]
        }
      )

      described_class.call(limit: 10)

      invoice.reload
      expect(invoice.status).to eq('cancelled')
      expect(invoice.invoice_events.order(:created_at).last.event_type).to eq('reconcile_synced')
    end

    it 'keeps cancel_pending when provider does not confirm cancellation status yet' do
      invoice = create(:invoice, status: 'cancel_pending', sat_uuid: 'UUID-EMITIDO-001', facturador_comprobante_id: nil)
      allow(client_double).to receive(:buscar_comprobantes).and_return(
        {
          'numeroComprobantes' => 1,
          'resumenComprobante' => [
            {
              'uuid' => 'UUID-EMITIDO-001',
              'subestatus' => 'Emitido',
              'descripcion' => 'Emitido',
              'subestatusId' => 2,
              'idComprobante' => 0,
              'fecha' => Time.current.iso8601
            }
          ]
        }
      )

      expect { described_class.call(limit: 10) }.not_to raise_error

      invoice.reload
      expect(invoice.status).to eq('cancel_pending')
      expect(invoice.facturador_comprobante_id).to be_nil
      expect(invoice.invoice_events.order(:created_at).last.event_type).to eq('reconcile_synced')
    end

    it 'reconciles issued invoice automatically when it is inside reconciliation window' do
      invoice = create(:invoice, status: 'issued', sat_uuid: 'UUID-EXPLICIT-001')
      allow(client_double).to receive(:buscar_comprobantes).and_return(
        {
          'numeroComprobantes' => 1,
          'resumenComprobante' => [
            {
              'uuid' => 'UUID-EXPLICIT-001',
              'subestatus' => 'Cancelado',
              'descripcion' => 'Cancelado (Directo)',
              'subestatusId' => 3
            }
          ]
        }
      )

      described_class.call(limit: 10)
      expect(invoice.reload.status).to eq('cancelled')
    end

    it 'prioritizes cancel_pending before other reconciliable statuses' do
      issued_invoice = create(:invoice, status: 'issued', sat_uuid: 'UUID-ISSUED-SECOND')
      pending_invoice = create(:invoice, status: 'cancel_pending', sat_uuid: 'UUID-PENDING-FIRST')

      expect(client_double).to receive(:buscar_comprobantes)
        .with(hash_including(uuid: 'UUID-PENDING-FIRST'))
        .once
        .and_return([
          {
            'uuid' => 'UUID-PENDING-FIRST',
            'subestatus' => 'Cancelado',
            'descripcion' => 'Cancelado (Directo)',
            'subestatusId' => 3
          }
        ])

      described_class.call(limit: 1)

      expect(pending_invoice.reload.status).to eq('cancelled')
      expect(issued_invoice.reload.status).to eq('issued')
    end

    it 'excludes invoices older than max age from automatic reconciliation' do
      old_invoice = create(:invoice, status: 'cancel_pending', sat_uuid: 'UUID-OLD-001')
      old_invoice.update_columns(created_at: 90.days.ago, issued_at: 90.days.ago)

      recent_invoice = create(:invoice, status: 'cancel_pending', sat_uuid: 'UUID-RECENT-001')

      allow(client_double).to receive(:buscar_comprobantes).and_return([
        {
          'uuid' => 'UUID-RECENT-001',
          'subestatus' => 'Cancelado',
          'descripcion' => 'Cancelado (Directo)',
          'subestatusId' => 3
        }
      ])

      described_class.call(limit: 10)

      expect(old_invoice.reload.status).to eq('cancel_pending')
      expect(recent_invoice.reload.status).to eq('cancelled')
      expect(client_double).to have_received(:buscar_comprobantes).once
    end

    it 'enqueues document sync when status changes to cancelled and auto sync flag is enabled' do
      invoice = create(:invoice, status: 'issued', sat_uuid: 'UUID-AUTO-SYNC-001')
      allow(Facturador::Config).to receive(:auto_sync_documents_on_reconcile_enabled?).and_return(true)
      allow(client_double).to receive(:buscar_comprobantes).and_return([
        {
          'uuid' => 'UUID-AUTO-SYNC-001',
          'subestatus' => 'Cancelado',
          'descripcion' => 'Cancelado (Directo)',
          'subestatusId' => 3
        }
      ])

      expect(Facturador::SyncInvoiceDocumentsJob).to receive(:perform_later)
        .with(invoice_id: invoice.id, actor_id: nil)

      described_class.call(limit: 10)

      expect(invoice.reload.status).to eq('cancelled')
    end

    it 'does not enqueue document sync when status stays cancel_pending' do
      invoice = create(:invoice, status: 'cancel_pending', sat_uuid: 'UUID-NO-AUTO-SYNC-001')
      allow(Facturador::Config).to receive(:auto_sync_documents_on_reconcile_enabled?).and_return(true)
      allow(client_double).to receive(:buscar_comprobantes).and_return([
        {
          'uuid' => 'UUID-NO-AUTO-SYNC-001',
          'subestatus' => 'Emitido (Espera Cancelación)',
          'descripcion' => 'Emitido (Espera Cancelación)',
          'subestatusId' => 4
        }
      ])

      expect(Facturador::SyncInvoiceDocumentsJob).not_to receive(:perform_later)

      described_class.call(limit: 10)

      expect(invoice.reload.status).to eq('cancel_pending')
    end
  end
end
