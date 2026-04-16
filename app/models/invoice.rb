require "digest"

class Invoice < ApplicationRecord
  KINDS = %w[ingreso egreso pago].freeze
  STATUSES = %w[draft queued issued cancel_pending cancelled failed].freeze
  PAYMENT_STATUSES = %w[pending partial paid].freeze
  PAYMENT_STATUS_LABELS = {
    "pending" => "Pendiente",
    "partial" => "Parcial",
    "paid" => "Pagado"
  }.freeze
  CANCELLATION_MOTIVES = %w[02].freeze

  belongs_to :invoiceable, polymorphic: true, optional: true
  belongs_to :issuer_entity, class_name: "Entity"
  belongs_to :receiver_entity, class_name: "Entity"
  belongs_to :customs_agent, class_name: "Entity", optional: true

  has_many :invoice_events, dependent: :destroy
  has_many :invoice_payments, dependent: :destroy
  has_many :invoice_payment_evidence_links, dependent: :destroy
  has_many :invoice_payment_evidences, through: :invoice_payment_evidence_links
  has_many :invoice_line_items, -> { order(:position, :id) }, dependent: :destroy
  has_many :invoice_service_links, dependent: :destroy
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
  scope :reconciliation_candidates, -> {
    where(status: %w[cancel_pending issued failed])
      .where.not(sat_uuid: [ nil, "" ])
  }
  scope :prioritized_for_reconciliation, -> {
    order(
      Arel.sql("CASE WHEN invoices.status = 'cancel_pending' THEN 0 ELSE 1 END ASC"),
      Arel.sql("COALESCE(invoices.issued_at, invoices.created_at) DESC")
    )
  }
  scope :with_payment_status, ->(payment_status) {
    next all unless PAYMENT_STATUSES.include?(payment_status)

    paid_total_sql = "COALESCE((SELECT SUM(invoice_payments.amount) FROM invoice_payments WHERE invoice_payments.invoice_id = invoices.id), 0)"

    case payment_status
    when "pending"
      where("#{paid_total_sql} <= 0")
    when "partial"
      where("#{paid_total_sql} > 0 AND #{paid_total_sql} < invoices.total")
    when "paid"
      where("#{paid_total_sql} >= invoices.total")
    else
      all
    end
  }

  def issued?
    status == "issued"
  end

  def failed?
    status == "failed"
  end

  def stamped?
    sat_uuid.present?
  end

  def deletable_non_stamped?
    !stamped?
  end

  def effective_status
    return "issued" if sat_uuid.present? && status == "failed"

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

    paid_total = if has_attribute?(:paid_total_for_index)
      self[:paid_total_for_index].to_d
    elsif association(:invoice_payments).loaded?
      invoice_payments.sum { |payment| payment.amount.to_d }
    else
      invoice_payments.sum(:amount).to_d
    end
    remaining = total.to_d - paid_total
    remaining.positive? ? remaining : 0.to_d
  end

  def payment_method_code
    payload_snapshot.to_h["metodoPago"].to_s.presence || receiver_entity&.fiscal_profile&.metodo_pago.to_s.presence || "PPD"
  end

  def payment_status
    paid_total = invoice_payments.sum(:amount).to_d
    return "pending" unless paid_total.positive?
    return "paid" if paid_total >= total.to_d

    "partial"
  end

  def payment_status_label
    PAYMENT_STATUS_LABELS[payment_status] || payment_status.to_s.humanize
  end

  def payment_complement_eligible?
    payment_registration_eligible? && payment_method_code == FiscalProfile::METODO_PAGO_PPD
  end

  def payment_complement_ineligibility_reason
    return payment_registration_ineligibility_reason if payment_registration_ineligibility_reason.present?
    return "La factura fue emitida con metodoPago #{payment_method_code}; REP solo aplica para PPD." unless payment_method_code == FiscalProfile::METODO_PAGO_PPD

    nil
  end

  def payment_registration_eligible?
    payment_registration_ineligibility_reason.blank?
  end

  def payment_registration_ineligibility_reason
    return "Solo se puede registrar pagos para facturas emitidas." unless effectively_issued?
    return "No se pueden registrar pagos sobre un CFDI de tipo pago." if kind == "pago"
    return "La factura no tiene saldo pendiente por pagar." unless outstanding_amount.positive?

    nil
  end

  def queue_issue!(actor: nil)
    return false unless Facturador::Config.enabled?
    return false if issued?

    payload = Facturador::PayloadBuilder.build(self)

    update!(
      status: "queued",
      payload_snapshot: payload,
      last_error_code: nil,
      last_error_message: nil
    )

    invoice_events.create!(
      event_type: "issue_requested",
      created_by: actor,
      request_payload: payload,
      response_payload: {}
    )
    Facturador::IssueInvoiceJob.perform_later(id)
    true
  end

  def email_delivery_target_entity
    direct_target = target_entity_from_invoiceable(invoiceable)
    return direct_target if direct_target.present?

    linked_target = target_entity_from_service_links
    return linked_target if linked_target.present?

    return customs_agent if customs_agent.present?
    return receiver_entity if receiver_entity&.role_consolidator?

    nil
  end

  def email_delivery_recipients
    target_entity = email_delivery_target_entity
    return [] if target_entity.blank?

    target_entity.delivery_email_recipients
  end

  def email_delivery_recipients_csv
    email_delivery_recipients.join(";")
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
      provider_response: merged_provider_response(provider_response),
      last_error_code: nil,
      last_error_message: nil
    )
  end

  def mark_cancelled!(cancelled_at:, provider_response: {})
    update!(
      status: "cancelled",
      cancelled_at: cancelled_at,
      provider_response: merged_provider_response(provider_response),
      last_error_code: nil,
      last_error_message: nil
    )
  end

  def mark_cancel_pending!(motive:, replacement_uuid: nil, provider_response: {})
    update!(
      status: "cancel_pending",
      cancellation_motive: motive,
      replacement_uuid: replacement_uuid,
      provider_response: merged_provider_response(provider_response),
      last_error_code: nil,
      last_error_message: nil
    )
  end

  def mark_cancel_failed_attempt!(error_code:, error_message:, provider_response: {})
    update!(
      status: "issued",
      last_error_code: error_code,
      last_error_message: error_message,
      provider_response: merged_provider_response(provider_response)
    )
  end

  private

  def target_entity_from_invoiceable(record)
    case record
    when ContainerService
      record.container&.consolidator_entity
    when BlHouseLineService
      record.bl_house_line&.customs_agent
    else
      nil
    end
  end

  def target_entity_from_service_links
    links = invoice_service_links.includes(:serviceable)
    return nil if links.empty?

    serviceables = links.map(&:serviceable).compact
    return nil if serviceables.empty?

    types = serviceables.map(&:class).uniq
    return nil if types.size > 1

    target_entity_from_invoiceable(serviceables.first)
  end

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

  def merged_provider_response(new_response)
    existing = provider_response.to_h.deep_stringify_keys
    incoming = new_response.to_h.deep_stringify_keys
    return existing if incoming.blank?

    # Cancellation responses can omit folio/serie; keep the issued values for UI continuity.
    %w[serie folio noComprobante numeroComprobante idComprobante uuid].each do |key|
      incoming[key] = existing[key] if incoming[key].blank? && existing[key].present?
    end

    existing.merge(incoming)
  end
end
