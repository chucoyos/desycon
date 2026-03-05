module Facturador
  class IssueInvoiceService
    class << self
      def call(invoice_id:, actor: nil)
        new(invoice_id: invoice_id, actor: actor).call
      end
    end

    def initialize(invoice_id:, actor: nil)
      @invoice_id = invoice_id
      @actor = actor
    end

    def call
      return unless Config.enabled?

      invoice.with_lock do
        return invoice if invoice.issued?

        payload = PayloadBuilder.build(invoice)
        invoice.update!(payload_snapshot: payload)

        access_token = AccessTokenService.fetch!
        emisor_id = EmisorService.emisor_id!(access_token: access_token)
        client = Client.new(access_token: access_token)

        response = client.emitir_comprobante(
          emisor_id: emisor_id,
          payload: payload,
          emitir: true
        )

        handle_response!(response)
      end

      invoice
    rescue Error => e
      invoice.mark_failed!(error_code: "FACTURADOR_ERROR", error_message: e.message)
      invoice.invoice_events.create!(
        event_type: "issue_failed",
        created_by: actor,
        request_payload: invoice.payload_snapshot,
        response_payload: { error: e.message },
        provider_error_message: e.message
      )
      raise
    end

    private

    attr_reader :invoice_id, :actor

    def invoice
      @invoice ||= Invoice.find(invoice_id)
    end

    def handle_response!(response)
      if response["esValido"]
        invoice.mark_issued!(
          uuid: response["uuid"],
          comprobante_id: response["idComprobante"],
          issued_at: Time.current,
          provider_response: response
        )

        invoice.invoice_events.create!(
          event_type: "issue_succeeded",
          created_by: actor,
          request_payload: invoice.payload_snapshot,
          response_payload: response,
          provider_status: response["subEstatusId"]&.to_s
        )
      else
        message = extract_error_message(response)
        invoice.mark_failed!(
          error_code: "FACTURADOR_INVALID",
          error_message: message,
          provider_response: response
        )

        invoice.invoice_events.create!(
          event_type: "issue_failed",
          created_by: actor,
          request_payload: invoice.payload_snapshot,
          response_payload: response,
          provider_error_message: message
        )
      end
    end

    def extract_error_message(response)
      errors = response["errores"]
      return response["descripcion"].presence || "Validación PAC no detallada" if errors.blank?

      return errors.to_s unless errors.is_a?(Array)

      messages = errors.filter_map do |item|
        item["mensaje"] || item["message"]
      end

      messages.presence&.join(" | ") || "Validación PAC no detallada"
    end
  end
end
