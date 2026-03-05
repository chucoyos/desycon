module Facturador
  class ErrorCodeResolver
    class << self
      def call(context:, provider_payload: nil, message: nil, exception: nil)
        new(context: context, provider_payload: provider_payload, message: message, exception: exception).call
      end
    end

    def initialize(context:, provider_payload:, message:, exception:)
      @context = context.to_s.upcase.presence || "GENERAL"
      @provider_payload = provider_payload
      @message = message.to_s
      @exception = exception
    end

    def call
      code = provider_error_code
      return "#{prefix}_PROVIDER_#{sanitize(code)}" if code.present?
      return "#{prefix}_PROVIDER_ERROR" if provider_error_payload?
      return "#{prefix}_AUTH_ERROR" if auth_error?
      return "#{prefix}_VALIDATION_ERROR" if validation_error?
      return "#{prefix}_TIMEOUT_ERROR" if timeout_error?
      return "#{prefix}_NETWORK_ERROR" if network_error?

      "#{prefix}_ERROR"
    end

    private

    attr_reader :context, :provider_payload, :message, :exception

    def prefix
      "FACTURADOR_#{context}"
    end

    def provider_error_code
      entries = error_entries(provider_payload)

      entries.each do |entry|
        next unless entry.is_a?(Hash)

        item = entry.transform_keys(&:to_s)
        found = item["codigo"].presence || item["code"].presence
        return found if found.present?
      end

      nil
    end

    def provider_error_payload?
      return false unless provider_payload.is_a?(Hash)

      payload = provider_payload.transform_keys(&:to_s)
      payload["errores"].present? || payload["errors"].present? || payload["descripcion"].present? || payload["message"].present?
    end

    def error_entries(payload)
      return [] unless payload.is_a?(Hash)

      data = payload.transform_keys(&:to_s)
      entries = []
      entries.concat(normalize_to_array(data["errores"]))
      entries.concat(normalize_to_array(data["errors"]))
      entries
    end

    def normalize_to_array(value)
      case value
      when nil
        []
      when Array
        value
      else
        [ value ]
      end
    end

    def auth_error?
      exception.is_a?(AuthenticationError) || message.match?(/\b401\b|unauthoriz|invalid_grant|token/i)
    end

    def validation_error?
      exception.is_a?(ValidationError)
    end

    def timeout_error?
      message.match?(/timeout|timed out|execution expired/i)
    end

    def network_error?
      message.match?(/econnrefused|socketerror|getaddrinfo|name or service not known|network/i)
    end

    def sanitize(value)
      value.to_s.upcase.gsub(/[^A-Z0-9]+/, "_").gsub(/\A_|_\z/, "")
    end
  end
end
