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

  describe 'GET /entities/:entity_id/addresses/:id/edit' do
    it 'returns http success' do
      address = create(:address, addressable: entity, tipo: 'matriz')

      get edit_entity_address_path(entity, address)

      expect(response).to have_http_status(:success)
    end
  end

  describe 'PATCH /entities/:entity_id/addresses/:id' do
    it 'updates an address with valid params' do
      address = create(:address, addressable: entity, tipo: 'sucursal', calle: 'Calle Original')

      patch entity_address_path(entity, address), params: {
        address: {
          calle: 'Calle Actualizada',
          pais: 'MX',
          codigo_postal: '01010',
          estado: 'Ciudad de Mexico',
          email: 'actualizado@example.com'
        }
      }

      expect(response).to redirect_to(entity_path(entity))
      expect(flash[:notice]).to eq('Dirección actualizada exitosamente.')
      expect(address.reload.calle).to eq('Calle Actualizada')
      expect(address.email).to eq('actualizado@example.com')
    end

    it 'returns turbo stream in edit context to preserve unsaved entity form fields' do
      address = create(:address, addressable: entity, tipo: 'sucursal', calle: 'Calle Original')

      patch entity_address_path(entity, address), params: {
        context: 'edit',
        address: {
          calle: 'Calle Turbo',
          pais: 'MX',
          codigo_postal: '01010',
          estado: 'Ciudad de Mexico',
          email: 'turbo@example.com'
        }
      }, headers: { 'ACCEPT' => 'text/vnd.turbo-stream.html' }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('turbo-stream action="replace" target="addresses_container"')
      expect(address.reload.calle).to eq('Calle Turbo')
    end

    it 'returns unprocessable_content with invalid params' do
      address = create(:address, addressable: entity, tipo: 'sucursal')

      patch entity_address_path(entity, address), params: {
        address: {
          email: ''
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(address.reload.email).to be_present
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

  describe 'authorization for customs broker users' do
    let(:customs_broker_user) { create(:user, :customs_broker) }

    before do
      sign_out user
      sign_in customs_broker_user, scope: :user
    end

    it 'blocks updating an address from a foreign client' do
      foreign_client = create(:entity, :client)
      foreign_address = create(:address, addressable: foreign_client, tipo: 'matriz', calle: 'Original')

      patch entity_address_path(foreign_client, foreign_address), params: {
        address: {
          calle: 'No permitido',
          pais: 'MX',
          codigo_postal: '01010',
          estado: 'Ciudad de Mexico',
          email: 'denied@example.com'
        }
      }

      expect(response).to redirect_to(customs_agents_dashboard_path)
      expect(foreign_address.reload.calle).to eq('Original')
    end

    it 'allows updating an address from own client' do
      own_client = create(:entity, :client, customs_agent: customs_broker_user.entity)
      own_address = create(:address, addressable: own_client, tipo: 'matriz', calle: 'Original')

      patch entity_address_path(own_client, own_address), params: {
        address: {
          calle: 'Permitido',
          pais: 'MX',
          codigo_postal: '01010',
          estado: 'Ciudad de Mexico',
          email: 'ok@example.com'
        }
      }

      expect(response).to redirect_to(entity_path(own_client))
      expect(own_address.reload.calle).to eq('Permitido')
    end
  end
end
