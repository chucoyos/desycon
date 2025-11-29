require 'rails_helper'

RSpec.describe FiscalProfile, type: :model do
  describe 'associations' do
    it 'belongs to profileable polymorphically' do
      shipping_line = create(:shipping_line)
      fiscal_profile = build(:fiscal_profile, profileable: shipping_line)
      expect(fiscal_profile.profileable).to eq(shipping_line)
    end
  end

  describe 'validations' do
    let(:fiscal_profile) { build(:fiscal_profile) }

    it 'is valid with valid attributes' do
      expect(fiscal_profile).to be_valid
    end

    describe 'razon_social' do
      it 'requires razon_social' do
        fiscal_profile.razon_social = nil
        expect(fiscal_profile).not_to be_valid
        expect(fiscal_profile.errors[:razon_social]).to include("no puede estar en blanco")
      end

      it 'validates maximum length' do
        fiscal_profile.razon_social = 'A' * 255
        expect(fiscal_profile).not_to be_valid
      end
    end

    describe 'rfc' do
      it 'requires rfc' do
        fiscal_profile.rfc = nil
        expect(fiscal_profile).not_to be_valid
      end

      it 'requires 12 characters' do
        fiscal_profile.rfc = 'ABC12345'
        expect(fiscal_profile).not_to be_valid
        expect(fiscal_profile.errors[:rfc]).to include('debe tener 12 caracteres para personas morales')
      end

      it 'validates RFC format' do
        fiscal_profile.rfc = 'INVALID12345'
        expect(fiscal_profile).not_to be_valid
      end

      it 'accepts valid RFC' do
        fiscal_profile.rfc = 'EMP850101XXX'
        expect(fiscal_profile).to be_valid
      end

      it 'normalizes RFC to uppercase' do
        fiscal_profile.rfc = 'emp850101xxx'
        fiscal_profile.valid?
        expect(fiscal_profile.rfc).to eq('EMP850101XXX')
      end

      it 'validates uniqueness case-insensitively' do
        create(:fiscal_profile, rfc: 'EMP850101XXX')
        fiscal_profile.rfc = 'emp850101xxx'
        expect(fiscal_profile).not_to be_valid
      end
    end

    describe 'regimen' do
      it 'requires regimen' do
        fiscal_profile.regimen = nil
        expect(fiscal_profile).not_to be_valid
      end

      it 'validates regimen is in catalog' do
        fiscal_profile.regimen = '999'
        expect(fiscal_profile).not_to be_valid
      end

      it 'accepts valid regimen' do
        fiscal_profile.regimen = '601'
        expect(fiscal_profile).to be_valid
      end
    end

    describe 'catalogs' do
      it 'validates uso_cfdi when present' do
        fiscal_profile.uso_cfdi = 'INVALID'
        expect(fiscal_profile).not_to be_valid
      end

      it 'allows blank uso_cfdi' do
        fiscal_profile.uso_cfdi = nil
        expect(fiscal_profile).to be_valid
      end

      it 'validates forma_pago when present' do
        fiscal_profile.forma_pago = 'INVALID'
        expect(fiscal_profile).not_to be_valid
      end

      it 'validates metodo_pago when present' do
        fiscal_profile.metodo_pago = 'INVALID'
        expect(fiscal_profile).not_to be_valid
      end
    end
  end

  describe 'scopes' do
    it 'finds by RFC case-insensitively' do
      profile = create(:fiscal_profile, rfc: 'EMP850101XXX')
      expect(FiscalProfile.by_rfc('emp850101xxx')).to include(profile)
    end
  end

  describe 'instance methods' do
    let(:fiscal_profile) { build(:fiscal_profile, razon_social: 'Test SA de CV') }

    it 'returns razon_social as string representation' do
      expect(fiscal_profile.to_s).to eq('Test SA de CV')
    end

    it 'returns regimen name' do
      fiscal_profile.regimen = '601'
      expect(fiscal_profile.regimen_nombre).to eq('General de Ley Personas Morales')
    end

    it 'returns uso_cfdi name' do
      fiscal_profile.uso_cfdi = 'G03'
      expect(fiscal_profile.uso_cfdi_nombre).to eq('Gastos en general')
    end

    it 'returns forma_pago name' do
      fiscal_profile.forma_pago = '03'
      expect(fiscal_profile.forma_pago_nombre).to eq('Transferencia electrónica de fondos')
    end

    it 'returns metodo_pago name' do
      fiscal_profile.metodo_pago = 'PUE'
      expect(fiscal_profile.metodo_pago_nombre).to eq('Pago en una sola exhibición')
    end
  end
end
