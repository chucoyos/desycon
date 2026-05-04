module Facturador
  class RequestError < Error
    attr_reader :status_code,
      :provider_payload,
      :response_body,
      :response_headers,
      :request_method,
      :request_path,
      :request_host,
      :request_query,
      :request_id

    def initialize(
      message = nil,
      status_code: nil,
      provider_payload: nil,
      response_body: nil,
      response_headers: nil,
      request_method: nil,
      request_path: nil,
      request_host: nil,
      request_query: nil,
      request_id: nil
    )
      super(message)
      @status_code = status_code
      @provider_payload = provider_payload
      @response_body = response_body
      @response_headers = response_headers
      @request_method = request_method
      @request_path = request_path
      @request_host = request_host
      @request_query = request_query
      @request_id = request_id
    end

    def to_h
      {
        status_code: status_code,
        request_id: request_id,
        request_method: request_method,
        request_path: request_path,
        request_host: request_host,
        request_query: request_query,
        provider_payload: provider_payload,
        response_body: response_body,
        response_headers: response_headers
      }.compact
    end
  end
end
