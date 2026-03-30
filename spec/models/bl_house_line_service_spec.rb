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
    it 'usa el monto del catalogo por defecto al crear' do
      catalog = create(:service_catalog, applies_to: 'bl_house_line', amount: 180.25)

      service = create(:bl_house_line_service, service_catalog: catalog, amount: nil)

      expect(service.amount).to eq(180.25)
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
  end
end
