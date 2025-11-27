require 'rails_helper'

RSpec.describe ShippingLine, type: :model do
  describe 'validations' do
    it 'is valid with a name' do
      shipping_line = ShippingLine.new(name: 'Maersk')
      expect(shipping_line).to be_valid
    end

    it 'is invalid without a name' do
      shipping_line = ShippingLine.new(name: nil)
      expect(shipping_line).not_to be_valid
      expect(shipping_line.errors[:name]).to include("can't be blank")
    end

    it 'is invalid with a duplicate name (case insensitive)' do
      ShippingLine.create!(name: 'MSC')
      duplicate_shipping_line = ShippingLine.new(name: 'msc')
      expect(duplicate_shipping_line).not_to be_valid
      expect(duplicate_shipping_line.errors[:name]).to include('has already been taken')
    end

    it 'allows different names' do
      ShippingLine.create!(name: 'CMA CGM')
      shipping_line = ShippingLine.new(name: 'Hapag-Lloyd')
      expect(shipping_line).to be_valid
    end
  end
end
