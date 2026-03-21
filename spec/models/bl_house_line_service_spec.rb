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
  end
end
