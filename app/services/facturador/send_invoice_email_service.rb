module Facturador
  class SendInvoiceEmailService
    class << self
      def call(invoice:, actor: nil, trigger: "manual")
        new(invoice: invoice, actor: actor, trigger: trigger).call
      end
    end

    def initialize(invoice:, actor:, trigger:)
      @invoice = invoice
      @actor = actor
      @trigger = trigger
    end

    def call
      return invoice unless Config.enabled?
      unless Config.email_enabled?
        raise ValidationError, "Email sending via PAC is disabled" if manual_trigger?

        return invoice
      end

      validate_invoice!

      access_token = AccessTokenService.fetch!
      emisor_id = EmisorService.emisor_id!(access_token: access_token)
      client = Client.new(access_token: access_token)

      payload = build_payload(client: client, emisor_id: emisor_id)
      invoice.invoice_events.create!(
        event_type: "email_requested",
        created_by: actor,
        request_payload: { trigger: trigger, para: payload["para"], cc: payload["cc"], responderA: payload["responderA"] },
        response_payload: payload
      )

      response = client.enviar_correo_cfdi(emisor_id: emisor_id, payload: payload)
      message = parse_response_message(response)

      if response_invalid?(response)
        error_code = ErrorCodeResolver.call(context: :email, provider_payload: response, message: message)
        invoice.invoice_events.create!(
          event_type: "email_failed",
          created_by: actor,
          request_payload: { trigger: trigger, para: payload["para"], cc: payload["cc"], responderA: payload["responderA"] },
          response_payload: response,
          provider_error_message: message
        )
        raise RequestError, "#{error_code}: #{message}"
      end

      invoice.invoice_events.create!(
        event_type: "email_sent",
        created_by: actor,
        request_payload: { trigger: trigger, para: payload["para"], cc: payload["cc"], responderA: payload["responderA"] },
        response_payload: response,
        provider_error_message: message
      )

      invoice
    rescue Error => e
      invoice.invoice_events.create!(
        event_type: "email_failed",
        created_by: actor,
        request_payload: { trigger: trigger },
        response_payload: { error: e.message, trigger: trigger },
        provider_error_message: e.message
      )
      raise
    end

    private

    attr_reader :invoice, :actor, :trigger

    def validate_invoice!
      raise ValidationError, "Invoice UUID is missing" if invoice.sat_uuid.blank?
      raise ValidationError, "Invoice is not in a mailable state" unless invoice.status.in?(%w[issued cancelled])
      raise ValidationError, "Receiver fiscal email is missing" if receiver_email.blank?
    end

    def receiver_email
      @receiver_email ||= invoice.receiver_entity&.fiscal_address&.email.to_s.strip
    end

    def build_payload(client:, emisor_id:)
      {
        "asunto" => Config.email_subject,
        "cc" => receiver_email,
        "mensaje" => Config.email_message,
        "para" => receiver_email,
        "responderA" => receiver_email,
        "cfdi" => build_cfdi_payload(client: client, emisor_id: emisor_id)
      }
    end

    def build_cfdi_payload(client:, emisor_id:)
      provider = provider_summary(client: client, emisor_id: emisor_id)
      payload = invoice.payload_snapshot.to_h
      receptor = payload.fetch("receptor", {}).to_h
      resumen_id = provider["idResumenComprobante"].presence || provider["idcomprobante"].presence

      if resumen_id.blank?
        raise RequestError, "Resumen CFDI aun no disponible en PAC para envio de correo"
      end

      {
        "seleccionado" => false,
        "fecha" => provider["fecha"].presence || invoice.issued_at&.iso8601,
        "uuid" => invoice.sat_uuid,
        "total" => provider["total"].presence || invoice.total.to_f,
        "receptorNombre" => provider["receptorNombre"].presence || receptor["nombre"].presence || invoice.receiver_entity&.name,
        "serie" => provider["serie"].presence || invoice.provider_response.to_h["serie"].presence || payload["serie"].presence,
        "folio" => provider["folio"].presence || invoice.provider_response.to_h["folio"].presence,
        "idResumenComprobante" => resumen_id,
        "receptorRfc" => provider["receptorRfc"].presence || receptor["rfc"],
        "satTipoDeComprobante" => provider["satTipoDeComprobante"].presence || payload["tipoDeComprobante"]
      }
    end

    def provider_summary(client:, emisor_id:)
      return @provider_summary if defined?(@provider_summary)

      response = invoice.provider_response.to_h
      summary = response["resumenComprobante"]
      @provider_summary = if summary.is_a?(Array)
        summary.find { |item| item["uuid"].to_s.casecmp(invoice.sat_uuid.to_s).zero? }.to_h
      else
        response
      end

      return @provider_summary if @provider_summary["idResumenComprobante"].present? || @provider_summary["idcomprobante"].present?

      @provider_summary = fetch_provider_summary(client: client, emisor_id: emisor_id) || @provider_summary
    end

    def fetch_provider_summary(client:, emisor_id:)
      date_from = (invoice.issued_at || invoice.created_at || Time.current).to_i - 2.days.to_i
      date_to = Time.current.to_i

      response = client.buscar_comprobantes(
        emisor_id: emisor_id,
        finicial: date_from,
        ffinal: date_to,
        uuid: invoice.sat_uuid,
        take: 10
      )

      items = response.is_a?(Hash) ? Array(response["resumenComprobante"]) : Array(response)
      found = items.find { |item| item.is_a?(Hash) && item["uuid"].to_s.casecmp(invoice.sat_uuid.to_s).zero? }
      found.to_h
    rescue Facturador::Error
      nil
    end

    def parse_response_message(response)
      return "Envio de correo PAC aceptado" if response_success_without_payload?(response)

      Facturador::ErrorMessageExtractor.call(response, fallback: response_fallback_message(response))
    end

    def response_fallback_message(response)
      return "Envio de correo PAC sin detalle (respuesta nil)" if response.nil?

      if response.is_a?(Hash)
        keys = response.keys.map(&:to_s).sort.join(", ")
        serialized = compact_json(response)
        return "Envio de correo PAC sin detalle (llaves: #{keys.presence || 'ninguna'}, payload: #{serialized})"
      end

      "Envio de correo PAC sin detalle (#{response.class}: #{compact_json(response)})"
    end

    def response_invalid?(response)
      return false if response_success_without_payload?(response)
      return true unless response.is_a?(Hash)

      return true if response["errores"].present? || response["errors"].present?
      return true if explicitly_falsey?(response["esValido"])
      return true if explicitly_falsey?(response["valido"])
      return true if explicitly_falsey?(response["success"])
      return true if explicitly_falsey?(response["ok"])

      false
    end

    def response_success_without_payload?(response)
      response == true || response.to_s.strip.casecmp("true").zero?
    end

    def explicitly_falsey?(value)
      normalized = value.to_s.strip.downcase
      value == false || normalized.in?([ "false", "0", "no" ])
    end

    def compact_json(value)
      text = JSON.generate(value)
      text.length > 500 ? "#{text[0, 500]}..." : text
    rescue StandardError
      value.to_s
    end

    def manual_trigger?
      trigger.to_s == "manual"
    end
  end
end
