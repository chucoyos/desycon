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
      error_code = ErrorCodeResolver.call(context: :issue, message: e.message, exception: e)
      invoice.mark_failed!(error_code: error_code, error_message: e.message)
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

        send_email_non_blocking(trigger: "auto_issue")
      else
        message = extract_error_message(response)
        error_code = ErrorCodeResolver.call(context: :issue, provider_payload: response, message: message)
        invoice.mark_failed!(
          error_code: error_code,
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
      Facturador::ErrorMessageExtractor.call(response, fallback: "Validación PAC no detallada")
    end

    def send_email_non_blocking(trigger:)
      return unless Config.email_enabled?

      Facturador::SendInvoiceEmailJob.perform_later(
        invoice_id: invoice.id,
        trigger: trigger,
        actor_id: actor&.id
      )
    rescue StandardError, NotImplementedError => e
      Rails.logger.warn("Facturador email enqueue skipped after issue for invoice=#{invoice.id}: #{e.message}")
    end
  end
end
