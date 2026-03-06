require 'rails_helper'

RSpec.describe BlHouseLineService, type: :model do
  describe 'facturador auto issue callback' do
    it 'does not attempt auto issue when feature is disabled' do
      allow(Facturador::Config).to receive(:enabled?).and_return(false)

      expect(Facturador::AutoIssueService).not_to receive(:call)
      create(:bl_house_line_service)
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
  end
end
