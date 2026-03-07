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

      raise RequestError, "Invoice is not in a cancellable state" unless invoice.cancel_retryable?
      raise RequestError, "Invoice UUID is missing" if invoice.sat_uuid.blank?
      raise RequestError, "Only cancellation motive 02 is allowed" unless motive == "02"
      raise RequestError, "Replacement UUID is not allowed for motive 02" if replacement_uuid.present?

      access_token = AccessTokenService.fetch!
      emisor_id = EmisorService.emisor_id!(access_token: access_token)
      client = Client.new(access_token: access_token)
      provider_context = fetch_provider_context(client: client, emisor_id: emisor_id)

      response = client.cancelar_comprobante(
        emisor_id: emisor_id,
        uuid: invoice.sat_uuid,
        motivo: motive,
        folio_sustitucion: nil
      )
      message = nil

      if response["esValido"]
        if response["descripcion"].to_s.downcase.include?("cancelado") || response["subEstatusId"].to_i == 3
          invoice.mark_cancelled!(cancelled_at: Time.current, provider_response: response)
          event_type = "cancel_succeeded"
        else
          invoice.mark_cancel_pending!(motive: motive, replacement_uuid: replacement_uuid, provider_response: response)
          event_type = "cancel_requested"
        end
      else
        message = enrich_error_message(extract_error_message(response), provider_context)
        error_code = ErrorCodeResolver.call(context: :cancel, provider_payload: response, message: message)
        invoice.mark_cancel_failed_attempt!(error_code: error_code, error_message: message, provider_response: response)
        event_type = "cancel_failed"
      end

      invoice.invoice_events.create!(
        event_type: event_type,
        created_by: actor,
        request_payload: { motive: motive, replacement_uuid: replacement_uuid },
        response_payload: response,
        provider_status: response["subEstatusId"]&.to_s,
        provider_error_message: (event_type == "cancel_failed" ? message : response["descripcion"])
      )

      invoice
    rescue Error => e
      fallback_context = begin
        if defined?(client) && defined?(emisor_id) && client.present? && emisor_id.present?
          fetch_provider_context(client: client, emisor_id: emisor_id)
        end
      rescue StandardError
        nil
      end
      detailed_message = enrich_error_message(e.message, fallback_context)

      error_code = ErrorCodeResolver.call(context: :cancel, message: detailed_message, exception: e)
      invoice.mark_cancel_failed_attempt!(error_code: error_code, error_message: detailed_message)
      invoice.invoice_events.create!(
        event_type: "cancel_failed",
        created_by: actor,
        request_payload: { motive: motive, replacement_uuid: replacement_uuid },
        response_payload: {
          error: detailed_message,
          invoice_id: invoice.id,
          sat_uuid: invoice.sat_uuid,
          motive: motive,
          replacement_uuid: replacement_uuid,
          provider_context: fallback_context
        },
        provider_error_message: detailed_message
      )
      raise
    end

    private

    attr_reader :invoice, :motive, :replacement_uuid, :actor

    def extract_error_message(response)
      Facturador::ErrorMessageExtractor.call(response, fallback: "Cancelación PAC no detallada")
    end

    def fetch_provider_context(client:, emisor_id:)
      return nil if invoice.sat_uuid.blank?

      date_from = (invoice.issued_at || invoice.created_at || Time.current).to_i - 2.days.to_i
      date_to = Time.current.to_i

      response = client.buscar_comprobantes(
        emisor_id: emisor_id,
        finicial: date_from,
        ffinal: date_to,
        uuid: invoice.sat_uuid,
        take: 10
      )

      summaries = Array(response["resumenComprobante"])
      found = summaries.find { |item| item["uuid"].to_s.casecmp(invoice.sat_uuid.to_s).zero? }
      return nil unless found.is_a?(Hash)

      {
        estatus: found["estatus"],
        subestatus: found["subestatus"],
        estatus_id: found["estatusId"],
        subestatus_id: found["subestatusId"],
        monto_pagado: found["montoPagado"],
        total: found["total"],
        serie: found["serie"],
        folio: found["folio"],
        fecha: found["fecha"]
      }
    rescue Facturador::Error
      nil
    end

    def enrich_error_message(base_message, provider_context)
      return base_message if provider_context.blank?

      context_parts = []
      context_parts << "estatus=#{provider_context[:estatus]}" if provider_context[:estatus].present?
      context_parts << "subestatus=#{provider_context[:subestatus]}" if provider_context[:subestatus].present?
      if provider_context[:monto_pagado].present? || provider_context[:total].present?
        context_parts << "monto_pagado=#{provider_context[:monto_pagado]}"
        context_parts << "total=#{provider_context[:total]}"
      end
      if provider_context[:serie].present? || provider_context[:folio].present?
        context_parts << "comprobante=#{[ provider_context[:serie], provider_context[:folio] ].compact.join(' ').strip}"
      end

      return base_message if context_parts.empty?

      "#{base_message} [PAC: #{context_parts.join(', ')}]"
    end
  end
end
