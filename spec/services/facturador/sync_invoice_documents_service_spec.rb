require 'rails_helper'

RSpec.describe Facturador::SyncInvoiceDocumentsService, type: :service do
  describe '.call' do
    let(:invoice) do
      create(
        :invoice,
        status: 'issued',
        sat_uuid: 'UUID-XYZ',
        payload_snapshot: { 'sample' => 'payload' }
      )
    end

    let(:client_double) { instance_double(Facturador::Client) }

    before do
      allow(Facturador::Config).to receive(:enabled?).and_return(true)
      allow(Facturador::Config).to receive(:manual_actions_enabled?).and_return(true)
      allow(Facturador::AccessTokenService).to receive(:fetch!).and_return('token-123')
      allow(Facturador::EmisorService).to receive(:emisor_id!).and_return(208)
      allow(Facturador::Client).to receive(:new).with(access_token: 'token-123').and_return(client_double)
    end

    it 'stores xml and pdf attachments and creates events' do
      allow(client_double).to receive(:descargar_xml).and_return('<cfdi>ok</cfdi>')
      allow(client_double).to receive(:generar_pdf).and_return({ 'ok' => true })
      allow(client_double).to receive(:obtener_pdf_url).and_return('https://example.com/test.pdf')
      allow(URI).to receive(:open).and_return(StringIO.new('%PDF-1.4 file'))

      described_class.call(invoice: invoice)

      invoice.reload
      expect(invoice.xml_file).to be_attached
      expect(invoice.pdf_file).to be_attached

      event_types = invoice.invoice_events.order(:created_at).pluck(:event_type)
      expect(event_types).to include('xml_requested', 'xml_stored', 'pdf_requested', 'pdf_stored')
    end

    it 'allows syncing documents for cancelled invoices' do
      invoice.update!(status: 'cancelled')
      allow(client_double).to receive(:descargar_xml).and_return('<cfdi>cancelled</cfdi>')
      allow(client_double).to receive(:generar_pdf).and_return({ 'ok' => true })
      allow(client_double).to receive(:obtener_pdf_url).and_return('https://example.com/cancelled.pdf')
      allow(URI).to receive(:open).and_return(StringIO.new('%PDF-1.4 cancelled'))

      described_class.call(invoice: invoice)

      invoice.reload
      expect(invoice.xml_file).to be_attached
      expect(invoice.pdf_file).to be_attached
    end
  end
end
