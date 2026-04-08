require "open-uri"
require "stringio"
require "nokogiri"

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
        filename: xml_filename_from_content(xml_body),
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

      downloaded_pdf = URI.open(pdf_url, read_timeout: 30)
      pdf_bytes = downloaded_pdf.read
      raise RequestError, "PDF content is empty" if pdf_bytes.blank?
      pdf_filename = pdf_filename_from_response(pdf_url, downloaded_pdf)

      invoice.pdf_file.attach(
        io: StringIO.new(pdf_bytes),
        filename: pdf_filename,
        content_type: "application/pdf"
      )

      invoice.invoice_events.create!(
        event_type: "pdf_stored",
        created_by: actor,
        request_payload: { uuid: invoice.sat_uuid, url: pdf_url },
        response_payload: { bytes: pdf_bytes.bytesize }
      )
    end

    def pdf_filename_from_url(pdf_url)
      uri = URI.parse(pdf_url)
      basename = File.basename(uri.path.to_s)
      return basename if basename.present? && basename != "/" && basename.downcase.end_with?(".pdf")

      "#{invoice.sat_uuid}.pdf"
    rescue URI::InvalidURIError
      "#{invoice.sat_uuid}.pdf"
    end

    def pdf_filename_from_response(pdf_url, downloaded_pdf)
      header_filename = extract_filename_from_content_disposition(downloaded_pdf)
      return header_filename if header_filename.present?

      pdf_filename_from_url(pdf_url)
    end

    def extract_filename_from_content_disposition(downloaded_pdf)
      return nil unless downloaded_pdf.respond_to?(:meta)

      disposition = downloaded_pdf.meta["content-disposition"].to_s
      return nil if disposition.blank?

      match = disposition.match(/filename\*=UTF-8''([^;]+)|filename="?([^";]+)"?/i)
      raw = match&.captures&.compact&.first.to_s
      return nil if raw.blank?

      filename = URI.decode_www_form_component(raw).strip
      filename if filename.downcase.end_with?(".pdf")
    rescue StandardError
      nil
    end

    def xml_filename_from_content(xml_body)
      document = Nokogiri::XML(xml_body.to_s) { |config| config.nonet }
      comprobante = document.at_xpath("//*[local-name()='Comprobante']")
      emisor = document.at_xpath("//*[local-name()='Emisor']")

      rfc = normalized_filename_token(emisor&.[]("Rfc") || emisor&.[]("RFC"))
      serie = normalized_filename_token(comprobante&.[]("Serie") || comprobante&.[]("serie"))
      folio = normalized_filename_token(comprobante&.[]("Folio") || comprobante&.[]("folio"))
      fecha_raw = comprobante&.[]("Fecha") || comprobante&.[]("fecha")
      fecha = normalized_filename_token(fecha_raw.to_s.split("T").first&.delete("-"))

      parts = [ rfc, serie, folio, fecha ].compact
      return "#{parts.join('_')}.xml" if parts.any?

      "#{invoice.sat_uuid}.xml"
    rescue StandardError
      "#{invoice.sat_uuid}.xml"
    end

    def normalized_filename_token(value)
      token = value.to_s.strip
      return nil if token.blank?

      token.gsub(/[^0-9A-Za-z_-]/, "")
    end
  end
end
