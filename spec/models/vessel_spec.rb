require 'rails_helper'

RSpec.describe Vessel, type: :model do
  describe 'validations' do
    it 'requires name' do
      vessel = Vessel.new(name: nil, shipping_line: create(:shipping_line))
      vessel.valid?
      expect(vessel.errors[:name]).to include('no puede estar en blanco')
    end

    it 'requires unique name' do
      line = create(:shipping_line)
      create(:vessel, name: 'Unique Vessel', shipping_line: line)
      duplicate_vessel = Vessel.new(name: 'Unique Vessel', shipping_line: line)
      duplicate_vessel.valid?
      expect(duplicate_vessel.errors[:name]).to include('ya está en uso')
    end

    it 'requires shipping_line' do
      vessel = Vessel.new(name: 'Test Vessel', shipping_line: nil)
      vessel.valid?
      expect(vessel.errors[:shipping_line]).to include('debe existir')
    end
  end

  describe 'associations' do
    it 'belongs to shipping_line' do
      vessel = build(:vessel)
      expect(vessel.shipping_line).to be_present
    end
  end

  describe 'scopes' do
    it 'orders alphabetically' do
      line = create(:shipping_line)
      vessel_b = create(:vessel, name: 'Bravo', shipping_line: line)
      vessel_a = create(:vessel, name: 'Alpha', shipping_line: line)
      expect(Vessel.alphabetical).to eq([ vessel_a, vessel_b ])
    end
  end
end
