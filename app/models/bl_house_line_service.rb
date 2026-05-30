class BlHouseLineService < ApplicationRecord
  BILLING_LOCK_STATUSES = %w[queued issued cancel_pending cancelled].freeze
  AUTO_ISSUE_ORIGIN_STATUS_TRANSITION = "status_transition".freeze
  LABEL_TAGGING_SERVICE_CODES = %w[BL-ETIADH BL-ETICOS].freeze
  FORMULA_AMOUNT_SERVICE_CODES = %w[BL-ENTCAM BL-PREVIO BL-RECASU BL-ALMA].freeze

  belongs_to :bl_house_line
  belongs_to :service_catalog
  belongs_to :billed_to_entity, class_name: "Entity", optional: true
  has_many :invoices, as: :invoiceable, dependent: :nullify
  has_many :invoice_service_links, as: :serviceable, dependent: :destroy

  before_validation :assign_default_billed_to_entity
  before_validation :assign_default_quantity
  before_validation :assign_quantity_based_amount_for_standard_services
  before_validation :assign_default_amount
  before_validation :assign_formula_amount_for_bl_services
  before_update :prevent_changes_if_facturado
  before_destroy :prevent_destroy_if_facturado, prepend: true
  after_commit :enqueue_facturador_auto_issue, on: :create

  validates :service_catalog, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :currency, presence: true, inclusion: { in: [ "MXN" ] }
  validates :observaciones, length: { maximum: 1000 }, allow_blank: true
  validates :factura, length: { maximum: 100 }, allow_blank: true
  validate :prevent_manual_storage_service_within_grace_period, on: :create
  validate :quantity_required_for_label_tagging_services

  scope :facturados, -> { where.not(factura: nil) }
  scope :pendientes, -> { where(factura: nil) }
  scope :by_fecha_programada, -> { order(fecha_programada: :asc) }

  def facturado?
    factura.present? || billed_by_invoice?
  end

  def pendiente?
    !facturado?
  end

  def latest_invoice
    direct_invoice = invoices.recent_first.first
    linked_invoice = Invoice.joins(:invoice_service_links)
                          .where(invoice_service_links: { serviceable_type: self.class.name, serviceable_id: id })
                          .recent_first
                          .first

    [ direct_invoice, linked_invoice ].compact.max_by(&:created_at)
  end

  def currency
    service_catalog&.currency
  end

  private

  def enqueue_facturador_auto_issue
    return unless Facturador::Config.enabled?
    return unless Facturador::Config.auto_issue_enabled?
    return unless auto_issue_origin_for_status_transition?

    Facturador::AutoIssueService.call(invoiceable: self, actor: Current.user)
  end

  def auto_issue_origin_for_status_transition?
    creation_origin.to_s == AUTO_ISSUE_ORIGIN_STATUS_TRANSITION
  end

  def assign_default_billed_to_entity
    return if billed_to_entity_id.present?

    self.billed_to_entity_id = bl_house_line&.client_id
  end

  def assign_default_quantity
    return if quantity.present?
    return if label_tagging_service_code?

    self.quantity = 1
  end

  def assign_default_amount
    return if amount.present?

    self.amount = service_catalog&.amount
  end

  def assign_formula_amount_for_bl_services
    return if service_catalog.blank? || bl_house_line.blank?

    case service_catalog.code.to_s
    when "BL-ENTCAM", "BL-PREVIO", "BL-RECASU"
      self.amount = entcam_charge_result.total
    when "BL-ALMA"
      result = storage_charge_result
      return if result.blank? || result.billable_days <= 0

      self.amount = result.total
    when *LABEL_TAGGING_SERVICE_CODES
      result = label_tagging_charge_result
      return if result.blank?

      self.amount = result.total
    end
  end

  def assign_quantity_based_amount_for_standard_services
    return if service_catalog.blank?
    return unless quantity_driven_service_code?
    if new_record? && amount.present?
      quantity_value = quantity.to_i
      catalog_amount = service_catalog.amount.to_d.round(2)
      provided_amount = amount.to_d.round(2)

      # Preserve intentional manual amount on create, but if amount was just
      # autofilled from catalog and quantity > 1, compute the expected total.
      return unless quantity_value > 1 && provided_amount == catalog_amount
    end
    return unless will_save_change_to_quantity? || amount.blank?

    self.amount = (quantity.to_i * service_catalog.amount.to_d).round(2)
  end

  def quantity_required_for_label_tagging_services
    return unless label_tagging_service_code?
    return if quantity.present?

    errors.add(:quantity, "no puede estar en blanco")
  end

  def prevent_manual_storage_service_within_grace_period
    return unless service_catalog&.code.to_s == "BL-ALMA"
    return if auto_issue_origin_for_status_transition?

    result = storage_charge_result
    return if result.blank?
    return if result.billable_days.positive?

    errors.add(:base, "No se puede crear BL-ALMA durante periodo de gracia.")
  end

  def prevent_changes_if_facturado
    return unless locked_for_modification?
    return if changes.except("updated_at").blank?

    errors.add(:base, "No se puede editar un servicio facturado.")
    throw :abort
  end

  def prevent_destroy_if_facturado
    return unless locked_for_modification?

    errors.add(:base, "No se puede eliminar un servicio facturado.")
    throw :abort
  end

  def locked_for_modification?
    return false if latest_invoice&.status == "cancelled"

    factura_in_database.present? || billed_by_invoice?
  end

  def billed_by_invoice?
    direct_billing = invoices.where(status: BILLING_LOCK_STATUSES).exists?
    return true if direct_billing

    Invoice.joins(:invoice_service_links)
      .where(invoice_service_links: { serviceable_type: self.class.name, serviceable_id: id })
      .where(status: BILLING_LOCK_STATUSES)
      .exists?
  end

  def entcam_charge_result
    BlHouseLines::EntregaAlmacenCamionCalculator.call(
      bl_house_line: bl_house_line,
      unit_price: service_catalog.amount
    )
  end

  def storage_charge_result
    BlHouseLines::StorageChargeCalculator.call(
      bl_house_line: bl_house_line,
      desconsolidation_date: bl_house_line.container&.fecha_desconsolidacion,
      dispatch_date: bl_house_line.fecha_despacho,
      unit_price: service_catalog.amount
    )
  end

  def label_tagging_charge_result
    BlHouseLines::LabelTaggingChargeCalculator.call(
      service_code: service_catalog.code,
      quantity: quantity,
      unit_price: service_catalog.amount
    )
  end

  def label_tagging_service_code?
    LABEL_TAGGING_SERVICE_CODES.include?(service_catalog&.code.to_s)
  end

  def formula_amount_service_code?
    FORMULA_AMOUNT_SERVICE_CODES.include?(service_catalog&.code.to_s)
  end

  def quantity_driven_service_code?
    !formula_amount_service_code? && !label_tagging_service_code?
  end
end
