require 'rails_helper'

RSpec.describe Facturador::ErrorMessageExtractor do
  describe '.call' do
    it 'extracts error_description from oauth-like payload' do
      payload = { 'error_description' => 'invalid_grant' }

      expect(described_class.call(payload)).to eq('invalid_grant')
    end

    it 'extracts and composes codigo + mensaje from errores array' do
      payload = {
        'errores' => [
          { 'codigo' => 'FAC112', 'mensaje' => 'La serie especificada no existe' },
          { 'codigo' => 'SAT001', 'message' => 'RFC inválido' }
        ]
      }

      expect(described_class.call(payload)).to eq('FAC112: La serie especificada no existe | SAT001: RFC inválido')
    end

    it 'extracts nested model errors from hash collections' do
      payload = {
        'errors' => {
          'Receptor.Rfc' => [ 'es requerido' ],
          'Conceptos[0].ClaveProdServ' => [ 'no válido' ]
        }
      }

      expect(described_class.call(payload)).to eq('Receptor.Rfc: es requerido | Conceptos[0].ClaveProdServ: no válido')
    end

    it 'falls back to provided fallback when payload has no usable messages' do
      payload = { 'errores' => [] }

      expect(described_class.call(payload, fallback: 'Error base')).to eq('Error base')
    end
  end
end
