require 'rails_helper'

RSpec.describe 'Turbo frame not found handling', type: :request do
  let(:role) { Role.find_or_create_by(name: 'test_role') }
  let(:user) { User.create!(email: 'turbo_not_found@example.com', password: 'password123', password_confirmation: 'password123', role: role) }

  before { login_as user }

  it 'renders a turbo frame fallback instead of static 404 page' do
    get documents_bl_house_line_path(id: 999_999), headers: { 'Turbo-Frame' => 'revalidation_modal' }

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include('<turbo-frame id="revalidation_modal">')
    expect(response.body).to include('El recurso solicitado ya no existe o fue movido.')
  end
end
