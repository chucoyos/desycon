require "digest"

class Invoice < ApplicationRecord
  KINDS = %w[ingreso egreso pago].freeze
  STATUSES = %w[draft queued issued cancel_pending cancelled failed].freeze
  CANCELLATION_MOTIVES = %w[02].freeze

  belongs_to :invoiceable, polymorphic: true, optional: true
  belongs_to :issuer_entity, class_name: "Entity"
  belongs_to :receiver_entity, class_name: "Entity"
  belongs_to :customs_agent, class_name: "Entity", optional: true

  has_many :invoice_events, dependent: :destroy
  has_many :invoice_payments, dependent: :destroy
  has_many :invoice_line_items, -> { order(:position, :id) }, dependent: :destroy
  has_many :payment_complements, class_name: "InvoicePayment", foreign_key: :complement_invoice_id, dependent: :nullify
  has_one_attached :xml_file
  has_one_attached :pdf_file

  before_validation :ensure_idempotency_key

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :currency, presence: true, inclusion: { in: [ "MXN" ] }
  validates :subtotal, :tax_total, :total, numericality: { greater_than_or_equal_to: 0 }
  validates :idempotency_key, presence: true, uniqueness: true
  validates :sat_uuid, uniqueness: true, allow_blank: true
  validates :facturador_comprobante_id, uniqueness: true, allow_nil: true
  validates :cancellation_motive, inclusion: { in: CANCELLATION_MOTIVES }, allow_blank: true
  validate :customs_agent_must_be_agency_when_present

  scope :recent_first, -> { order(created_at: :desc) }
  scope :issued, -> { where(status: "issued") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :pending_reconciliation, -> { where(status: "cancel_pending").where.not(sat_uuid: [ nil, "" ]) }

  def issued?
    status == "issued"
  end

  def failed?
    status == "failed"
  end

  def effective_status
    return "issued" if sat_uuid.present? && status != "cancelled" && status.in?(%w[failed cancel_pending])

    status
  end

  def effectively_issued?
    effective_status == "issued"
  end

  def cancel_retryable?
    issued? || (failed? && sat_uuid.present? && last_error_code.to_s.start_with?("FACTURADOR_CANCEL_"))
  end

  def outstanding_amount
    return 0.to_d unless issued?

    paid_total = invoice_payments.sum(:amount).to_d
    remaining = total.to_d - paid_total
    remaining.positive? ? remaining : 0.to_d
  end

  def queue_issue!(actor: nil)
    return false unless Facturador::Config.enabled?
    return false if issued?

    mark_queued!
    invoice_events.create!(
      event_type: "issue_requested",
      created_by: actor,
      request_payload: payload_snapshot,
      response_payload: {}
    )
    Facturador::IssueInvoiceJob.perform_later(id)
    true
  end

  def mark_queued!
    update!(status: "queued", last_error_code: nil, last_error_message: nil)
  end

  def mark_failed!(error_code:, error_message:, provider_response: {})
    update!(
      status: "failed",
      last_error_code: error_code,
      last_error_message: error_message,
      provider_response: provider_response
    )
  end

  def mark_issued!(uuid:, comprobante_id:, issued_at:, provider_response: {})
    update!(
      status: "issued",
      sat_uuid: uuid,
      facturador_comprobante_id: comprobante_id,
      issued_at: issued_at,
      provider_response: provider_response,
      last_error_code: nil,
      last_error_message: nil
    )
  end

  def mark_cancelled!(cancelled_at:, provider_response: {})
    update!(
      status: "cancelled",
      cancelled_at: cancelled_at,
      provider_response: provider_response,
      last_error_code: nil,
      last_error_message: nil
    )
  end

  def mark_cancel_pending!(motive:, replacement_uuid: nil, provider_response: {})
    update!(
      status: "cancel_pending",
      cancellation_motive: motive,
      replacement_uuid: replacement_uuid,
      provider_response: provider_response,
      last_error_code: nil,
      last_error_message: nil
    )
  end

  def mark_cancel_failed_attempt!(error_code:, error_message:, provider_response: {})
    update!(
      status: "issued",
      last_error_code: error_code,
      last_error_message: error_message,
      provider_response: provider_response
    )
  end

  private

  def ensure_idempotency_key
    return if idempotency_key.present?

    fingerprint = [ invoiceable_type, invoiceable_id, receiver_entity_id, kind, total.to_s, Time.current.to_f ].join(":")
    self.idempotency_key = Digest::SHA256.hexdigest(fingerprint)
  end

  def customs_agent_must_be_agency_when_present
    return if customs_agent.blank?
    return if customs_agent.role_customs_agent?

    errors.add(:customs_agent, "debe ser una agencia aduanal")
  end
end
