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
      transient_retry_error = nil

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

        transient_retry_error = handle_response!(response)
      end

      raise transient_retry_error if transient_retry_error

      invoice
    rescue Error => e
      raise if e.is_a?(TransientIssueError)

      is_transient_transport = transient_transport_retryable?(e) || transient_rep_pending_retryable?(e)

      error_code = ErrorCodeResolver.call(context: :issue, message: e.message, exception: e)
      invoice.mark_failed!(error_code: error_code, error_message: e.message)
      invoice.invoice_events.create!(
        event_type: "issue_failed",
        created_by: actor,
        request_payload: invoice.payload_snapshot,
        response_payload: { error: e.message },
        provider_error_message: e.message
      )

      sync_payment_complement_status!("failed") unless is_transient_transport

      if is_transient_transport
        raise TransientIssueError, e.message
      end

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

        sync_payment_complement_status!("complement_issued")

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

        sync_payment_complement_status!("failed") unless transient_provider_retryable?(error_code)

        return TransientIssueError.new(message) if transient_provider_retryable?(error_code)
      end

      nil
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

    def transient_provider_retryable?(error_code)
      error_code.to_s == "FACTURADOR_ISSUE_PROVIDER_FAC119"
    end

    def transient_transport_retryable?(error)
      return false unless error.is_a?(RequestError) || error.is_a?(AuthenticationError)

      message = error.message.to_s
      message.match?(/Temporary failure in name resolution|getaddrinfo\(3\)|Failed to open TCP connection|execution expired|timed out|timeout/i)
    end

    def transient_rep_pending_retryable?(error)
      return false unless invoice.kind == "pago"
      return false unless error.is_a?(RequestError)

      message = error.message.to_s
      message.include?("500: An error has occurred.") &&
        message.include?("POST /api/v1/emisores/") &&
        message.include?("query=emitir=true")
    end

    def sync_payment_complement_status!(status)
      return unless invoice.kind == "pago"

      invoice.payment_complements.update_all(status: status, updated_at: Time.current)
    end
  end
end
