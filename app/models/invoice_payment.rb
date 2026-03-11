class InvoicePayment < ApplicationRecord
  STATUSES = %w[registered complement_queued complement_issued failed].freeze
  STATUS_LABELS = {
    "registered" => "Registrado",
    "complement_queued" => "Complemento en cola",
    "complement_issued" => "Complemento emitido",
    "failed" => "Fallido"
  }.freeze

  belongs_to :invoice
  belongs_to :complement_invoice, class_name: "Invoice", optional: true
  has_many :invoice_payment_evidences, dependent: :nullify
  has_one_attached :receipt_file

  validates :amount, numericality: { greater_than: 0 }
  validates :currency, inclusion: { in: [ "MXN" ] }
  validates :paid_at, presence: true
  validates :payment_method, inclusion: { in: FiscalProfile::FORMAS_PAGO.keys }
  validates :status, inclusion: { in: STATUSES }
  validates :reference, length: { maximum: 120 }, allow_blank: true
  validates :tracking_key, length: { maximum: 120 }, allow_blank: true
  validates :notes, length: { maximum: 1000 }, allow_blank: true
  validate :cumulative_amount_within_invoice_total

  scope :recent_first, -> { order(paid_at: :desc, id: :desc) }

  def status_label
    STATUS_LABELS[status] || status.to_s.humanize
  end

  private

  def cumulative_amount_within_invoice_total
    return if invoice.blank? || amount.blank?

    existing_total = invoice.invoice_payments.where.not(id: id).sum(:amount).to_d
    new_total = existing_total + amount.to_d
    return if new_total <= invoice.total.to_d

    errors.add(:amount, "excede el total de la factura")
  end
end
