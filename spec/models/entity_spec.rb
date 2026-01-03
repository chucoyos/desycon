require 'rails_helper'

RSpec.describe Entity, type: :model do
  describe 'associations' do
    it 'has many bl_house_lines_as_customs_agent' do
      association = described_class.reflect_on_association(:bl_house_lines_as_customs_agent)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:class_name]).to eq('BlHouseLine')
      expect(association.options[:foreign_key]).to eq('customs_agent_id')
      expect(association.options[:dependent]).to eq(:restrict_with_error)
    end

    it 'has many bl_house_lines_as_client' do
      association = described_class.reflect_on_association(:bl_house_lines_as_client)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:class_name]).to eq('BlHouseLine')
      expect(association.options[:foreign_key]).to eq('client_id')
      expect(association.options[:dependent]).to eq(:restrict_with_error)
    end
  end

  describe 'deletion restrictions' do
    let(:customs_agent) { create(:entity, :customs_agent) }
    let(:client) { create(:entity, customs_agent: customs_agent) }

    it 'prevents deletion when entity is referenced as customs_agent in bl_house_lines' do
      create(:bl_house_line, customs_agent: customs_agent)

      expect(customs_agent.destroy).to be_falsey
      expect(customs_agent.errors[:base]).to include("No se puede eliminar el registro porque existen bl house lines as customs agent dependientes")
    end

    it 'prevents deletion when entity is referenced as client in bl_house_lines' do
      create(:bl_house_line, client: client)

      expect(client.destroy).to be_falsey
      expect(client.errors[:base]).to include("No se puede eliminar el registro porque existen bl house lines as client dependientes")
    end

    it 'allows deletion when entity has no associated bl_house_lines' do
      entity = create(:entity)
      expect { entity.destroy }.not_to raise_error
      expect(entity.destroyed?).to be_truthy
    end
  end
end
