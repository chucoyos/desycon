require "open-uri"
require "stringio"

module Facturador
  class SyncInvoiceDocumentsService
    class << self
      def call(invoice:, actor: nil, force: false)
        new(invoice: invoice, actor: actor, force: force).call
      end
    end

    def initialize(invoice:, actor: nil, force: false)
      @invoice = invoice
      @actor = actor
      @force = force
    end

    def call
      return invoice unless Config.enabled?
      return invoice unless force || Config.manual_actions_enabled?
      raise RequestError, "Invoice is not syncable" unless invoice.status.in?(%w[issued cancelled])
      raise RequestError, "Invoice UUID is missing" if invoice.sat_uuid.blank?

      access_token = AccessTokenService.fetch!
      emisor_id = EmisorService.emisor_id!(access_token: access_token)
      client = Client.new(access_token: access_token)

      sync_xml!(client: client, emisor_id: emisor_id)
      sync_pdf!(client: client, emisor_id: emisor_id)

      invoice
    end

    private

    attr_reader :invoice, :actor, :force

    def sync_xml!(client:, emisor_id:)
      invoice.invoice_events.create!(
        event_type: "xml_requested",
        created_by: actor,
        request_payload: { emisor_id: emisor_id, uuid: invoice.sat_uuid },
        response_payload: {}
      )

      xml_body = client.descargar_xml(emisor_id: emisor_id, uuid: invoice.sat_uuid)
      raise RequestError, "XML response is empty" if xml_body.blank?

      invoice.xml_file.attach(
        io: StringIO.new(xml_body),
        filename: "#{invoice.sat_uuid}.xml",
        content_type: "application/xml"
      )

      invoice.invoice_events.create!(
        event_type: "xml_stored",
        created_by: actor,
        request_payload: { uuid: invoice.sat_uuid },
        response_payload: { bytes: xml_body.bytesize }
      )
    end

    def sync_pdf!(client:, emisor_id:)
      invoice.invoice_events.create!(
        event_type: "pdf_requested",
        created_by: actor,
        request_payload: { emisor_id: emisor_id, uuid: invoice.sat_uuid },
        response_payload: {}
      )

      client.generar_pdf(emisor_id: emisor_id, uuid: invoice.sat_uuid)
      pdf_url = client.obtener_pdf_url(emisor_id: emisor_id, uuid: invoice.sat_uuid)
      raise RequestError, "PDF URL is invalid" unless pdf_url.start_with?("http://", "https://")

      pdf_bytes = URI.open(pdf_url, read_timeout: 30).read
      raise RequestError, "PDF content is empty" if pdf_bytes.blank?

      invoice.pdf_file.attach(
        io: StringIO.new(pdf_bytes),
        filename: "#{invoice.sat_uuid}.pdf",
        content_type: "application/pdf"
      )

      invoice.invoice_events.create!(
        event_type: "pdf_stored",
        created_by: actor,
        request_payload: { uuid: invoice.sat_uuid, url: pdf_url },
        response_payload: { bytes: pdf_bytes.bytesize }
      )
    end
  end
end
