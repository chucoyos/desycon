module Facturador
  class CancelInvoiceService
    class << self
      def call(invoice:, motive:, replacement_uuid: nil, actor: nil)
        new(invoice: invoice, motive: motive, replacement_uuid: replacement_uuid, actor: actor).call
      end
    end

    def initialize(invoice:, motive:, replacement_uuid:, actor: nil)
      @invoice = invoice
      @motive = motive
      @replacement_uuid = replacement_uuid
      @actor = actor
    end

    def call
      return invoice unless Config.enabled?
      return invoice unless Config.manual_actions_enabled?

      raise RequestError, "Invoice is not issued" unless invoice.issued?
      raise RequestError, "Invoice UUID is missing" if invoice.sat_uuid.blank?
      raise RequestError, "Only cancellation motive 02 is allowed" unless motive == "02"
      raise RequestError, "Replacement UUID is not allowed for motive 02" if replacement_uuid.present?

      access_token = AccessTokenService.fetch!
      emisor_id = EmisorService.emisor_id!(access_token: access_token)
      client = Client.new(access_token: access_token)

      response = client.cancelar_comprobante(
        emisor_id: emisor_id,
        uuid: invoice.sat_uuid,
        motivo: motive,
        folio_sustitucion: nil
      )

      if response["esValido"]
        if response["descripcion"].to_s.downcase.include?("cancelado") || response["subEstatusId"].to_i == 3
          invoice.mark_cancelled!(cancelled_at: Time.current, provider_response: response)
          event_type = "cancel_succeeded"
        else
          invoice.mark_cancel_pending!(motive: motive, replacement_uuid: replacement_uuid, provider_response: response)
          event_type = "cancel_requested"
        end
      else
        message = extract_error_message(response)
        invoice.mark_failed!(error_code: "FACTURADOR_CANCEL_INVALID", error_message: message, provider_response: response)
        event_type = "cancel_failed"
      end

      invoice.invoice_events.create!(
        event_type: event_type,
        created_by: actor,
        request_payload: { motive: motive, replacement_uuid: replacement_uuid },
        response_payload: response,
        provider_status: response["subEstatusId"]&.to_s,
        provider_error_message: response["descripcion"]
      )

      invoice
    rescue Error => e
      invoice.mark_failed!(error_code: "FACTURADOR_CANCEL_ERROR", error_message: e.message)
      invoice.invoice_events.create!(
        event_type: "cancel_failed",
        created_by: actor,
        request_payload: { motive: motive, replacement_uuid: replacement_uuid },
        response_payload: { error: e.message },
        provider_error_message: e.message
      )
      raise
    end

    private

    attr_reader :invoice, :motive, :replacement_uuid, :actor

    def extract_error_message(response)
      errors = response["errores"]
      return response["descripcion"] if errors.blank?

      if errors.is_a?(Array)
        errors.map { |item| item["mensaje"] || item["message"] }.compact.join(" | ")
      else
        errors.to_s
      end
    end
  end
end
