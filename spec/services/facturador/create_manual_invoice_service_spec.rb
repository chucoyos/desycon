require 'rails_helper'

RSpec.describe Facturador::CreateManualInvoiceService, type: :service do
  describe '.call' do
    let(:actor) { create(:user, :admin) }
    let(:issuer) { create(:entity, :customs_agent, :with_fiscal_profile, :with_address) }
    let(:receiver) { create(:entity, :client, :with_fiscal_profile, :with_address) }

    before do
      allow(Facturador::Config).to receive(:enabled?).and_return(true)
      allow(Facturador::Config).to receive(:manual_actions_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:issuer_entity).and_return(issuer)
    end

    it 'returns error when any concept is incomplete' do
      service_catalog = create(:service_catalog)

      result = described_class.call(
        actor: actor,
        receiver_entity_id: receiver.id,
        customs_agent_id: nil,
        line_items_params: [
          {
            service_catalog_id: service_catalog.id,
            description: 'Concepto valido',
            quantity: '1',
            unit_price: '100.00'
          },
          {
            service_catalog_id: '',
            description: 'Concepto incompleto',
            quantity: '1',
            unit_price: '50.00'
          }
        ]
      )

      expect(result.success?).to be(false)
      expect(result.error_message).to include('está incompleto')
      expect(result.invoice).to be_nil
    end

    it 'returns error when concept references an inactive or missing catalog' do
      result = described_class.call(
        actor: actor,
        receiver_entity_id: receiver.id,
        customs_agent_id: nil,
        line_items_params: [
          {
            service_catalog_id: '999999',
            description: 'Concepto invalido',
            quantity: '1',
            unit_price: '100.00'
          }
        ]
      )

      expect(result.success?).to be(false)
      expect(result.error_message).to include('no existe o está inactivo')
      expect(result.invoice).to be_nil
    end

    it 'returns error when quantity is zero' do
      service_catalog = create(:service_catalog)

      result = described_class.call(
        actor: actor,
        receiver_entity_id: receiver.id,
        customs_agent_id: nil,
        line_items_params: [
          {
            service_catalog_id: service_catalog.id,
            description: 'Cantidad invalida',
            quantity: '0',
            unit_price: '100.00'
          }
        ]
      )

      expect(result.success?).to be(false)
      expect(result.error_message).to include('cantidad entera mayor o igual a 1')
      expect(result.invoice).to be_nil
    end

    it 'returns error when quantity has decimals' do
      service_catalog = create(:service_catalog)

      result = described_class.call(
        actor: actor,
        receiver_entity_id: receiver.id,
        customs_agent_id: nil,
        line_items_params: [
          {
            service_catalog_id: service_catalog.id,
            description: 'Cantidad decimal',
            quantity: '1.5',
            unit_price: '100.00'
          }
        ]
      )

      expect(result.success?).to be(false)
      expect(result.error_message).to include('cantidad entera mayor o igual a 1')
      expect(result.invoice).to be_nil
    end

    it 'returns error when quantity is negative' do
      service_catalog = create(:service_catalog)

      result = described_class.call(
        actor: actor,
        receiver_entity_id: receiver.id,
        customs_agent_id: nil,
        line_items_params: [
          {
            service_catalog_id: service_catalog.id,
            description: 'Cantidad negativa',
            quantity: '-1',
            unit_price: '100.00'
          }
        ]
      )

      expect(result.success?).to be(false)
      expect(result.error_message).to include('cantidad entera mayor o igual a 1')
      expect(result.invoice).to be_nil
    end
  end
end
