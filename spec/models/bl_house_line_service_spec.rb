require 'rails_helper'

RSpec.describe BlHouseLineService, type: :model do
  describe 'facturador auto issue callback' do
    it 'does not attempt auto issue when feature is disabled' do
      allow(Facturador::Config).to receive(:enabled?).and_return(false)

      expect(Facturador::AutoIssueService).not_to receive(:call)
      create(:bl_house_line_service)
    end

    it 'does not attempt auto issue for manually created services' do
      allow(Facturador::Config).to receive(:enabled?).and_return(true)
      allow(Facturador::Config).to receive(:auto_issue_enabled?).and_return(true)

      expect(Facturador::AutoIssueService).not_to receive(:call)
      create(:bl_house_line_service)
    end

    it 'attempts auto issue for services created from status transition flow' do
      allow(Facturador::Config).to receive(:enabled?).and_return(true)
      allow(Facturador::Config).to receive(:auto_issue_enabled?).and_return(true)

      expect(Facturador::AutoIssueService).to receive(:call)
      create(:bl_house_line_service, creation_origin: BlHouseLineService::AUTO_ISSUE_ORIGIN_STATUS_TRANSITION)
    end
  end

  describe 'restricciones de servicios facturados' do
    it 'no permite editar un servicio facturado' do
      service = create(:bl_house_line_service, :facturado)

      expect(service.update(observaciones: 'Cambio no permitido')).to be(false)
      expect(service.errors[:base]).to include('No se puede editar un servicio facturado.')
    end

    it 'no permite eliminar un servicio facturado' do
      service = create(:bl_house_line_service, :facturado)

      expect(service.destroy).to be(false)
      expect(service.errors[:base]).to include('No se puede eliminar un servicio facturado.')
      expect(described_class.exists?(service.id)).to be(true)
    end

    it 'bloquea edicion y eliminacion cuando existe CFDI emitido asociado' do
      service = create(:bl_house_line_service, factura: nil)
      create(:invoice, invoiceable: service, status: 'issued')

      expect(service.update(observaciones: 'Cambio no permitido')).to be(false)
      expect(service.errors[:base]).to include('No se puede editar un servicio facturado.')

      expect(service.destroy).to be(false)
      expect(service.errors[:base]).to include('No se puede eliminar un servicio facturado.')
    end

    it 'bloquea edicion y eliminacion cuando existe CFDI emitido por facturacion agrupada' do
      service = create(:bl_house_line_service, factura: nil)
      invoice = create(:invoice, invoiceable: nil, status: 'issued')
      create(:invoice_service_link, invoice: invoice, serviceable: service)

      expect(service.update(observaciones: 'Cambio no permitido')).to be(false)
      expect(service.errors[:base]).to include('No se puede editar un servicio facturado.')

      expect(service.destroy).to be(false)
      expect(service.errors[:base]).to include('No se puede eliminar un servicio facturado.')
    end
  end

  describe 'monto por servicio' do
    it 'usa cantidad 1 por defecto y monto del catalogo al crear' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', amount: 180.25)

      service = create(:bl_house_line_service, service_catalog: catalog, amount: nil)

      expect(service.quantity).to eq(1)
      expect(service.amount).to eq(180.25)
    end

    it 'calcula monto por cantidad para servicios estandar' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', code: 'BL-ASIG', amount: 150)

      service = create(:bl_house_line_service, service_catalog: catalog, quantity: 3, amount: nil)

      expect(service.amount).to eq(BigDecimal('450.0'))
    end

    it 'recalcula monto al cambiar cantidad en servicios estandar' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', code: 'BL-ASIG', amount: 120)
      service = create(:bl_house_line_service, service_catalog: catalog, quantity: 1, amount: nil)

      service.update!(quantity: 4)

      expect(service.reload.amount).to eq(BigDecimal('480.0'))
    end

    it 'permite conservar un monto distinto al catalogo' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', amount: 95)
      service = create(:bl_house_line_service, service_catalog: catalog, amount: 210.4)

      catalog.update!(amount: 300)
      service.reload

      expect(service.amount).to eq(210.4)
    end

    it 'calcula ENTCAM por formula aunque llegue monto manual' do
      catalog = create(
        :service_catalog,
        applies_to: 'bl_house_line',
        code: 'BL-ENTCAM',
        amount: 126,
        currency: 'MXN'
      )
      bl_house_line = create(:bl_house_line, peso: 13_200, volumen: 8.1)

      service = create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, amount: 1)

      expect(service.amount).to eq(BigDecimal('1764'))
    end

    it 'calcula ALMA por formula aunque llegue monto manual cuando hay dias cobrables' do
      catalog = create(
        :service_catalog,
        applies_to: 'bl_house_line',
        code: 'BL-ALMA',
        amount: 170.91,
        currency: 'MXN'
      )
      container = create(:container, fecha_desconsolidacion: Date.new(2026, 3, 20))
      bl_house_line = create(
        :bl_house_line,
        container: container,
        peso: 12_000,
        volumen: 10,
        fecha_despacho: Time.zone.local(2026, 3, 30, 9, 0, 0)
      )

      service = create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, amount: 1)

      expect(service.amount).to eq(BigDecimal('6048'))
    end

    it 'bloquea alta manual de BL-ALMA durante periodo de gracia' do
      catalog = create(
        :service_catalog,
        applies_to: 'bl_house_line',
        code: 'BL-ALMA',
        amount: 170.91,
        currency: 'MXN'
      )
      container = create(:container, fecha_desconsolidacion: Date.new(2026, 3, 20))
      bl_house_line = create(
        :bl_house_line,
        container: container,
        peso: 12_000,
        volumen: 10,
        fecha_despacho: Time.zone.local(2026, 3, 26, 9, 0, 0)
      )

      service = build(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, amount: 1)

      expect(service).not_to be_valid
      expect(service.errors[:base]).to include('No se puede crear BL-ALMA durante periodo de gracia.')
    end

    it 'aplica formula y gracia al almacenaje Lázaro' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', code: 'BL-ALM-LZC', amount: 100)
      port = create(:port, code: 'MXLZC', country_code: 'MX')
      voyage = create(:voyage, destination_port: port)
      container = create(:container, voyage: voyage, fecha_desconsolidacion: Date.new(2026, 3, 20))
      line = create(:bl_house_line, container: container, peso: 12_000, volumen: 10, fecha_despacho: Time.zone.local(2026, 3, 27))
      service = create(:bl_house_line_service, bl_house_line: line, service_catalog: catalog, amount: 1)
      expect(service.amount).to eq(1200)

      line.update!(fecha_despacho: Time.zone.local(2026, 3, 26))
      within_grace = build(:bl_house_line_service, bl_house_line: line, service_catalog: catalog)
      expect(within_grace).not_to be_valid
      expect(within_grace.errors[:base]).to include('No se puede crear BL-ALM-LZC durante periodo de gracia.')
    end

    it 'calcula BL-PREVIO por formula aunque llegue monto manual' do
      catalog = create(
        :service_catalog,
        applies_to: 'bl_house_line',
        code: 'BL-PREVIO',
        amount: 126,
        currency: 'MXN'
      )
      bl_house_line = create(:bl_house_line, peso: 13_200, volumen: 8.1)

      service = create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, amount: 1)

      expect(service.amount).to eq(BigDecimal('1764'))
    end

    it 'calcula BL-PRV-LZC por formula con minimo de 10 unidades' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', code: 'BL-PRV-LZC', amount: 679, currency: 'MXN')
      small = create(:bl_house_line, peso: 3_000, volumen: 4.2)
      large = create(:bl_house_line, peso: 13_200, volumen: 8.1)

      expect(create(:bl_house_line_service, bl_house_line: small, service_catalog: catalog, amount: 1).amount).to eq(BigDecimal('6790'))
      expect(create(:bl_house_line_service, bl_house_line: large, service_catalog: catalog, amount: 1).amount).to eq(BigDecimal('9506'))
    end

    it 'calcula BL-REAC-LZC por formula con minimo de 7 unidades' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', code: 'BL-REAC-LZC', amount: 600, currency: 'MXN')
      small = create(:bl_house_line, peso: 3_000, volumen: 4.2)
      large = create(:bl_house_line, peso: 13_200, volumen: 8.1)

      expect(create(:bl_house_line_service, bl_house_line: small, service_catalog: catalog, amount: 1).amount).to eq(BigDecimal('4200'))
      expect(create(:bl_house_line_service, bl_house_line: large, service_catalog: catalog, amount: 1).amount).to eq(BigDecimal('8400'))
    end

    it 'calcula BL-POSC-LZC por formula con minimo de 10 unidades' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', code: 'BL-POSC-LZC', amount: 679, currency: 'MXN')
      small = create(:bl_house_line, peso: 3_000, volumen: 4.2)
      large = create(:bl_house_line, peso: 13_200, volumen: 8.1)

      expect(create(:bl_house_line_service, bl_house_line: small, service_catalog: catalog, amount: 1).amount).to eq(BigDecimal('6790'))
      expect(create(:bl_house_line_service, bl_house_line: large, service_catalog: catalog, amount: 1).amount).to eq(BigDecimal('9506'))
    end

    it 'calcula BL-MF-LZC por formula con minimo de 10 unidades' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', code: 'BL-MF-LZC', amount: 626, currency: 'MXN')
      small = create(:bl_house_line, peso: 3_000, volumen: 4.2)
      large = create(:bl_house_line, peso: 13_200, volumen: 8.1)

      expect(create(:bl_house_line_service, bl_house_line: small, service_catalog: catalog, amount: 1).amount).to eq(BigDecimal('6260'))
      expect(create(:bl_house_line_service, bl_house_line: large, service_catalog: catalog, amount: 1).amount).to eq(BigDecimal('8764'))
    end

    it 'calcula BL-PA-LZC como tarifa fija por cantidad' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', code: 'BL-PA-LZC', amount: 1300, currency: 'MXN')
      bl_house_line = create(:bl_house_line)

      expect(create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, quantity: 1, amount: nil).amount).to eq(BigDecimal('1300'))
      expect(create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, quantity: 3, amount: nil).amount).to eq(BigDecimal('3900'))
    end

    it 'calcula BL-ETQ-LZC como tarifa por etiqueta sin minimo' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', code: 'BL-ETQ-LZC', amount: 10, currency: 'MXN')
      bl_house_line = create(:bl_house_line)

      expect(create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, quantity: 1, amount: nil).amount).to eq(BigDecimal('10'))
      expect(create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, quantity: 25, amount: nil).amount).to eq(BigDecimal('250'))
    end

    it 'calcula BL-PER-LZC como tarifa por dia' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', code: 'BL-PER-LZC', amount: 2500, currency: 'MXN')
      bl_house_line = create(:bl_house_line)

      expect(create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, quantity: 1, amount: nil).amount).to eq(BigDecimal('2500'))
      expect(create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, quantity: 3, amount: nil).amount).to eq(BigDecimal('7500'))
    end

    it 'calcula BL-PMD-LZC como tarifa fija por HBL' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', code: 'BL-PMD-LZC', amount: 3447, currency: 'MXN')
      bl_house_line = create(:bl_house_line)

      expect(create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, amount: nil).amount).to eq(BigDecimal('3447'))
    end

    it 'calcula BL-EMP-LZC con la cantidad de pallets de la partida' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', code: 'BL-EMP-LZC', amount: 500, currency: 'MXN')
      bl_house_line = create(:bl_house_line, cantidad: 4)

      service = create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, quantity: 1, amount: 1)

      expect(service.amount).to eq(BigDecimal('2000'))
      expect(service.quantity).to eq(4)
    end

    it 'calcula BL-FLJ-LZC como tarifa por metro capturado' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', code: 'BL-FLJ-LZC', amount: 300, currency: 'MXN')
      bl_house_line = create(:bl_house_line)

      expect(create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, quantity: 1, amount: nil).amount).to eq(BigDecimal('300'))
      expect(create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, quantity: 12, amount: nil).amount).to eq(BigDecimal('3600'))
    end

    it 'calcula BL-GRP-LZC como tarifa por pieza capturada' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', code: 'BL-GRP-LZC', amount: 20, currency: 'MXN')
      bl_house_line = create(:bl_house_line)

      expect(create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, quantity: 1, amount: nil).amount).to eq(BigDecimal('20'))
      expect(create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, quantity: 50, amount: nil).amount).to eq(BigDecimal('1000'))
    end

    it 'calcula BL-CLVS-LZC como tarifa por pieza capturada' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', code: 'BL-CLVS-LZC', amount: 15, currency: 'MXN')
      bl_house_line = create(:bl_house_line)

      expect(create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, quantity: 1, amount: nil).amount).to eq(BigDecimal('15'))
      expect(create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, quantity: 40, amount: nil).amount).to eq(BigDecimal('600'))
    end

    it 'calcula BL-REF-LZC como tarifa fija' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', code: 'BL-REF-LZC', amount: 1200, currency: 'MXN')
      bl_house_line = create(:bl_house_line)

      expect(create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, amount: nil).amount).to eq(BigDecimal('1200'))
    end

    it 'calcula BL-ENT-LZC por formula con minimo de 10 unidades' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', code: 'BL-ENT-LZC', amount: 626, currency: 'MXN')
      small = create(:bl_house_line, peso: 3_000, volumen: 4.2)
      large = create(:bl_house_line, peso: 13_200, volumen: 8.1)

      expect(create(:bl_house_line_service, bl_house_line: small, service_catalog: catalog, amount: 1).amount).to eq(BigDecimal('6260'))
      expect(create(:bl_house_line_service, bl_house_line: large, service_catalog: catalog, amount: 1).amount).to eq(BigDecimal('8764'))
    end

    it 'recalcula BL-PREVIO al editar aunque llegue monto manual' do
      catalog = create(
        :service_catalog,
        applies_to: 'bl_house_line',
        code: 'BL-PREVIO',
        amount: 126,
        currency: 'MXN'
      )
      bl_house_line = create(:bl_house_line, peso: 13_200, volumen: 8.1)
      service = create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, amount: 1)

      bl_house_line.update!(peso: 20_100)
      service.update!(amount: 999)

      expect(service.reload.amount).to eq(BigDecimal('2646'))
    end

    it 'calcula BL-RECASU por formula aunque llegue monto manual' do
      catalog = create(
        :service_catalog,
        applies_to: 'bl_house_line',
        code: 'BL-RECASU',
        amount: 126,
        currency: 'MXN'
      )
      bl_house_line = create(:bl_house_line, peso: 13_200, volumen: 8.1)

      service = create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, amount: 1)

      expect(service.amount).to eq(BigDecimal('1764'))
    end

    it 'recalcula BL-RECASU al editar aunque llegue monto manual' do
      catalog = create(
        :service_catalog,
        applies_to: 'bl_house_line',
        code: 'BL-RECASU',
        amount: 126,
        currency: 'MXN'
      )
      bl_house_line = create(:bl_house_line, peso: 13_200, volumen: 8.1)
      service = create(:bl_house_line_service, bl_house_line: bl_house_line, service_catalog: catalog, amount: 1)

      bl_house_line.update!(peso: 20_100)
      service.update!(amount: 999)

      expect(service.reload.amount).to eq(BigDecimal('2646'))
    end

    it 'calcula BL-ETIADH usando cantidad minima cuando la capturada es menor' do
      catalog = create(
        :service_catalog,
        applies_to: 'bl_house_line',
        code: 'BL-ETIADH',
        amount: 1.68,
        currency: 'MXN'
      )
      bl_house_line = create(:bl_house_line, peso: 13_200, volumen: 8.1)

      service = create(
        :bl_house_line_service,
        bl_house_line: bl_house_line,
        service_catalog: catalog,
        quantity: 1000,
        amount: 1
      )

      expect(service.amount).to eq(BigDecimal('2004.24'))
    end

    it 'calcula BL-ETICOS usando cantidad capturada cuando supera el minimo' do
      catalog = create(
        :service_catalog,
        applies_to: 'bl_house_line',
        code: 'BL-ETICOS',
        amount: 4.96,
        currency: 'MXN'
      )
      bl_house_line = create(:bl_house_line, peso: 13_200, volumen: 8.1)

      service = create(
        :bl_house_line_service,
        bl_house_line: bl_house_line,
        service_catalog: catalog,
        quantity: 500,
        amount: 1
      )

      expect(service.amount).to eq(BigDecimal('2480.0'))
    end

    it 'exige cantidad para BL-ETIADH y BL-ETICOS' do
      catalog = create(
        :service_catalog,
        applies_to: 'bl_house_line',
        code: 'BL-ETIADH',
        amount: 1.68,
        currency: 'MXN'
      )
      bl_house_line = create(:bl_house_line, peso: 13_200, volumen: 8.1)

      service = build(
        :bl_house_line_service,
        bl_house_line: bl_house_line,
        service_catalog: catalog,
        quantity: nil,
        amount: 1
      )

      expect(service).not_to be_valid
      expect(service.errors[:quantity]).to include('no puede estar en blanco')
    end

    it 'mantiene compatibilidad con servicios existentes sin quantity capturada' do
      catalog = create(
        :service_catalog,
        applies_to: 'bl_house_line',
        code: 'BL-ASIG',
        amount: 1200,
        currency: 'MXN'
      )
      service = create(:bl_house_line_service, service_catalog: catalog, quantity: nil, amount: nil)

      expect(service).to be_valid
      expect(service.quantity).to eq(1)
      expect(service.amount).to eq(BigDecimal('1200.0'))
    end
  end
end
