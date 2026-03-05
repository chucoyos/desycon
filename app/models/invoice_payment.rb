class InvoicePayment < ApplicationRecord
  STATUSES = %w[registered complement_queued complement_issued failed].freeze

  belongs_to :invoice
  belongs_to :complement_invoice, class_name: "Invoice", optional: true

  validates :amount, numericality: { greater_than: 0 }
  validates :currency, inclusion: { in: [ "MXN" ] }
  validates :paid_at, presence: true
  validates :payment_method, inclusion: { in: FiscalProfile::FORMAS_PAGO.keys }
  validates :status, inclusion: { in: STATUSES }
  validates :reference, length: { maximum: 120 }, allow_blank: true
  validates :notes, length: { maximum: 1000 }, allow_blank: true

  scope :recent_first, -> { order(paid_at: :desc, id: :desc) }
end
