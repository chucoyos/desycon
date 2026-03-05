require 'rails_helper'

RSpec.describe Facturador::ErrorCodeResolver do
  describe '.call' do
    it 'maps provider code from errores array' do
      payload = { 'errores' => [ { 'codigo' => 'FAC112', 'mensaje' => 'Serie inválida' } ] }

      code = described_class.call(context: :issue, provider_payload: payload)

      expect(code).to eq('FACTURADOR_ISSUE_PROVIDER_FAC112')
    end

    it 'maps provider payload without explicit code' do
      payload = { 'errores' => [ { 'mensaje' => 'RFC inválido' } ] }

      code = described_class.call(context: :issue, provider_payload: payload)

      expect(code).to eq('FACTURADOR_ISSUE_PROVIDER_ERROR')
    end

    it 'maps timeout request errors' do
      error = Facturador::RequestError.new('execution expired')

      code = described_class.call(context: :issue, exception: error, message: error.message)

      expect(code).to eq('FACTURADOR_ISSUE_TIMEOUT_ERROR')
    end

    it 'maps auth errors' do
      error = Facturador::AuthenticationError.new('invalid_grant')

      code = described_class.call(context: :cancel, exception: error, message: error.message)

      expect(code).to eq('FACTURADOR_CANCEL_AUTH_ERROR')
    end
  end
end
