require 'rails_helper'

RSpec.describe Facturador::ImportExternalInvoicesService, type: :service do
  describe '.call' do
    let(:client_double) { instance_double(Facturador::Client) }
    let(:issuer_entity) { create(:entity, :customs_agent) }

    before do
      allow(Facturador::Config).to receive(:enabled?).and_return(true)
      allow(Facturador::Config).to receive(:external_invoices_sync_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:external_invoices_runtime_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:external_sync_take).and_return(2)
      allow(Facturador::Config).to receive(:external_sync_max_pages).and_return(nil)
      allow(Facturador::Config).to receive(:issuer_entity).and_return(issuer_entity)
      allow(Facturador::AccessTokenService).to receive(:fetch!).and_return('token-123')
      allow(Facturador::EmisorService).to receive(:emisor_id!).and_return(208)
      allow(Facturador::Client).to receive(:new).with(access_token: 'token-123').and_return(client_double)
    end

    it 'creates missing external invoices with mapped visibility' do
      receiver = create(:entity, :client, customs_agent: create(:entity, :customs_agent))
      receiver_fiscal_profile = create(
        :fiscal_profile,
        profileable: receiver,
        rfc: 'AAA010101AAA',
        razon_social: 'Receptor Fiscal Mapeado SA de CV'
      )

      allow(client_double).to receive(:buscar_comprobantes)
        .and_return(
          [
            {
              'uuid' => 'UUID-EXT-001',
              'idComprobante' => 123456,
              'receptorRfc' => 'AAA010101AAA',
              'fecha' => Time.current.iso8601,
              'estatus' => 'Emitido',
              'subestatus' => 'Emitido',
              'serie' => 'A',
              'folio' => '100',
              'subtotal' => '100.00',
              'impuestos' => '16.00',
              'total' => '116.00',
              'moneda' => 'MXN'
            }
          ],
          []
        )

      summary = described_class.call(window_start: 1.day.ago, window_end: Time.current, source: 'test')

      expect(summary.created_count).to eq(1)
      expect(summary.error_count).to eq(0)

      invoice = Invoice.find_by(sat_uuid: 'UUID-EXT-001')
      expect(invoice).to be_present
      expect(invoice.source_origin).to eq('facturador_external')
      expect(invoice.external_visibility_state).to eq('mapped')
      expect(invoice.receiver_entity_id).to eq(receiver.id)
      expect(invoice.payload_snapshot.dig('receptor', 'rfc')).to eq('AAA010101AAA')
      expect(invoice.payload_snapshot.dig('receptor', 'nombre')).to eq(receiver.name)
      expect(invoice.payload_snapshot['formaPago']).to eq(receiver_fiscal_profile.forma_pago)
      expect(invoice.payload_snapshot['metodoPago']).to eq(receiver_fiscal_profile.metodo_pago)
      expect(invoice.payload_snapshot['conceptos']).to be_present
      expect(invoice.invoice_events.order(:created_at).last.event_type).to eq('external_import_created')
    end

    it 'marks invoice as pending assignment when receiver mapping is not found' do
      allow(client_double).to receive(:buscar_comprobantes)
        .and_return(
          [
            {
              'uuid' => 'UUID-EXT-PENDING-001',
              'idComprobante' => 223344,
              'receptorRfc' => 'RFC-NO-EXISTE',
              'fecha' => Time.current.iso8601,
              'estatus' => 'Emitido',
              'subestatus' => 'Emitido',
              'serie' => 'B',
              'folio' => '200',
              'subtotal' => '50.00',
              'impuestos' => '8.00',
              'total' => '58.00',
              'moneda' => 'MXN'
            }
          ],
          []
        )

      summary = described_class.call(window_start: 1.day.ago, window_end: Time.current, source: 'test')

      expect(summary.created_count).to eq(1)
      expect(summary.pending_assignment_count).to eq(1)

      invoice = Invoice.find_by(sat_uuid: 'UUID-EXT-PENDING-001')
      expect(invoice).to be_present
      expect(invoice.external_visibility_state).to eq('pending_assignment')
      expect(invoice.receiver_entity_id).to eq(issuer_entity.id)
      expect(invoice.invoice_events.order(:created_at).last.event_type).to eq('external_import_pending_assignment')
    end

    it 'does not duplicate when invoice already exists by sat_uuid' do
      existing = create(
        :invoice,
        sat_uuid: 'UUID-EXT-EXISTING-001',
        source_origin: 'facturador_external',
        external_visibility_state: 'mapped'
      )

      allow(client_double).to receive(:buscar_comprobantes)
        .and_return(
          [
            {
              'uuid' => 'UUID-EXT-EXISTING-001',
              'idComprobante' => existing.facturador_comprobante_id || 998877,
              'receptorRfc' => 'RFC-NO-EXISTE',
              'fecha' => Time.current.iso8601,
              'estatus' => 'Emitido',
              'subestatus' => 'Emitido',
              'serie' => 'C',
              'folio' => '300',
              'subtotal' => existing.subtotal.to_s,
              'impuestos' => existing.tax_total.to_s,
              'total' => existing.total.to_s,
              'moneda' => 'MXN'
            }
          ],
          []
        )

      summary = described_class.call(window_start: 1.day.ago, window_end: Time.current, source: 'test')

      expect(summary.created_count).to eq(0)
      expect(summary.duplicate_count + summary.updated_count).to eq(1)
      expect(Invoice.where(sat_uuid: 'UUID-EXT-EXISTING-001').count).to eq(1)
    end
  end
end
