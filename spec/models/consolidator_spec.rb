require 'rails_helper'

RSpec.describe Consolidator, type: :model do
  describe 'associations' do
    it 'has one fiscal_profile' do
      consolidator = create(:consolidator, :with_fiscal_profile)
      expect(consolidator.fiscal_profile).to be_present
      expect(consolidator.fiscal_profile).to be_a(FiscalProfile)
    end

    it 'has many addresses' do
      consolidator = create(:consolidator)
      address1 = create(:address, addressable: consolidator)
      address2 = create(:address, :envio, addressable: consolidator)
      expect(consolidator.addresses.count).to eq(2)
    end

    it 'destroys fiscal_profile when destroyed' do
      consolidator = create(:consolidator, :with_fiscal_profile)
      fiscal_profile_id = consolidator.fiscal_profile.id
      consolidator.destroy
      expect(FiscalProfile.find_by(id: fiscal_profile_id)).to be_nil
    end

    it 'destroys addresses when destroyed' do
      consolidator = create(:consolidator, :with_fiscal_address)
      address_id = consolidator.addresses.first.id
      consolidator.destroy
      expect(Address.find_by(id: address_id)).to be_nil
    end
  end

  describe 'validations' do
    let(:consolidator) { build(:consolidator) }

    it 'is valid with valid attributes' do
      expect(consolidator).to be_valid
    end

    describe 'name' do
      it 'requires name' do
        consolidator.name = nil
        expect(consolidator).not_to be_valid
        expect(consolidator.errors[:name]).to include("no puede estar en blanco")
      end

      it 'validates uniqueness case-insensitively' do
        create(:consolidator, name: 'Test Consolidador')
        consolidator.name = 'test consolidador'
        expect(consolidator).not_to be_valid
      end

      it 'validates maximum length' do
        consolidator.name = 'A' * 201
        expect(consolidator).not_to be_valid
      end
    end
  end

  describe 'scopes' do
    before do
      create(:consolidator, name: 'Zebra')
      create(:consolidator, name: 'Alpha')
      create(:consolidator, name: 'Beta')
    end

    it 'returns consolidators in alphabetical order' do
      names = Consolidator.alphabetical.pluck(:name)
      expect(names).to eq([ 'Alpha', 'Beta', 'Zebra' ])
    end

    it 'includes fiscal_profile with with_fiscal_data scope' do
      consolidator = create(:consolidator, :with_fiscal_profile)
      # Verificar que no hace query adicional
      result = Consolidator.with_fiscal_data.find(consolidator.id)
      queries = 0
      ActiveSupport::Notifications.subscribe('sql.active_record') { queries += 1 }
      result.fiscal_profile
      expect(queries).to eq(0)
    end

    it 'includes addresses with with_addresses scope' do
      consolidator = create(:consolidator, :with_fiscal_address)
      # Verificar que no hace query adicional
      result = Consolidator.with_addresses.find(consolidator.id)
      queries = 0
      ActiveSupport::Notifications.subscribe('sql.active_record') { queries += 1 }
      result.addresses.to_a
      expect(queries).to eq(0)
    end
  end

  describe 'instance methods' do
    let(:consolidator) { create(:consolidator, name: 'Test Consolidador') }

    it 'returns name as string representation' do
      expect(consolidator.to_s).to eq('Test Consolidador')
    end

    describe '#fiscal_address' do
      it 'returns the fiscal address' do
        fiscal_addr = create(:address, addressable: consolidator, tipo: 'fiscal')
        create(:address, :envio, addressable: consolidator)
        expect(consolidator.fiscal_address).to eq(fiscal_addr)
      end

      it 'returns nil when no fiscal address exists' do
        expect(consolidator.fiscal_address).to be_nil
      end
    end

    describe '#shipping_addresses' do
      it 'returns only shipping addresses' do
        create(:address, addressable: consolidator, tipo: 'fiscal')
        envio1 = create(:address, :envio, addressable: consolidator)
        envio2 = create(:address, :envio, addressable: consolidator)
        expect(consolidator.shipping_addresses.count).to eq(2)
        expect(consolidator.shipping_addresses).to include(envio1, envio2)
      end
    end

    describe '#warehouse_addresses' do
      it 'returns only warehouse addresses' do
        create(:address, addressable: consolidator, tipo: 'fiscal')
        almacen = create(:address, :almacen, addressable: consolidator)
        expect(consolidator.warehouse_addresses.count).to eq(1)
        expect(consolidator.warehouse_addresses).to include(almacen)
      end
    end

    describe '#build_fiscal_profile_if_needed' do
      it 'builds fiscal_profile if blank' do
        expect(consolidator.fiscal_profile).to be_nil
        consolidator.build_fiscal_profile_if_needed
        expect(consolidator.fiscal_profile).to be_a(FiscalProfile)
        expect(consolidator.fiscal_profile).to be_new_record
      end

      it 'does not build if already exists' do
        consolidator = create(:consolidator, :with_fiscal_profile)
        existing_profile = consolidator.fiscal_profile
        consolidator.build_fiscal_profile_if_needed
        expect(consolidator.fiscal_profile).to eq(existing_profile)
      end
    end

    describe '#build_fiscal_address_if_needed' do
      it 'builds fiscal address if none exists' do
        expect(consolidator.addresses.fiscales).to be_empty
        consolidator.build_fiscal_address_if_needed
        fiscal_addresses = consolidator.addresses.select { |a| a.tipo == 'fiscal' }
        expect(fiscal_addresses.count).to eq(1)
        expect(fiscal_addresses.first.tipo).to eq('fiscal')
      end

      it 'does not build if fiscal address already exists' do
        create(:address, addressable: consolidator, tipo: 'fiscal')
        consolidator.reload
        expect {
          consolidator.build_fiscal_address_if_needed
        }.not_to change { consolidator.addresses.fiscales.count }
      end
    end
  end

  describe 'nested attributes' do
    it 'accepts nested attributes for fiscal_profile' do
      consolidator = create(:consolidator)
      consolidator.update(
        fiscal_profile_attributes: {
          razon_social: 'Test SA de CV',
          rfc: 'TST850101XXX',
          regimen: '601'
        }
      )
      expect(consolidator.fiscal_profile).to be_present
      expect(consolidator.fiscal_profile.razon_social).to eq('Test SA de CV')
    end

    it 'accepts nested attributes for addresses' do
      consolidator = create(:consolidator)
      consolidator.update(
        addresses_attributes: [
          {
            tipo: 'fiscal',
            pais: 'MX',
            codigo_postal: '06600',
            estado: 'CDMX',
            calle: 'Reforma',
            email: 'fiscal@test.com'
          }
        ]
      )
      expect(consolidator.addresses.count).to eq(1)
      expect(consolidator.addresses.first.tipo).to eq('fiscal')
    end
  end
end
