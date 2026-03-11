class InvoicePaymentEvidence < ApplicationRecord
  STATUSES = %w[pending linked rejected].freeze

  belongs_to :invoice
  belongs_to :customs_agent, class_name: "Entity"
  belongs_to :submitted_by, class_name: "User"
  belongs_to :invoice_payment, optional: true

  has_one_attached :receipt_file

  validates :reference, presence: true, length: { maximum: 120 }
  validates :tracking_key, length: { maximum: 120 }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }
  validates :receipt_file, presence: true

  def self.status_label_for(status)
    I18n.t(
      "activerecord.attributes.invoice_payment_evidence.statuses.#{status}",
      default: status.to_s.humanize
    )
  end

  def status_label
    self.class.status_label_for(status)
  end

  after_create_commit :notify_admins_and_executives

  private

  def notify_admins_and_executives
    recipients = User.joins(:role).where(roles: { name: [ Role::ADMIN, Role::EXECUTIVE ] })

    recipients.find_each do |recipient|
      Notification.create!(
        recipient: recipient,
        actor: submitted_by,
        action: "adjunto comprobante de pago para revision",
        notifiable: self
      )
    end
  end
end
