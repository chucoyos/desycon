require 'rails_helper'

RSpec.describe Facturador::RequestError do
  describe '#to_h' do
    it 'exposes structured diagnostics for provider failures' do
      error = described_class.new(
        '500: provider error',
        status_code: 500,
        provider_payload: { 'errores' => [ { 'codigo' => 'FAC500' } ] },
        response_body: '{"errores":[{"codigo":"FAC500"}]}',
        response_headers: { 'x-request-id' => [ 'abc-123' ] },
        request_method: 'POST',
        request_path: '/api/v1/emisores/273059/comprobantes',
        request_host: 'emision-api.facturador.com',
        request_query: 'emitir=true',
        request_id: 'abc-123'
      )

      expect(error.to_h).to include(
        status_code: 500,
        request_id: 'abc-123',
        request_method: 'POST',
        request_path: '/api/v1/emisores/273059/comprobantes',
        request_host: 'emision-api.facturador.com',
        request_query: 'emitir=true'
      )
      expect(error.to_h[:provider_payload]).to eq({ 'errores' => [ { 'codigo' => 'FAC500' } ] })
    end
  end
end
