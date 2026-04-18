require 'rails_helper'

RSpec.describe Facturador::IssueGroupedServicesService, type: :service do
  describe '.call' do
    let(:actor) { create(:user, :admin) }
    let(:issuer) do
      create(:entity, :customs_agent).tap do |entity|
        create(:fiscal_profile, profileable: entity)
        create(:address, addressable: entity, tipo: 'matriz')
        entity.reload
      end
    end
    let(:receiver) do
      create(:entity, :client).tap do |entity|
        create(:fiscal_profile, profileable: entity)
        create(:address, addressable: entity, tipo: 'matriz')
        entity.reload
      end
    end

    before do
      allow(Facturador::Config).to receive(:enabled?).and_return(true)
      allow(Facturador::Config).to receive(:manual_actions_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:issuer_entity).and_return(issuer)
    end

    it 'creates one invoice with multiple line items and links all selected services' do
      container = create(:container, consolidator_entity: receiver)
      first_service = create(:container_service, container: container, factura: nil)
      second_service = create(:container_service, container: container, factura: nil)
      first_service.update!(billed_to_entity: receiver)
      second_service.update!(billed_to_entity: receiver)

      result = described_class.call(serviceables: [ first_service, second_service ], actor: actor)

      expect(result.success?).to be(true), result.error_message
      expect(result.invoice).to be_present
      expect(result.invoice.invoice_line_items.count).to eq(2)
      expect(result.invoice.invoice_service_links.count).to eq(2)
      expect(result.invoice.invoice_service_links.pluck(:serviceable_id)).to match_array([ first_service.id, second_service.id ])
      expect(result.invoice.status).to eq('queued')
    end

    it 'returns an error when selected services have different receivers' do
      container = create(:container)
      other_receiver = create(:entity, :client, :with_fiscal_profile, :with_address)
      first_service = create(:container_service, container: container, factura: nil)
      second_service = create(:container_service, container: container, factura: nil)
      first_service.update!(billed_to_entity: receiver)
      second_service.update!(billed_to_entity: other_receiver)

      result = described_class.call(serviceables: [ first_service, second_service ], actor: actor)

      expect(result.success?).to be(false)
      expect(result.error_message).to include('mismo receptor')
    end

    it 'enriches grouped line item descriptions with container and blhouse when available' do
      bl_service = create(:bl_house_line_service, factura: nil)
      bl_service.update!(billed_to_entity: receiver)

      result = described_class.call(serviceables: [ bl_service ], actor: actor)

      expect(result.success?).to be(true), result.error_message

      line_item = result.invoice.invoice_line_items.first
      container_token = I18n.transliterate(bl_service.bl_house_line.container.number.to_s).gsub(/[^A-Za-z0-9]/, '')
      blhouse_token = I18n.transliterate(bl_service.bl_house_line.blhouse.to_s).gsub(/[^A-Za-z0-9]/, '')

      expect(line_item.description).to include("Contenedor #{container_token}")
      expect(line_item.description).to include("BlHouse #{blhouse_token}")
    end
  end
end
