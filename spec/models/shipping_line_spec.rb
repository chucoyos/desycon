require 'rails_helper'

RSpec.describe ShippingLine, type: :model do
  describe 'validations' do
    it 'is valid with a name' do
      shipping_line = ShippingLine.new(name: 'Maersk', iso_code: 'MAE')
      expect(shipping_line).to be_valid
    end

    it 'is invalid without a name' do
      shipping_line = ShippingLine.new(name: nil, iso_code: 'TES')
      expect(shipping_line).not_to be_valid
      expect(shipping_line.errors[:name]).to include("no puede estar en blanco")
    end

    it 'is invalid without a iso_code' do
      shipping_line = ShippingLine.new(name: 'Test Line')
      expect(shipping_line).not_to be_valid
      expect(shipping_line.errors[:iso_code]).to include("no puede estar en blanco")
    end

    it 'is invalid with iso_code not exactly 3 characters' do
      shipping_line = ShippingLine.new(name: 'Test Line', iso_code: 'AB')
      expect(shipping_line).not_to be_valid
      expect(shipping_line.errors[:iso_code]).to include("no tiene la longitud correcta (3 caracteres exactos)")
    end

    it 'is invalid with a duplicate name (case insensitive)' do
      ShippingLine.create!(name: 'MSC', iso_code: 'MSC')
      duplicate_shipping_line = ShippingLine.new(name: 'msc', iso_code: 'TES')
      expect(duplicate_shipping_line).not_to be_valid
      expect(duplicate_shipping_line.errors[:name]).to include('ya está en uso')
    end

    it 'is invalid with a duplicate iso_code (case insensitive)' do
      ShippingLine.create!(name: 'MSC', iso_code: 'MSC')
      duplicate_shipping_line = ShippingLine.new(name: 'Test Line', iso_code: 'msc')
      expect(duplicate_shipping_line).not_to be_valid
      expect(duplicate_shipping_line.errors[:iso_code]).to include('ya está en uso')
    end

    it 'allows different names' do
      ShippingLine.create!(name: 'CMA CGM', iso_code: 'CMD')
      shipping_line = ShippingLine.new(name: 'Hapag-Lloyd', iso_code: 'HPG')
      expect(shipping_line).to be_valid
    end
  end
end
