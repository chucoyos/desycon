require 'rails_helper'

RSpec.describe Packaging, type: :model do
  describe 'validations' do
    it 'validates presence of nombre' do
      packaging = described_class.new(nombre: nil)

      expect(packaging).not_to be_valid
      expect(packaging.errors[:nombre]).to include("no puede estar en blanco")
    end

    it 'validates case-insensitive uniqueness of nombre' do
      create(:packaging, nombre: 'Caja')
      duplicated = build(:packaging, nombre: 'caja')

      expect(duplicated).not_to be_valid
      expect(duplicated.errors[:nombre]).to include('ya está en uso')
    end
  end
end
