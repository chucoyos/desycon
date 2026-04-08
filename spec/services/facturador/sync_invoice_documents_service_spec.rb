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
      allow(client_double).to receive(:descargar_xml).and_return('<cfdi:Comprobante xmlns:cfdi="http://www.sat.gob.mx/cfd/4" Serie="GMZO" Folio="1" Fecha="2026-04-07T10:11:12"><cfdi:Emisor Rfc="PTM0701119T6"/></cfdi:Comprobante>')
      allow(client_double).to receive(:generar_pdf).and_return({ 'ok' => true })
      allow(client_double).to receive(:obtener_pdf_url).and_return('https://example.com/test.pdf')
      allow(URI).to receive(:open).and_return(StringIO.new('%PDF-1.4 file'))

      described_class.call(invoice: invoice)

      invoice.reload
      expect(invoice.xml_file).to be_attached
      expect(invoice.pdf_file).to be_attached
      expect(invoice.xml_file.filename.to_s).to eq('PTM0701119T6_GMZO_1_20260407.xml')
      expect(invoice.pdf_file.filename.to_s).to eq('test.pdf')

      event_types = invoice.invoice_events.order(:created_at).pluck(:event_type)
      expect(event_types).to include('xml_requested', 'xml_stored', 'pdf_requested', 'pdf_stored')
    end

    it 'falls back to uuid filename when pdf url has no pdf basename' do
      allow(client_double).to receive(:descargar_xml).and_return('<cfdi>ok</cfdi>')
      allow(client_double).to receive(:generar_pdf).and_return({ 'ok' => true })
      allow(client_double).to receive(:obtener_pdf_url).and_return('https://example.com/download?uuid=UUID-XYZ')
      allow(URI).to receive(:open).and_return(StringIO.new('%PDF-1.4 file'))

      described_class.call(invoice: invoice)

      invoice.reload
      expect(invoice.xml_file).to be_attached
      expect(invoice.xml_file.filename.to_s).to eq('UUID-XYZ.xml')
      expect(invoice.pdf_file).to be_attached
      expect(invoice.pdf_file.filename.to_s).to eq('UUID-XYZ.pdf')
    end

    it 'uses filename from content disposition when available' do
      allow(client_double).to receive(:descargar_xml).and_return('<cfdi>ok</cfdi>')
      allow(client_double).to receive(:generar_pdf).and_return({ 'ok' => true })
      allow(client_double).to receive(:obtener_pdf_url).and_return('https://example.com/download?uuid=UUID-XYZ')

      io = double('downloaded_pdf',
                  read: '%PDF-1.4 file',
                  meta: { 'content-disposition' => 'attachment; filename="PTM0701119T6_GMZO_1_20260407.pdf"' })
      allow(URI).to receive(:open).and_return(io)

      described_class.call(invoice: invoice)

      invoice.reload
      expect(invoice.pdf_file).to be_attached
      expect(invoice.pdf_file.filename.to_s).to eq('PTM0701119T6_GMZO_1_20260407.pdf')
    end

    it 'uses xml-derived basename when pdf url and headers are generic' do
      allow(client_double).to receive(:descargar_xml).and_return('<cfdi:Comprobante xmlns:cfdi="http://www.sat.gob.mx/cfd/4" Serie="GMZO" Folio="1" Fecha="2026-04-07T10:11:12"><cfdi:Emisor Rfc="PTM0701119T6"/></cfdi:Comprobante>')
      allow(client_double).to receive(:generar_pdf).and_return({ 'ok' => true })
      allow(client_double).to receive(:obtener_pdf_url).and_return('https://example.com/download?uuid=UUID-XYZ')
      allow(URI).to receive(:open).and_return(StringIO.new('%PDF-1.4 file'))

      described_class.call(invoice: invoice)

      invoice.reload
      expect(invoice.xml_file.filename.to_s).to eq('PTM0701119T6_GMZO_1_20260407.xml')
      expect(invoice.pdf_file.filename.to_s).to eq('PTM0701119T6_GMZO_1_20260407.pdf')
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

    it 'allows syncing documents for cancel_pending invoices' do
      invoice.update!(status: 'cancel_pending')
      allow(client_double).to receive(:descargar_xml).and_return('<cfdi>pending</cfdi>')
      allow(client_double).to receive(:generar_pdf).and_return({ 'ok' => true })
      allow(client_double).to receive(:obtener_pdf_url).and_return('https://example.com/pending.pdf')
      allow(URI).to receive(:open).and_return(StringIO.new('%PDF-1.4 pending'))

      described_class.call(invoice: invoice)

      invoice.reload
      expect(invoice.xml_file).to be_attached
      expect(invoice.pdf_file).to be_attached
    end

    it 'allows forced sync when manual actions are disabled' do
      allow(Facturador::Config).to receive(:manual_actions_enabled?).and_return(false)
      allow(client_double).to receive(:descargar_xml).and_return('<cfdi>forced</cfdi>')
      allow(client_double).to receive(:generar_pdf).and_return({ 'ok' => true })
      allow(client_double).to receive(:obtener_pdf_url).and_return('https://example.com/forced.pdf')
      allow(URI).to receive(:open).and_return(StringIO.new('%PDF-1.4 forced'))

      described_class.call(invoice: invoice, force: true)

      invoice.reload
      expect(invoice.xml_file).to be_attached
      expect(invoice.pdf_file).to be_attached
    end
  end
end
