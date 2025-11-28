require 'rails_helper'

RSpec.describe Port, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      port = Port.new(name: 'Puerto de Veracruz', code: 'MXVER', country_code: 'MX')
      expect(port).to be_valid
    end

    it 'is invalid without a name' do
      port = Port.new(name: nil, code: 'MXVER', country_code: 'MX')
      expect(port).not_to be_valid
      expect(port.errors[:name]).to include('no puede estar en blanco')
    end

    it 'is invalid without a code' do
      port = Port.new(name: 'Puerto de Veracruz', code: nil, country_code: 'MX')
      expect(port).not_to be_valid
      expect(port.errors[:code]).to include('no puede estar en blanco')
    end

    it 'is invalid without a country_code' do
      port = Port.new(name: 'Puerto de Veracruz', code: 'MXVER', country_code: nil)
      expect(port).not_to be_valid
      expect(port.errors[:country_code]).to include('no puede estar en blanco')
    end

    it 'is invalid with a duplicate code (case insensitive)' do
      Port.create!(name: 'Puerto de Veracruz', code: 'MXVER', country_code: 'MX')
      duplicate_port = Port.new(name: 'Otro Puerto', code: 'mxver', country_code: 'MX')
      expect(duplicate_port).not_to be_valid
      expect(duplicate_port.errors[:code]).to include('ya está en uso')
    end

    it 'is invalid with an invalid country code' do
      port = Port.new(name: 'Puerto de Veracruz', code: 'MXVER', country_code: 'XX')
      expect(port).not_to be_valid
      expect(port.errors[:country_code]).to include('no está incluido en la lista')
    end

    it 'normalizes code to uppercase' do
      port = Port.create!(name: 'Puerto de Veracruz', code: 'mxver', country_code: 'MX')
      expect(port.code).to eq('MXVER')
    end
  end

  describe 'scopes' do
    let!(:mx_port1) { Port.create!(name: 'Veracruz', code: 'MXVER', country_code: 'MX') }
    let!(:mx_port2) { Port.create!(name: 'Manzanillo', code: 'MXZLO', country_code: 'MX') }
    let!(:us_port) { Port.create!(name: 'Los Angeles', code: 'USLAX', country_code: 'US') }

    it 'filters by country' do
      expect(Port.by_country('MX')).to contain_exactly(mx_port1, mx_port2)
      expect(Port.by_country('US')).to contain_exactly(us_port)
    end

    it 'orders alphabetically' do
      expect(Port.alphabetical).to eq([ us_port, mx_port2, mx_port1 ])
    end
  end

  describe 'methods' do
    let(:port) { Port.create!(name: 'Puerto de Veracruz', code: 'MXVER', country_code: 'MX') }

    it 'returns the country object' do
      expect(port.country).to be_a(ISO3166::Country)
      expect(port.country.alpha2).to eq('MX')
    end

    it 'returns the country name in Spanish' do
      expect(port.country_name).to eq('México')
    end

    it 'returns a display name with code' do
      expect(port.display_name).to eq('Puerto de Veracruz (MXVER)')
    end
  end
end
