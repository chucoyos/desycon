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
        snapshot = invoice.build_persisted_payload_snapshot(payload)
        invoice.update!(payload_snapshot: snapshot)

        access_token = AccessTokenService.fetch!
        emisor_id = EmisorService.emisor_id!(access_token: access_token)
        client = Client.new(access_token: access_token)

        response = client.emitir_comprobante(
          emisor_id: emisor_id,
          payload: snapshot,
          emitir: true
        )

        transient_retry_error = handle_response!(response)
      end

      raise transient_retry_error if transient_retry_error

      invoice
    rescue Error => e
      raise if e.is_a?(TransientIssueError)

      is_transient_transport = transient_transport_retryable?(e)
      message = normalized_issue_error_message(e)
      provider_payload = provider_payload_from_exception(e)

      error_code = ErrorCodeResolver.call(context: :issue, provider_payload: provider_payload, message: message, exception: e)
      failure_provider_response = failure_provider_response_for(error: e, error_code: error_code, message: message, provider_payload: provider_payload)

      invoice.mark_failed!(error_code: error_code, error_message: message, provider_response: failure_provider_response)
      invoice.invoice_events.create!(
        event_type: "issue_failed",
        created_by: actor,
        request_payload: invoice.payload_snapshot,
        response_payload: failure_provider_response,
        provider_error_message: message
      )

      if pending_review_issue_error?(error_code)
        sync_payment_complement_status!("complement_queued")
      elsif !is_transient_transport
        sync_payment_complement_status!("failed")
      end

      if is_transient_transport
        if invoice.kind == "pago"
          raise TransientIssueError, e.message
        end

        enqueue_reconcile_and_sync_non_blocking
        return invoice
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
        enqueue_reconcile_and_sync_non_blocking
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

    def enqueue_reconcile_and_sync_non_blocking
      Facturador::ReconcileAndSyncInvoiceJob.perform_later(
        invoice_id: invoice.id,
        actor_id: actor&.id
      )
    rescue StandardError, NotImplementedError => e
      Rails.logger.warn("Facturador reconcile+sync enqueue skipped after issue for invoice=#{invoice.id}: #{e.message}")
    end

    def transient_provider_retryable?(error_code)
      error_code.to_s == "FACTURADOR_ISSUE_PROVIDER_FAC119"
    end

    def transient_transport_retryable?(error)
      return false unless error.is_a?(RequestError) || error.is_a?(AuthenticationError)

      message = error.message.to_s
      message.match?(/Temporary failure in name resolution|getaddrinfo\(3\)|Failed to open TCP connection|execution expired|timed out|timeout/i)
    end

    def normalized_issue_error_message(error)
      base = error.message.to_s
      return base unless invoice.kind == "pago"
      return base unless potential_pending_timbrado_error?(base)

      "#{base} | Posible estado pendiente en PAC: el comprobante pudo registrarse sin timbrarse. Verifica en Facturador antes de reintentar para evitar duplicados."
    end

    def potential_pending_timbrado_error?(message)
      message.match?(/(?:\A|\s)500:/i) &&
        message.match?(%r{POST\s+/api/v1/emisores/\d+/comprobantes}i) &&
        message.match?(/query=emitir=true/i)
    end

    def sync_payment_complement_status!(status)
      return unless invoice.kind == "pago"

      invoice.payment_complements.update_all(status: status, updated_at: Time.current)
    end

    def pending_review_issue_error?(error_code)
      error_code.to_s == "FACTURADOR_ISSUE_PENDING_REVIEW"
    end

    def provider_payload_from_exception(error)
      return unless error.respond_to?(:provider_payload)

      error.provider_payload
    end

    def failure_provider_response_for(error:, error_code:, message:, provider_payload:)
      payload = provider_payload.is_a?(Hash) ? provider_payload.deep_stringify_keys : {}
      payload = payload.merge(
        "issue_error_diagnostics" => issue_error_diagnostics(error: error, error_code: error_code, message: message)
      )

      payload
    end

    def issue_error_diagnostics(error:, error_code:, message:)
      diagnostics = {
        "error_code" => error_code,
        "error_message" => message
      }

      if error.respond_to?(:to_h)
        request_error_details = error.to_h.deep_stringify_keys
        diagnostics["request_error"] = request_error_details if request_error_details.present?
      end

      diagnostics
    end
  end
end
