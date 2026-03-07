require 'rails_helper'

RSpec.describe 'EntityAddresses', type: :request do
  let(:user) { create(:user, :admin) }
  let(:entity) { create(:entity) }

  before do
    sign_in user, scope: :user
  end

  describe 'POST /entities/:entity_id/addresses' do
    it 'defaults tipo to matriz when entity has no fiscal address' do
      expect {
        post entity_addresses_path(entity), params: {
          address: {
            pais: 'MX',
            codigo_postal: '01010',
            estado: 'Ciudad de Mexico',
            email: 'fiscal@example.com'
          }
        }
      }.to change(entity.addresses, :count).by(1)

      expect(entity.reload.addresses.last.tipo).to eq('matriz')
    end
  end

  describe 'DELETE /entities/:entity_id/addresses/:id' do
    it 'blocks deleting the only fiscal address when entity has fiscal profile' do
      create(:fiscal_profile, profileable: entity)
      fiscal_address = create(:address, addressable: entity, tipo: 'matriz')

      expect {
        delete entity_address_path(entity, fiscal_address)
      }.not_to change(Address, :count)

      expect(response).to redirect_to(entity_path(entity))
      expect(flash[:alert]).to include('No se puede eliminar')
    end

    it 'allows deleting a fiscal address when another fiscal address exists' do
      create(:fiscal_profile, profileable: entity)
      delete_candidate = create(:address, addressable: entity, tipo: 'matriz')
      create(:address, addressable: entity, tipo: 'matriz')

      expect {
        delete entity_address_path(entity, delete_candidate)
      }.to change(Address, :count).by(-1)

      expect(response).to redirect_to(edit_entity_path(entity))
      expect(flash[:notice]).to include('eliminada exitosamente')
    end
  end
end
