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
  validate :cumulative_amount_within_invoice_total

  scope :recent_first, -> { order(paid_at: :desc, id: :desc) }

  private

  def cumulative_amount_within_invoice_total
    return if invoice.blank? || amount.blank?

    existing_total = invoice.invoice_payments.where.not(id: id).sum(:amount).to_d
    new_total = existing_total + amount.to_d
    return if new_total <= invoice.total.to_d

    errors.add(:amount, "excede el total de la factura")
  end
end
