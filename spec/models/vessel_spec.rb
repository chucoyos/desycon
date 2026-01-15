require 'rails_helper'

RSpec.describe Vessel, type: :model do
  describe 'validations' do
    it 'requires name' do
      vessel = Vessel.new(name: nil)
      vessel.valid?
      expect(vessel.errors[:name]).to include('no puede estar en blanco')
    end

    it 'requires unique name' do
      create(:vessel, name: 'Unique Vessel')
      duplicate_vessel = Vessel.new(name: 'Unique Vessel')
      duplicate_vessel.valid?
      expect(duplicate_vessel.errors[:name]).to include('ya está en uso')
    end
  end

  describe 'associations' do
    it 'has many containers' do
      association = described_class.reflect_on_association(:containers)
      expect(association.macro).to eq(:has_many)
    end
  end

  describe 'scopes' do
    it 'orders alphabetically' do
      vessel_b = create(:vessel, name: 'Bravo')
      vessel_a = create(:vessel, name: 'Alpha')
      expect(Vessel.alphabetical).to eq([ vessel_a, vessel_b ])
    end
  end
end
