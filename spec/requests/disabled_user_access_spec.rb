require 'rails_helper'

RSpec.describe "Disabled user access", type: :request do
  let!(:role) { Role.find_or_create_by!(name: Role::EXECUTIVE) }

  it 'redirects disabled users to the blocked page and signs them out' do
    disabled_user = create(:user, role: role, disabled: true)
    sign_in disabled_user

    get containers_path
    expect(response).to redirect_to(blocked_users_path)

    follow_redirect!
    expect(response.body).to include("Acceso deshabilitado")

    get containers_path
    expect(response).to redirect_to(root_path)
  end

  it 'allows enabled users to proceed' do
    user = create(:user, role: role, disabled: false)
    sign_in user

    get containers_path
    expect(response).to have_http_status(:ok)
  end
end
