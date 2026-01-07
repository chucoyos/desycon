class Notification < ApplicationRecord
  belongs_to :recipient, class_name: "User"
  belongs_to :actor, class_name: "User"
  belongs_to :notifiable, polymorphic: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  after_create_commit :broadcast_to_recipient

  def read?
    read_at.present?
  end

  def mark_as_read!
    update(read_at: Time.current)
  end

  private

  def broadcast_to_recipient
    broadcast_replace_to(
      "notifications_#{recipient_id}", 
      target: "notifications_count", 
      partial: "notifications/count", 
      locals: { unread_count: recipient.notifications.unread.count }
    )
    # Also optionally push to the list if they are on the index page
    # broadcast_prepend_to "notifications_#{recipient_id}", target: "notifications_list", partial: "notifications/notification", locals: { notification: self }
  end
end
