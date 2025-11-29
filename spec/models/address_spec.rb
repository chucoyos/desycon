require 'rails_helper'

RSpec.describe Address, type: :model do
  describe 'associations' do
    it 'belongs to addressable polymorphically' do
      shipping_line = create(:shipping_line)
      address = build(:address, addressable: shipping_line)
      expect(address.addressable).to eq(shipping_line)
    end
  end

  describe 'validations' do
    let(:address) { build(:address) }

    it 'is valid with valid attributes' do
      expect(address).to be_valid
    end

    describe 'pais' do
      it 'requires pais' do
        address.pais = nil
        expect(address).not_to be_valid
      end

      it 'requires 2 character ISO code' do
        address.pais = 'MEX'
        expect(address).not_to be_valid
      end

      it 'validates uppercase format' do
        address.pais = 'mx'
        expect(address).to be_valid # normaliza a MX
        address.valid?
        expect(address.pais).to eq('MX')
      end
    end

    describe 'codigo_postal' do
      it 'requires codigo_postal' do
        address.codigo_postal = nil
        expect(address).not_to be_valid
      end

      it 'validates maximum length' do
        address.codigo_postal = '1' * 11
        expect(address).not_to be_valid
      end
    end

    describe 'estado' do
      it 'requires estado' do
        address.estado = nil
        expect(address).not_to be_valid
      end
    end

    describe 'email' do
      it 'requires email' do
        address.email = nil
        expect(address).not_to be_valid
      end

      it 'validates email format' do
        address.email = 'invalid-email'
        expect(address).not_to be_valid
      end

      it 'accepts valid email' do
        address.email = 'test@example.com'
        expect(address).to be_valid
      end
    end

    describe 'optional fields' do
      it 'allows blank calle' do
        address.calle = nil
        expect(address).to be_valid
      end

      it 'allows blank municipio' do
        address.municipio = nil
        expect(address).to be_valid
      end

      it 'allows blank numero_interior' do
        address.numero_interior = nil
        expect(address).to be_valid
      end

      it 'allows blank colonia' do
        address.colonia = nil
        expect(address).to be_valid
      end
    end

    describe 'tipo' do
      it 'validates tipo is in catalog when present' do
        address.tipo = 'invalid'
        expect(address).not_to be_valid
      end

      it 'accepts valid tipo' do
        Address::TIPOS.keys.each do |tipo|
          address.tipo = tipo
          expect(address).to be_valid
        end
      end

      it 'allows blank tipo' do
        address.tipo = nil
        expect(address).to be_valid
      end
    end
  end

  describe 'scopes' do
    before do
      create(:address, :envio)
      create(:address, tipo: 'fiscal')
      create(:address, :almacen)
    end

    it 'filters fiscales addresses' do
      expect(Address.fiscales.count).to eq(1)
    end

    it 'filters envio addresses' do
      expect(Address.envio.count).to eq(1)
    end

    it 'filters almacenes addresses' do
      expect(Address.almacenes.count).to eq(1)
    end

    it 'finds by codigo_postal' do
      address = create(:address, codigo_postal: '06600')
      expect(Address.by_codigo_postal('06600')).to include(address)
    end
  end

  describe 'instance methods' do
    let(:address) do
      build(:address,
            calle: 'Reforma',
            numero_exterior: '123',
            numero_interior: 'A',
            colonia: 'Centro',
            codigo_postal: '06600',
            municipio: 'Cuauhtémoc',
            estado: 'CDMX',
            pais: 'MX')
    end

    it 'returns formatted address as string' do
      expect(address.to_s).to include('Reforma')
      expect(address.to_s).to include('123')
      expect(address.to_s).to include('Int. A')
      expect(address.to_s).to include('CP 06600')
    end

    it 'returns domicilio_completo' do
      expect(address.domicilio_completo).to eq(address.to_s)
    end

    it 'returns tipo_nombre' do
      address.tipo = 'fiscal'
      expect(address.tipo_nombre).to eq('Domicilio Fiscal')
    end

    it 'normalizes codigo_postal removing spaces' do
      address.codigo_postal = '066 00'
      address.valid?
      expect(address.codigo_postal).to eq('06600')
    end
  end
end
