require 'rails_helper'

RSpec.describe Facturador::PayloadBuilder, type: :service do
  describe '.build' do
    context 'when invoice kind is pago' do
      let(:issuer) { create(:entity, :customs_agent) }
      let(:receiver) { create(:entity, :client) }

      let(:source_invoice) do
        create(
          :invoice,
          status: 'issued',
          sat_uuid: 'UUID-SOURCE-001',
          issuer_entity: issuer,
          receiver_entity: receiver,
          currency: 'MXN',
          subtotal: 1000,
          tax_total: 160,
          total: 1160,
          provider_response: { 'serie' => 'Sin Serie', 'folio' => '123' }
        )
      end

      let!(:previous_payment) do
        create(
          :invoice_payment,
          invoice: source_invoice,
          amount: 200,
          paid_at: 2.days.ago,
          created_at: 2.days.ago,
          payment_method: '03',
          status: 'registered'
        )
      end

      let!(:current_payment) do
        create(
          :invoice_payment,
          invoice: source_invoice,
          amount: 300,
          paid_at: Time.zone.parse('2026-03-09 12:00:00'),
          created_at: Time.zone.parse('2026-03-09 12:00:00'),
          payment_method: '03',
          status: 'registered'
        )
      end

      let(:complement_invoice) do
        create(
          :invoice,
          kind: 'pago',
          status: 'draft',
          sat_uuid: nil,
          issuer_entity: issuer,
          receiver_entity: receiver,
          currency: 'MXN',
          subtotal: current_payment.amount,
          tax_total: 0,
          total: current_payment.amount,
          payload_snapshot: {
            payment: {
              payment_id: current_payment.id,
              amount: current_payment.amount.to_s,
              paid_at: current_payment.paid_at.iso8601,
              payment_method: current_payment.payment_method,
              reference: current_payment.reference
            },
            source_invoice_id: source_invoice.id,
            source_invoice_uuid: source_invoice.sat_uuid
          }
        )
      end

      before do
        create(:fiscal_profile, profileable: issuer) unless issuer.fiscal_profile.present?
        create(:fiscal_profile, profileable: receiver) unless receiver.fiscal_profile.present?
        create(:address, addressable: issuer, tipo: 'matriz') unless issuer.fiscal_address.present?
        create(:address, addressable: receiver, tipo: 'matriz') unless receiver.fiscal_address.present?
        issuer.reload
        receiver.reload

        allow(Facturador::Config).to receive(:payment_serie).and_return('PAY')
      end

      it 'builds REP payload with CP01 and complementoPago20 doctoRelacionado' do
        payload = described_class.build(complement_invoice)

        expect(payload[:tipoDeComprobante]).to eq('P')
        expect(payload[:serie]).to eq('PAY')
        expect(payload[:receptor][:usoCFDI]).to eq('CP01')

        complemento = payload.dig(:complemento, :complementoPago20)
        expect(complemento).to be_present
        expect(complemento[:version]).to eq('2.0')
        expect(complemento.dig(:totales, :montoTotalPagos)).to eq(300.0)

        pago = complemento[:pago].first
        expect(pago[:fechaPago]).to eq('2026-03-09T12:00:00')
        expect(pago[:formaDePagoP]).to eq('03')
        expect(pago[:monedaP]).to eq('MXN')
        expect(pago[:monto]).to eq(300.0)
        expect(complemento.dig(:totales, :totalTrasladosBaseIVA16)).to eq(258.62)
        expect(complemento.dig(:totales, :totalTrasladosImpuestoIVA16)).to eq(41.38)

        docto = pago[:doctoRelacionado].first
        expect(docto[:idDocumento]).to eq('UUID-SOURCE-001')
        expect(docto.key?(:serie)).to be(false)
        expect(docto[:folio]).to eq('123')
        expect(docto[:monedaDR]).to eq('MXN')
        expect(docto[:equivalenciaDR]).to eq(1)
        expect(docto[:objetoImpDR]).to eq('02')
        expect(docto[:numParcialidad]).to eq('2')
        expect(docto[:impSaldoAnt]).to eq(960.0)
        expect(docto[:impPagado]).to eq(300.0)
        expect(docto[:impSaldoInsoluto]).to eq(660.0)
        traslado_dr = docto.dig(:impuestosDR, :trasladosDR)&.first
        expect(traslado_dr).to be_present
        expect(traslado_dr[:baseDR]).to eq(258.62)
        expect(traslado_dr[:impuestoDR]).to eq('002')
        expect(traslado_dr[:tipoFactorDR]).to eq('Tasa')
        expect(traslado_dr[:tasaOCuotaDR]).to eq('0.160000')
        expect(traslado_dr[:importeDR]).to eq(41.38)
        traslado_p = pago.dig(:impuestosP, :trasladosP)&.first
        expect(traslado_p).to be_present
        expect(traslado_p[:baseP]).to eq(258.62)
        expect(traslado_p[:impuestoP]).to eq('002')
        expect(traslado_p[:tipoFactorP]).to eq('Tasa')
        expect(traslado_p[:tasaOCuotaP]).to eq('0.160000')
        expect(traslado_p[:importeP]).to eq(41.38)
        expect(docto.key?(:tipoCambioActual)).to be(false)
      end

      it 'omits serie when payment serie is not configured' do
        allow(Facturador::Config).to receive(:payment_serie).and_return(nil)

        payload = described_class.build(complement_invoice)

        expect(payload.key?(:serie)).to be(false)
      end

      it 'preserves payment metadata across retries when snapshot already stores emitted payload' do
        first_payload = described_class.build(complement_invoice)
        complement_invoice.update!(payload_snapshot: JSON.parse(first_payload.to_json))

        retry_payload = described_class.build(complement_invoice)

        retry_pago = retry_payload.dig(:complemento, :complementoPago20, :pago).first
        expect(retry_pago[:monto]).to eq(300.0)
        expect(retry_pago[:fechaPago]).to be_present
      end
    end
  end
end
