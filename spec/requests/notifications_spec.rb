require 'rails_helper'

RSpec.describe "Notifications", type: :request do
  let(:role) { Role.find_or_create_by(name: "test_role") }
  let(:user) { User.create!(email: "test_user@example.com", password: "password123", password_confirmation: "password123", role: role) }

  before { login_as user }

  describe "GET /notifications" do
    it "displays the notifications page" do
      get notifications_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Notificaciones")
    end

    it "shows user's notifications" do
      notification = Notification.create!(recipient: user, actor: user, notifiable: create_bl_house_line, action: "test action")

      get notifications_path

      expect(response.body).to include("test action")
    end
  end

  describe "revalidation notification styling" do
    it "shows prominent styling for revalidado action" do
      Notification.create!(recipient: user, actor: user, notifiable: create_bl_house_line, action: "revalidado")

      get notifications_path

      expect(response.body).to include("¡Revalidado!")
      expect(response.body).to include("animate-pulse")
      expect(response.body).to include("text-green-600")
    end

    it "shows prominent styling for revalidation request" do
      Notification.create!(recipient: user, actor: user, notifiable: create_bl_house_line, action: "solicitó revalidación")

      get notifications_path

      expect(response.body).to include("Solicitó Revalidación")
      expect(response.body).to include("animate-bounce")
      expect(response.body).to include("text-orange-600")
    end
  end

  describe "marking notifications as read" do
    it "marks notification as read via turbo stream" do
      notification = Notification.create!(recipient: user, actor: user, notifiable: create_bl_house_line, action: "test", read_at: nil)

      expect {
        patch mark_as_read_notification_path(notification), as: :turbo_stream
      }.to change { notification.reload.read? }.from(false).to(true)

      expect(response.media_type).to eq Mime[:turbo_stream]
    end
  end

  describe "deleting notifications" do
    it "deletes notification via turbo stream" do
      notification = Notification.create!(recipient: user, actor: user, notifiable: create_bl_house_line, action: "test")

      expect {
        delete notification_path(notification), as: :turbo_stream
      }.to change(Notification, :count).by(-1)

      expect(response.media_type).to eq Mime[:turbo_stream]
    end
  end

  private

  def create_bl_house_line
    entity = Entity.find_or_create_by(name: "Test Entity") do |e|
      e.is_client = true
    end
    BlHouseLine.create!(blhouse: "TEST#{rand(1000)}", partida: rand(1..100), cantidad: 1, contiene: "test", client: entity)
  end
end
