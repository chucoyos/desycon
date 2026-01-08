require 'rails_helper'

RSpec.describe Notification, type: :model do
  let(:role) { Role.find_or_create_by(name: "test_role") }
  let(:user) { User.create!(email: "test_user@example.com", password: "password123", password_confirmation: "password123", role: role) }
  let(:actor) { User.create!(email: "test_actor@example.com", password: "password123", password_confirmation: "password123", role: role) }
  let(:entity) { Entity.create!(name: "Test Entity", is_client: true) }
  let(:bl_house_line) { BlHouseLine.create!(blhouse: "TEST001", partida: 1, cantidad: 1, contiene: "test", client: entity) }

  describe "associations" do
    it "belongs to recipient" do
      association = Notification.reflect_on_association(:recipient)
      expect(association.macro).to eq(:belongs_to)
      expect(association.class_name).to eq("User")
    end

    it "belongs to actor" do
      association = Notification.reflect_on_association(:actor)
      expect(association.macro).to eq(:belongs_to)
      expect(association.class_name).to eq("User")
    end

    it "belongs to notifiable" do
      association = Notification.reflect_on_association(:notifiable)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:polymorphic]).to be true
    end
  end

  describe "scopes" do
    let!(:read_notification) { Notification.create!(recipient: user, actor: actor, notifiable: bl_house_line, action: "test", read_at: Time.current) }
    let!(:unread_notification) { Notification.create!(recipient: user, actor: actor, notifiable: bl_house_line, action: "test", read_at: nil) }
    let!(:old_notification) { Notification.create!(recipient: user, actor: actor, notifiable: bl_house_line, action: "test", created_at: 1.day.ago) }
    let!(:new_notification) { Notification.create!(recipient: user, actor: actor, notifiable: bl_house_line, action: "test", created_at: Time.current) }

    describe ".unread" do
      it "returns only unread notifications" do
        expect(Notification.unread).to include(unread_notification)
        expect(Notification.unread).not_to include(read_notification)
      end
    end

    describe ".recent" do
      it "orders notifications by created_at descending" do
        expect(Notification.recent.first).to eq(new_notification)
        expect(Notification.recent.last).to eq(old_notification)
      end
    end
  end

  describe "#read?" do
    context "when read_at is present" do
      let(:notification) { Notification.create!(recipient: user, actor: actor, notifiable: bl_house_line, action: "test", read_at: Time.current) }

      it "returns true" do
        expect(notification.read?).to be true
      end
    end

    context "when read_at is nil" do
      let(:notification) { Notification.create!(recipient: user, actor: actor, notifiable: bl_house_line, action: "test", read_at: nil) }

      it "returns false" do
        expect(notification.read?).to be false
      end
    end
  end

  describe "#mark_as_read!" do
    let(:notification) { Notification.create!(recipient: user, actor: actor, notifiable: bl_house_line, action: "test", read_at: nil) }

    it "sets read_at to current time" do
      expect {
        notification.mark_as_read!
      }.to change { notification.read_at }.from(nil)
    end

    it "makes the notification read" do
      expect {
        notification.mark_as_read!
      }.to change { notification.read? }.from(false).to(true)
    end
  end

  describe "broadcasting" do
    let(:notification) { build(:notification, recipient: user, actor: actor, notifiable: bl_house_line) }

    it "broadcasts to recipient after create" do
      expect(notification).to receive(:broadcast_replace_to).with(
        "notifications_#{user.id}",
        target: "notifications_count",
        partial: "notifications/count",
        locals: { unread_count: user.notifications.unread.count + 1 } # +1 because the notification will be created
      )

      notification.save
    end
  end

  describe "creation" do
    it "is valid with required attributes" do
      notification = build(:notification, recipient: user, actor: actor, notifiable: bl_house_line)
      expect(notification).to be_valid
    end

    it "requires recipient" do
      notification = build(:notification, recipient: nil)
      expect(notification).not_to be_valid
    end

    it "requires actor" do
      notification = build(:notification, actor: nil)
      expect(notification).not_to be_valid
    end
  end
end
