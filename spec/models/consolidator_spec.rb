require 'rails_helper'

RSpec.describe Consolidator, type: :model do
  describe 'associations' do
    it 'belongs to entity' do
      consolidator = create(:consolidator)
      expect(consolidator.entity).to be_present
      expect(consolidator.entity).to be_a(Entity)
    end

    it 'has many containers' do
      consolidator = create(:consolidator)
      expect(consolidator).to respond_to(:containers)
    end

    it 'delegates fiscal_profile to entity' do
      consolidator = create(:consolidator, :with_fiscal_profile)
      expect(consolidator.fiscal_profile).to be_present
      expect(consolidator.fiscal_profile).to be_a(FiscalProfile)
      expect(consolidator.fiscal_profile).to eq(consolidator.entity.fiscal_profile)
    end

    it 'delegates addresses to entity' do
      consolidator = create(:consolidator)
      create(:address, addressable: consolidator.entity, tipo: 'fiscal')
      create(:address, :envio, addressable: consolidator.entity)
      expect(consolidator.addresses.count).to eq(2)
      expect(consolidator.addresses).to eq(consolidator.entity.addresses)
    end

    it 'destroys fiscal_profile when entity is destroyed' do
      consolidator = create(:consolidator, :with_fiscal_profile)
      fiscal_profile_id = consolidator.entity.fiscal_profile.id
      consolidator.entity.destroy
      expect(FiscalProfile.find_by(id: fiscal_profile_id)).to be_nil
    end

    it 'destroys addresses when entity is destroyed' do
      consolidator = create(:consolidator, :with_fiscal_address)
      address_id = consolidator.entity.addresses.first.id
      consolidator.entity.destroy
      expect(Address.find_by(id: address_id)).to be_nil
    end
  end

  describe 'validations' do
    let(:consolidator) { create(:consolidator) }

    it 'is valid with valid attributes' do
      expect(consolidator).to be_valid
    end

    it 'requires entity_id' do
      consolidator.entity = nil
      expect(consolidator).not_to be_valid
      expect(consolidator.errors[:entity_id]).to include("no puede estar en blanco")
    end

    it 'validates uniqueness of entity_id' do
      entity = create(:entity, is_consolidator: true)
      create(:consolidator, entity: entity)
      duplicate = build(:consolidator, entity: entity)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:entity_id]).to include("ya está en uso")
    end

    describe 'name delegation' do
      it 'delegates name to entity' do
        consolidator = create(:consolidator)
        consolidator.entity.update(name: 'Test Consolidador')
        expect(consolidator.name).to eq('Test Consolidador')
      end
    end
  end

  describe 'scopes' do
    before do
      create(:consolidator).entity.update(name: 'Zebra')
      create(:consolidator).entity.update(name: 'Alpha')
      create(:consolidator).entity.update(name: 'Beta')
    end

    it 'returns consolidators in alphabetical order' do
      names = Consolidator.alphabetical.map(&:name)
      expect(names).to eq([ 'Alpha', 'Beta', 'Zebra' ])
    end

    it 'includes fiscal_profile with with_fiscal_data scope' do
      consolidator = create(:consolidator, :with_fiscal_profile)
      result = Consolidator.with_fiscal_data.find(consolidator.id)
      # Verify association is preloaded
      expect(result.association(:entity).loaded?).to be_truthy
    end

    it 'includes addresses with with_addresses scope' do
      consolidator = create(:consolidator, :with_fiscal_address)
      result = Consolidator.with_addresses.find(consolidator.id)
      # Verify association is preloaded
      expect(result.association(:entity).loaded?).to be_truthy
    end
  end

  describe 'instance methods' do
    let(:consolidator) { create(:consolidator) }

    before do
      consolidator.entity.update(name: 'Test Consolidador')
    end

    it 'returns name as string representation' do
      expect(consolidator.to_s).to eq('Test Consolidador')
    end

    describe '#fiscal_address' do
      it 'returns the fiscal address' do
        fiscal_addr = create(:address, addressable: consolidator.entity, tipo: 'fiscal')
        create(:address, :envio, addressable: consolidator.entity)
        expect(consolidator.fiscal_address).to eq(fiscal_addr)
      end

      it 'returns nil when no fiscal address exists' do
        expect(consolidator.fiscal_address).to be_nil
      end
    end

    describe '#shipping_addresses' do
      it 'returns only shipping addresses' do
        create(:address, addressable: consolidator.entity, tipo: 'fiscal')
        envio1 = create(:address, :envio, addressable: consolidator.entity)
        envio2 = create(:address, :envio, addressable: consolidator.entity)
        expect(consolidator.shipping_addresses.count).to eq(2)
        expect(consolidator.shipping_addresses).to include(envio1, envio2)
      end
    end

    describe '#warehouse_addresses' do
      it 'returns only warehouse addresses' do
        create(:address, addressable: consolidator.entity, tipo: 'fiscal')
        almacen = create(:address, :almacen, addressable: consolidator.entity)
        expect(consolidator.warehouse_addresses.count).to eq(1)
        expect(consolidator.warehouse_addresses).to include(almacen)
      end
    end

    describe '#build_fiscal_profile_if_needed' do
      it 'delegates to entity and builds fiscal_profile if blank' do
        expect(consolidator.fiscal_profile).to be_nil
        consolidator.build_fiscal_profile_if_needed
        expect(consolidator.entity.fiscal_profile).to be_a(FiscalProfile)
        expect(consolidator.entity.fiscal_profile).to be_new_record
      end

      it 'does not build if already exists' do
        consolidator = create(:consolidator, :with_fiscal_profile)
        existing_profile = consolidator.fiscal_profile
        consolidator.build_fiscal_profile_if_needed
        expect(consolidator.fiscal_profile).to eq(existing_profile)
      end
    end

    describe '#build_fiscal_address_if_needed' do
      it 'delegates to entity and builds fiscal address if none exists' do
        expect(consolidator.entity.addresses.fiscales).to be_empty
        consolidator.build_fiscal_address_if_needed
        fiscal_addresses = consolidator.entity.addresses.select { |a| a.tipo == 'fiscal' }
        expect(fiscal_addresses.count).to eq(1)
        expect(fiscal_addresses.first.tipo).to eq('fiscal')
      end

      it 'does not build if fiscal address already exists' do
        create(:address, addressable: consolidator.entity, tipo: 'fiscal')
        consolidator.reload
        expect {
          consolidator.build_fiscal_address_if_needed
        }.not_to change { consolidator.entity.addresses.fiscales.count }
      end
    end
  end

  describe 'entity management' do
    it 'accepts nested attributes through entity for fiscal_profile' do
      consolidator = create(:consolidator)
      consolidator.entity.update(
        fiscal_profile_attributes: {
          razon_social: 'Test SA de CV',
          rfc: 'TST850101XXX',
          regimen: '601'
        }
      )
      expect(consolidator.fiscal_profile).to be_present
      expect(consolidator.fiscal_profile.razon_social).to eq('Test SA de CV')
    end

    it 'accepts nested attributes through entity for addresses' do
      consolidator = create(:consolidator)
      consolidator.entity.update(
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
