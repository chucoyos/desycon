require 'rails_helper'

RSpec.describe ShippingLine, type: :model do
  describe 'validations' do
    it 'is valid with a name' do
      shipping_line = ShippingLine.new(name: 'Maersk', scac_code: 'MAEU')
      expect(shipping_line).to be_valid
    end

    it 'is invalid without a name' do
      shipping_line = ShippingLine.new(name: nil, scac_code: 'TEST')
      expect(shipping_line).not_to be_valid
      expect(shipping_line.errors[:name]).to include("no puede estar en blanco")
    end

    it 'is invalid without a scac_code' do
      shipping_line = ShippingLine.new(name: 'Test Line')
      expect(shipping_line).not_to be_valid
      expect(shipping_line.errors[:scac_code]).to include("no puede estar en blanco")
    end

    it 'is invalid with scac_code not exactly 4 characters' do
      shipping_line = ShippingLine.new(name: 'Test Line', scac_code: 'ABC')
      expect(shipping_line).not_to be_valid
      expect(shipping_line.errors[:scac_code]).to include("no tiene la longitud correcta (4 caracteres exactos)")
    end

    it 'is invalid with a duplicate name (case insensitive)' do
      ShippingLine.create!(name: 'MSC', scac_code: 'MSCU')
      duplicate_shipping_line = ShippingLine.new(name: 'msc', scac_code: 'TEST')
      expect(duplicate_shipping_line).not_to be_valid
      expect(duplicate_shipping_line.errors[:name]).to include('ya está en uso')
    end

    it 'is invalid with a duplicate scac_code (case insensitive)' do
      ShippingLine.create!(name: 'MSC', scac_code: 'MSCU')
      duplicate_shipping_line = ShippingLine.new(name: 'Test Line', scac_code: 'mscu')
      expect(duplicate_shipping_line).not_to be_valid
      expect(duplicate_shipping_line.errors[:scac_code]).to include('ya está en uso')
    end

    it 'allows different names' do
      ShippingLine.create!(name: 'CMA CGM', scac_code: 'CMDU')
      shipping_line = ShippingLine.new(name: 'Hapag-Lloyd', scac_code: 'HPGL')
      expect(shipping_line).to be_valid
    end
  end
end
