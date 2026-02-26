require 'rails_helper'

RSpec.describe NotificationsController, type: :controller do
  let(:role) { Role.find_or_create_by(name: "test_role") }
  let(:user) { User.create!(email: "test_user@example.com", password: "password123", password_confirmation: "password123", role: role) }

  before do
    allow(controller).to receive(:set_current_user)
    allow(controller).to receive(:redirect_disabled_user)
  end

  def create_bl_house_line
    entity = Entity.find_or_create_by(name: "Test Entity") do |e|
      e.role_kind = "client"
    end
    BlHouseLine.create!(
      blhouse: "TEST#{rand(1000)}",
      partida: rand(100) + 1,
      cantidad: 1,
      contiene: "test",
      marcas: "test",
      peso: 1.0,
      volumen: 1.0,
      packaging: create(:packaging),
      client: entity
    )
  end

  let(:notification) { Notification.create!(recipient: user, actor: user, notifiable: create_bl_house_line, action: "test") }

  describe "GET #index" do
    it "returns http success when authenticated" do
      allow(controller).to receive(:authenticate_user!).and_return(true)
      allow(controller).to receive(:current_user).and_return(user)
      get :index
      expect(response).to have_http_status(:ok)
    end

    it "redirects when not authenticated" do
      get :index
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "PATCH #mark_as_read" do
    before { sign_in user }

    it "marks notification as read" do
      expect {
        patch :mark_as_read, params: { id: notification.id }
      }.to change { notification.reload.read? }.from(false).to(true)
    end

    it "redirects back with html format" do
      patch :mark_as_read, params: { id: notification.id }, format: :html
      expect(response).to redirect_to(notifications_path)
    end
  end

  describe "DELETE #destroy" do
    before { sign_in user }

    it "destroys the notification" do
      notification # ensure it exists
      expect {
        delete :destroy, params: { id: notification.id }
      }.to change(Notification, :count).by(-1)
    end

    it "redirects back with html format" do
      delete :destroy, params: { id: notification.id }, format: :html
      expect(response).to redirect_to(notifications_path)
    end
  end
end
