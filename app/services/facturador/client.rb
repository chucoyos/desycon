require "net/http"
require "json"

module Facturador
  class Client
    TOKEN_PATH = "/connect/token".freeze
    USER_INFO_PATH = "/connect/userinfo".freeze
    COMPROBANTES_PATH = "/businessEmision/api/v1/emisores/%<emisor_id>s/comprobantes".freeze
    COMPROBANTES_LIST_PATH = "/BusinessEmision/api/v1/emisores/%<emisor_id>s/comprobantes".freeze
    COMPROBANTE_BY_UUID_PATH = "/businessEmision/api/v1/emisores/%<emisor_id>s/comprobantes/%<uuid>s".freeze
    DESCARGA_COMPROBANTE_PATH = "/businessEmision/api/v1/emisores/%<emisor_id>s/descargacomprobantes/%<uuid>s".freeze
    PDF_GENERATE_PATH = "/businessEmision/api/v1/emisores/%<emisor_id>s/pdfs/%<uuid>s".freeze
    PDF_URL_PATH = "/businessEmision/api/v1/emisores/%<emisor_id>s/comprobantes/%<uuid>s/pdf".freeze

    def initialize(access_token: nil)
      Config.validate!
      @access_token = access_token
    end

    def token
      form_body = URI.encode_www_form(
        grant_type: "password",
        scope: "offline_access openid APINegocios",
        username: Config.username,
        password: Config.password_md5,
        client_id: Config.client_id,
        client_secret: Config.client_secret,
        es_md5: true
      )

      post_form(Config.auth_base_url, TOKEN_PATH, form_body)
    end

    def refresh_token(refresh_token)
      form_body = URI.encode_www_form(
        grant_type: "refresh_token",
        refresh_token: refresh_token,
        client_id: Config.client_id,
        client_secret: Config.client_secret
      )

      post_form(Config.auth_base_url, TOKEN_PATH, form_body)
    end

    def user_info
      get_json(Config.auth_base_url, USER_INFO_PATH)
    end

    def emitir_comprobante(emisor_id:, payload:, emitir: true)
      path = format(COMPROBANTES_PATH, emisor_id: emisor_id)
      post_json(Config.business_base_url, path, payload, query: { emitir: emitir })
    end

    def buscar_comprobantes(emisor_id:, finicial:, ffinal:, uuid: nil, skip: 0, take: 10)
      path = format(COMPROBANTES_LIST_PATH, emisor_id: emisor_id)
      query = {
        finicial: finicial,
        ffinal: ffinal,
        nocomprobante: 0,
        tipoConfirmacionId: 0,
        skip: skip,
        take: take
      }
      query[:uuid] = uuid if uuid.present?

      get_json_with_query(Config.business_base_url, path, query)
    end

    def cancelar_comprobante(emisor_id:, uuid:, motivo:, folio_sustitucion: nil)
      path = format(COMPROBANTE_BY_UUID_PATH, emisor_id: emisor_id, uuid: uuid)
      body = { motivo: motivo }
      body[:folioSustitucion] = folio_sustitucion if folio_sustitucion.present?
      delete_json(Config.business_base_url, path, body)
    end

    def descargar_xml(emisor_id:, uuid:)
      path = format(DESCARGA_COMPROBANTE_PATH, emisor_id: emisor_id, uuid: uuid)
      get_raw(Config.business_base_url, path, query: { tipoContenido: "xml" })
    end

    def generar_pdf(emisor_id:, uuid:)
      path = format(PDF_GENERATE_PATH, emisor_id: emisor_id, uuid: uuid)
      post_json(Config.business_base_url, path, {})
    end

    def obtener_pdf_url(emisor_id:, uuid:)
      path = format(PDF_URL_PATH, emisor_id: emisor_id, uuid: uuid)
      normalize_pdf_url(get_raw(Config.business_base_url, path))
    end

    private

    attr_reader :access_token

    def post_form(base_url, path, body)
      uri = URI.join(base_url, path)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/x-www-form-urlencoded"
      request["Accept"] = "application/json"
      request["Authorization"] = "Bearer #{access_token}" if access_token.present?
      request.body = body

      execute_request(uri, request)
    end

    def post_json(base_url, path, body, query: {})
      uri = URI.join(base_url, path)
      uri.query = URI.encode_www_form(query) if query.present?

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request["Authorization"] = "Bearer #{access_token}" if access_token.present?
      request.body = body.to_json

      execute_request(uri, request)
    end

    def get_json(base_url, path)
      uri = URI.join(base_url, path)
      request = Net::HTTP::Get.new(uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request["Authorization"] = "Bearer #{access_token}" if access_token.present?

      execute_request(uri, request)
    end

    def get_json_with_query(base_url, path, query)
      uri = URI.join(base_url, path)
      uri.query = URI.encode_www_form(query)

      request = Net::HTTP::Get.new(uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request["Authorization"] = "Bearer #{access_token}" if access_token.present?

      execute_request(uri, request)
    end

    def get_raw(base_url, path, query: {})
      uri = URI.join(base_url, path)
      uri.query = URI.encode_www_form(query) if query.present?

      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "*/*"
      request["Authorization"] = "Bearer #{access_token}" if access_token.present?

      execute_raw_request(uri, request)
    end

    def delete_json(base_url, path, body)
      uri = URI.join(base_url, path)
      request = Net::HTTP::Delete.new(uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request["Authorization"] = "Bearer #{access_token}" if access_token.present?
      request.body = body.to_json

      execute_request(uri, request)
    end

    def execute_request(uri, request)
      response = perform_request(uri, request)
      parse_json_response(response)
    rescue Timeout::Error, Errno::ECONNREFUSED, SocketError => e
      raise RequestError, e.message
    end

    def execute_raw_request(uri, request)
      response = perform_request(uri, request)
      return response.body if response.is_a?(Net::HTTPSuccess)

      raise_for_unsuccessful_response(response)
    rescue Timeout::Error, Errno::ECONNREFUSED, SocketError => e
      raise RequestError, e.message
    end

    def perform_request(uri, request)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      response
    end

    def parse_json_response(response)
      body = response.body.presence || "{}"
      parsed = JSON.parse(body)

      return parsed if response.is_a?(Net::HTTPSuccess)

      message = parsed["error_description"] || parsed["message"] || parsed["descripcion"]
      if message.blank? && parsed["errores"].is_a?(Array)
        details = parsed["errores"].filter_map do |item|
          item["mensaje"] || item["message"] || item["descripcion"]
        end
        message = details.join(" | ") if details.any?
      end

      message = body if message.blank? && body.present?
      raise_with_message(response: response, message: message.presence || response.message)
    rescue JSON::ParserError
      if response.is_a?(Net::HTTPSuccess)
        raise RequestError, "Invalid JSON response from Facturador"
      end

      raw_message = response.body.to_s.strip
      raise_with_message(response: response, message: raw_message.presence || response.message)
    end

    def raise_for_unsuccessful_response(response)
      message = response.body.to_s.strip
      if message.present? && message.start_with?("{")
        parsed = JSON.parse(message)
        message = parsed["error_description"] || parsed["message"] || parsed["descripcion"] || message
      end

      raise_with_message(response: response, message: message.presence || response.message)
    rescue JSON::ParserError
      raise_with_message(response: response, message: response.message)
    end

    def raise_with_message(response:, message:)
      if response.code.to_i == 401
        raise AuthenticationError, message
      end

      raise RequestError, "#{response.code}: #{message}"
    end

    def normalize_pdf_url(raw_url)
      value = raw_url.to_s.strip
      return value if value.blank?

      3.times do
        break unless value.start_with?("\"") && value.end_with?("\"")

        parsed = JSON.parse(value)
        break unless parsed.is_a?(String)

        value = parsed.strip
      rescue JSON::ParserError
        break
      end

      value
    end
  end
end
