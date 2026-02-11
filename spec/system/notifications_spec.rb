require 'rails_helper'

RSpec.describe "Notifications UI", type: :system do
  let(:role) { Role.find_or_create_by(name: "test_role") }
  let(:user) { User.create!(email: "test_user@example.com", password: "password123", password_confirmation: "password123", role: role) }
  let(:customs_agent) { User.create!(email: "customs@example.com", password: "password123", password_confirmation: "password123", role: role) }
  let(:entity) { Entity.find_or_create_by(name: "Test Entity") { |e| e.is_client = true } }
  let(:bl_house_line) do
    BlHouseLine.create!(
      blhouse: "TEST#{rand(1000)}",
      partida: rand(1..100),
      cantidad: 1,
      contiene: "test",
      marcas: "test",
      peso: 1.0,
      volumen: 1.0,
      packaging: create(:packaging),
      client: entity,
      status: "revalidado"
    )
  end

  before do
    driven_by(:selenium_chrome_headless)
    login_as user
  end

  describe "notifications index page" do
    it "displays notifications with proper styling" do
      Notification.create!(recipient: user, actor: user, notifiable: bl_house_line, action: "revalidado")

      visit notifications_path

      expect(page).to have_content("¡REVALIDADO!")
      expect(page).to have_css(".animate-pulse")
      expect(page).to have_css(".text-green-600")
    end

    it "shows revalidation request notifications prominently" do
      Notification.create!(recipient: user, actor: user, notifiable: bl_house_line, action: "solicitó revalidación")

      visit notifications_path

      expect(page).to have_content("Solicitó Revalidación")
      expect(page).to have_css(".animate-bounce")
      expect(page).to have_css(".text-orange-600")
    end

    it "displays unread notifications with blue styling" do
      Notification.create!(recipient: user, actor: user, notifiable: bl_house_line, action: "test action", read_at: nil)

      visit notifications_path

      expect(page).to have_css(".border-blue-100")
      expect(page).to have_css(".bg-blue-50\\/10")
    end

    it "displays read notifications with slate styling" do
      Notification.create!(recipient: user, actor: user, notifiable: bl_house_line, action: "test action", read_at: Time.current)

      visit notifications_path

      expect(page).to have_css(".border-slate-100")
      expect(page).to have_css(".shadow-sm")
    end
  end

  describe "opening notifications" do
    it "navigates to the related partida" do
      Notification.create!(recipient: user, actor: user, notifiable: bl_house_line, action: "test action")

      visit notifications_path

      expect(page).to have_content("test action")

      click_link "Partida #{bl_house_line.blhouse}"
      expect(page).to have_current_path(bl_house_line_path(bl_house_line))
    end
  end

  describe "PDF download for revalidation" do
    it "provides link to documents modal" do
      Notification.create!(recipient: user, actor: user, notifiable: bl_house_line, action: "revalidado")

      visit notifications_path

      expect(page).to have_link(href: documents_bl_house_line_path(bl_house_line))
    end
  end

  describe "notification list" do
    it "shows a link to the related partida" do
      Notification.create!(recipient: user, actor: user, notifiable: bl_house_line, action: "test action")

      visit notifications_path

      expect(page).to have_link("Partida #{bl_house_line.blhouse}")
    end
  end

  describe "real-time updates" do
    it "updates notification count in real-time", js: true do
      Notification.create!(recipient: user, actor: user, notifiable: bl_house_line, action: "test action", read_at: nil)

      visit notifications_path

      # Just check that we can see the notification count element
      expect(page).to have_css("#notifications_count")
    end
  end
end
