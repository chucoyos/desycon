require 'rails_helper'

RSpec.describe Facturador::PayloadBuilder, type: :service do
  describe '.build' do
    context 'when invoice kind is ingreso' do
      let(:issuer) { create(:entity, :customs_agent) }
      let(:receiver) { create(:entity, :client) }

      before do
        create(:fiscal_profile, profileable: issuer) unless issuer.fiscal_profile.present?
        create(:fiscal_profile, profileable: receiver) unless receiver.fiscal_profile.present?
        create(:address, addressable: issuer, tipo: 'matriz') unless issuer.fiscal_address.present?
        create(:address, addressable: receiver, tipo: 'matriz') unless receiver.fiscal_address.present?
        issuer.reload
        receiver.reload
        allow(Facturador::Config).to receive(:environment).and_return('production')
      end

      it 'includes container and blhouse in separate lines when both exist' do
        bl_service = create(:bl_house_line_service)
        invoice = create(
          :invoice,
          kind: 'ingreso',
          invoiceable: bl_service,
          issuer_entity: issuer,
          receiver_entity: receiver
        )

        payload = described_class.build(invoice)

        expect(payload[:descripcionFacturador]).to eq('Factura')
        concepto_descripcion = payload.dig(:conceptos, 0, :descripcion)
        expect(concepto_descripcion).to include("Contenedor #{bl_service.bl_house_line.container.number}")
        expect(concepto_descripcion).to include("BlHouse #{bl_service.bl_house_line.blhouse.delete('-')}")
        expect(concepto_descripcion).not_to include('|')
        expect(concepto_descripcion).not_to include(':')
      end

      it 'omits receiver correo when fiscal address email is blank' do
        receiver.fiscal_address.update!(email: nil)

        invoice = create(
          :invoice,
          kind: 'ingreso',
          invoiceable: nil,
          issuer_entity: issuer,
          receiver_entity: receiver
        )
        create(:invoice_line_item, invoice: invoice)

        payload = described_class.build(invoice)

        expect(payload.dig(:receptor, :direccion, :correo)).to be_nil
        expect(payload.dig(:receptor, :direccion).key?(:correo)).to be(false)
      end

      it 'omits container and blhouse labels when values do not exist' do
        invoice = create(
          :invoice,
          kind: 'ingreso',
          invoiceable: nil,
          issuer_entity: issuer,
          receiver_entity: receiver
        )
        create(:invoice_line_item, invoice: invoice)

        payload = described_class.build(invoice)

        expect(payload[:descripcionFacturador]).to eq('Factura')
        expect(payload[:descripcionFacturador]).not_to include('Contenedor:')
        expect(payload[:descripcionFacturador]).not_to include('BlHouse:')
      end

      it 'uses mapped serie for importacion with destination port Manzanillo (container service)' do
        allow(Facturador::Config).to receive(:serie).and_return('GLOBAL')

        destination_port = create(:port, :manzanillo)
        voyage = create(:voyage, destination_port: destination_port)
        container = create(
          :container,
          tipo_maniobra: 'importacion',
          voyage: voyage,
          recinto: 'CONTECON',
          almacen: 'SSA'
        )
        container_service = create(:container_service, container: container)
        invoice = create(
          :invoice,
          kind: 'ingreso',
          invoiceable: container_service,
          issuer_entity: issuer,
          receiver_entity: receiver
        )

        payload = described_class.build(invoice)

        expect(payload[:serie]).to eq('GMZO')
      end

      it 'uses mapped serie for importacion with destination port Altamira (bl house line service)' do
        allow(Facturador::Config).to receive(:serie).and_return('GLOBAL')

        destination_port = create(:port, name: 'Altamira', code: 'MXATM', country_code: 'MX')
        voyage = create(:voyage, destination_port: destination_port)
        container = create(
          :container,
          tipo_maniobra: 'importacion',
          voyage: voyage,
          recinto: 'ATP',
          almacen: 'SERVICIOS CARRIER INTERPUERTOS'
        )
        bl_house_line = create(:bl_house_line, container: container)
        bl_service = create(:bl_house_line_service, bl_house_line: bl_house_line)
        invoice = create(
          :invoice,
          kind: 'ingreso',
          invoiceable: bl_service,
          issuer_entity: issuer,
          receiver_entity: receiver
        )

        payload = described_class.build(invoice)

        expect(payload[:serie]).to eq('GATM')
      end

      it 'uses mapped serie for importacion with destination port Veracruz' do
        allow(Facturador::Config).to receive(:serie).and_return('GLOBAL')

        destination_port = create(:port, :veracruz)
        voyage = create(:voyage, destination_port: destination_port)
        container = create(
          :container,
          tipo_maniobra: 'importacion',
          voyage: voyage,
          recinto: 'ICAVE',
          almacen: 'CICE'
        )
        container_service = create(:container_service, container: container)
        invoice = create(
          :invoice,
          kind: 'ingreso',
          invoiceable: container_service,
          issuer_entity: issuer,
          receiver_entity: receiver
        )

        payload = described_class.build(invoice)

        expect(payload[:serie]).to eq('GVRZ')
      end

      it 'uses mapped serie for importacion with destination port Lazaro Cardenas' do
        allow(Facturador::Config).to receive(:serie).and_return('GLOBAL')

        destination_port = create(:port, name: 'Lazaro Cardenas', code: 'MXLZC', country_code: 'MX')
        voyage = create(:voyage, destination_port: destination_port)
        container = create(
          :container,
          tipo_maniobra: 'importacion',
          voyage: voyage,
          recinto: 'LCTPC TERMINAL PORTUARIA DE CONTENEDORES (HPH)',
          almacen: 'UTTSA RECINTO 173'
        )
        container_service = create(:container_service, container: container)
        invoice = create(
          :invoice,
          kind: 'ingreso',
          invoiceable: container_service,
          issuer_entity: issuer,
          receiver_entity: receiver
        )

        payload = described_class.build(invoice)

        expect(payload[:serie]).to eq('GLZC')
      end

      it 'falls back to global serie for importacion with unmapped destination port' do
        allow(Facturador::Config).to receive(:serie).and_return('GLOBAL')

        destination_port = create(:port, :los_angeles)
        voyage = create(:voyage, destination_port: destination_port)
        container = create(:container, tipo_maniobra: 'importacion', voyage: voyage)
        container_service = create(:container_service, container: container)
        invoice = create(
          :invoice,
          kind: 'ingreso',
          invoiceable: container_service,
          issuer_entity: issuer,
          receiver_entity: receiver
        )

        payload = described_class.build(invoice)

        expect(payload[:serie]).to eq('GLOBAL')
      end

      it 'keeps global serie for exportacion' do
        allow(Facturador::Config).to receive(:serie).and_return('GLOBAL')

        destination_port = create(:port, :manzanillo)
        voyage = create(:voyage, destination_port: destination_port)
        container = create(:container, tipo_maniobra: 'exportacion', voyage: voyage)
        container_service = create(:container_service, container: container)
        invoice = create(
          :invoice,
          kind: 'ingreso',
          invoiceable: container_service,
          issuer_entity: issuer,
          receiver_entity: receiver
        )

        payload = described_class.build(invoice)

        expect(payload[:serie]).to eq('GLOBAL')
      end

      it 'falls back to global serie when invoiceable has no container context' do
        allow(Facturador::Config).to receive(:serie).and_return('GLOBAL')

        invoice = create(
          :invoice,
          kind: 'ingreso',
          invoiceable: nil,
          issuer_entity: issuer,
          receiver_entity: receiver
        )
        create(:invoice_line_item, invoice: invoice)

        payload = described_class.build(invoice)

        expect(payload[:serie]).to eq('GLOBAL')
      end

      it 'uses mapped serie for importacion even when global serie is nil' do
        allow(Facturador::Config).to receive(:serie).and_return(nil)

        destination_port = create(:port, :manzanillo)
        voyage = create(:voyage, destination_port: destination_port)
        container = create(
          :container,
          tipo_maniobra: 'importacion',
          voyage: voyage,
          recinto: 'CONTECON',
          almacen: 'SSA'
        )
        container_service = create(:container_service, container: container)
        invoice = create(
          :invoice,
          kind: 'ingreso',
          invoiceable: container_service,
          issuer_entity: issuer,
          receiver_entity: receiver
        )

        payload = described_class.build(invoice)

        expect(payload[:serie]).to eq('GMZO')
      end

      it 'uses manual serie override from payload snapshot for manual invoices' do
        allow(Facturador::Config).to receive(:serie).and_return('GLOBAL')

        invoice = create(
          :invoice,
          kind: 'ingreso',
          invoiceable: nil,
          issuer_entity: issuer,
          receiver_entity: receiver,
          payload_snapshot: {
            manual: true,
            serie_override: 'MZ'
          }
        )
        create(:invoice_line_item, invoice: invoice)

        payload = described_class.build(invoice)

        expect(payload[:serie]).to eq('MZ')
      end

      it 'uses simplified sandbox mapping for importacion destination ports' do
        allow(Facturador::Config).to receive(:environment).and_return('sandbox')
        allow(Facturador::Config).to receive(:serie).and_return('GLOBAL')

        test_cases = [
          { code: 'MXZLO', recinto: 'CONTECON', almacen: 'SSA', expected_serie: 'MZ' },
          { code: 'MXLZC', recinto: 'LCTPC TERMINAL PORTUARIA DE CONTENEDORES (HPH)', almacen: 'UTTSA RECINTO 173', expected_serie: 'A' },
          { code: 'MXVER', recinto: 'ICAVE', almacen: 'CICE', expected_serie: 'B' },
          { code: 'MXATM', recinto: 'ATP', almacen: 'SERVICIOS CARRIER INTERPUERTOS', expected_serie: 'C' }
        ]

        test_cases.each do |tc|
          destination_port = create(:port, name: "Port #{tc[:code]}", code: tc[:code], country_code: 'MX')
          voyage = create(:voyage, destination_port: destination_port)
          container = create(
            :container,
            tipo_maniobra: 'importacion',
            voyage: voyage,
            recinto: tc[:recinto],
            almacen: tc[:almacen]
          )
          container_service = create(:container_service, container: container)
          invoice = create(
            :invoice,
            kind: 'ingreso',
            invoiceable: container_service,
            issuer_entity: issuer,
            receiver_entity: receiver
          )

          payload = described_class.build(invoice)

          expect(payload[:serie]).to eq(tc[:expected_serie])
        end
      end
    end

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

      it 'builds grouped REP payload with multiple doctoRelacionado entries' do
        second_source_invoice = create(
          :invoice,
          status: 'issued',
          sat_uuid: 'UUID-SOURCE-002',
          issuer_entity: issuer,
          receiver_entity: receiver,
          currency: 'MXN',
          subtotal: 1000,
          tax_total: 160,
          total: 1160,
          provider_response: { 'folio' => '456' }
        )

        second_payment = create(
          :invoice_payment,
          invoice: second_source_invoice,
          amount: 200,
          paid_at: current_payment.paid_at,
          created_at: current_payment.created_at,
          payment_method: '03',
          status: 'registered'
        )

        grouped_complement = create(
          :invoice,
          kind: 'pago',
          status: 'draft',
          sat_uuid: nil,
          issuer_entity: issuer,
          receiver_entity: receiver,
          currency: 'MXN',
          subtotal: 500,
          tax_total: 0,
          total: 500,
          payload_snapshot: {
            metadataInterna: {
              grouped_payments: [
                {
                  payment_id: current_payment.id,
                  source_invoice_id: source_invoice.id,
                  source_invoice_uuid: source_invoice.sat_uuid,
                  amount: current_payment.amount.to_s,
                  paid_at: current_payment.paid_at.iso8601,
                  payment_method: current_payment.payment_method,
                  currency: current_payment.currency
                },
                {
                  payment_id: second_payment.id,
                  source_invoice_id: second_source_invoice.id,
                  source_invoice_uuid: second_source_invoice.sat_uuid,
                  amount: second_payment.amount.to_s,
                  paid_at: second_payment.paid_at.iso8601,
                  payment_method: second_payment.payment_method,
                  currency: second_payment.currency
                }
              ]
            }
          }
        )

        payload = described_class.build(grouped_complement)

        complemento = payload.dig(:complemento, :complementoPago20)
        expect(complemento).to be_present
        expect(complemento.dig(:totales, :montoTotalPagos)).to eq(500.0)

        pago = complemento[:pago].first
        expect(pago[:monto]).to eq(500.0)
        expect(pago[:doctoRelacionado].size).to eq(2)
        expect(pago[:doctoRelacionado].map { |docto| docto[:idDocumento] }).to match_array([ 'UUID-SOURCE-001', 'UUID-SOURCE-002' ])
      end

      it 'raises when grouped REP includes mixed tax rates' do
        lower_rate_invoice = create(
          :invoice,
          status: 'issued',
          sat_uuid: 'UUID-SOURCE-003',
          issuer_entity: issuer,
          receiver_entity: receiver,
          currency: 'MXN',
          subtotal: 1000,
          tax_total: 80,
          total: 1080,
          provider_response: { 'folio' => '789' }
        )

        lower_rate_payment = create(
          :invoice_payment,
          invoice: lower_rate_invoice,
          amount: 200,
          paid_at: current_payment.paid_at,
          created_at: current_payment.created_at,
          payment_method: '03',
          status: 'registered'
        )

        grouped_complement = create(
          :invoice,
          kind: 'pago',
          status: 'draft',
          sat_uuid: nil,
          issuer_entity: issuer,
          receiver_entity: receiver,
          currency: 'MXN',
          subtotal: 500,
          tax_total: 0,
          total: 500,
          payload_snapshot: {
            metadataInterna: {
              grouped_payments: [
                {
                  payment_id: current_payment.id,
                  source_invoice_id: source_invoice.id,
                  source_invoice_uuid: source_invoice.sat_uuid,
                  amount: current_payment.amount.to_s,
                  paid_at: current_payment.paid_at.iso8601,
                  payment_method: current_payment.payment_method,
                  currency: current_payment.currency
                },
                {
                  payment_id: lower_rate_payment.id,
                  source_invoice_id: lower_rate_invoice.id,
                  source_invoice_uuid: lower_rate_invoice.sat_uuid,
                  amount: lower_rate_payment.amount.to_s,
                  paid_at: lower_rate_payment.paid_at.iso8601,
                  payment_method: lower_rate_payment.payment_method,
                  currency: lower_rate_payment.currency
                }
              ]
            }
          }
        )

        expect do
          described_class.build(grouped_complement)
        end.to raise_error(Facturador::ValidationError, /mixed tax rates/)
      end
    end
  end
end
