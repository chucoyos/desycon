class BlHouseLine < ApplicationRecord
  # Default values
  attribute :clase_imo, :string, default: "0"
  attribute :tipo_imo, :string, default: "0"

  # Relationships
  belongs_to :customs_agent, class_name: "Entity", optional: true
  belongs_to :customs_broker, class_name: "Entity", optional: true
  belongs_to :client, class_name: "Entity", optional: true
  belongs_to :container, optional: true
  belongs_to :packaging, optional: true

  # Status history
  has_many :bl_house_line_status_histories, dependent: :destroy
  has_many :photos, as: :attachable, dependent: :destroy

  # Document attachments
  has_one_attached :bl_endosado_documento
  has_one_attached :liberacion_documento
  has_one_attached :encomienda_documento
  has_one_attached :pago_documento

  DOCUMENT_FIELDS = %i[bl_endosado_documento liberacion_documento encomienda_documento pago_documento].freeze

  has_many :bl_house_line_services, dependent: :destroy
  accepts_nested_attributes_for :bl_house_line_services, allow_destroy: true, reject_if: :all_blank

  # Enums
  enum :status, {
    activo: "activo",
    validar_documentos: "validar_documentos",
    instrucciones_pendientes: "instrucciones_pendientes",
    documentos_ok: "documentos_ok",
    revalidado: "revalidado",
    despachado: "despachado"
  }

  # Validations

  validates :blhouse, presence: true, uniqueness: { case_sensitive: false, scope: :container_id, message: "ya existe" }
  validates :partida, presence: true, numericality: { only_integer: true, greater_than: 0 }, unless: -> { container_id.present? && partida.blank? }
  validates :partida, uniqueness: { scope: :container_id, message: "debe ser único dentro del contenedor" }, if: :container_id?
  validates :cantidad, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :packaging, presence: true
  validates :contiene, presence: true
  validates :marcas, presence: true
  validates :peso, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :volumen, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :clase_imo, presence: true, length: { maximum: 4 }
  validates :tipo_imo, presence: true, length: { maximum: 4 }
  validate :broker_matches_agency

  scope :visible_to_customs_agent, -> { where(hidden_from_customs_agent: false) }

  attr_accessor :skip_revalidation_notification

  # Callbacks
  before_validation :normalize_imo_fields
  before_create :capture_current_user
  before_update :capture_current_user
  before_save :assign_next_partida_number, if: -> { partida.blank? && container_id.present? }
  after_create :create_initial_status_history
  after_update :create_status_history, if: :saved_change_to_status?
  after_update :notify_revalidation_request, if: -> { !skip_revalidation_notification && saved_change_to_status? && validar_documentos? }
  after_update :notify_customs_agent_revalidation, if: -> { saved_change_to_status? && revalidado? }
  after_update :ensure_asignacion_electronica_service, if: -> { saved_change_to_status? && revalidado? }
  after_update :ensure_storage_service_on_despachado, if: -> { saved_change_to_status? && despachado? }
  after_update :ensure_entcam_service_on_despachado, if: -> { saved_change_to_status? && despachado? }
  after_update :recalculate_storage_service_if_needed, if: :storage_recalculation_triggered?
  after_update :recalculate_entcam_service_if_needed, if: :storage_recalculation_triggered?
  after_update :recalculate_previo_service_if_needed, if: :storage_recalculation_triggered?
  after_update :recalculate_recasu_service_if_needed, if: :storage_recalculation_triggered?
  def documentos_completos?
    required_revalidation_documents.all? { |field| public_send(field).attached? }
  end

  def document_validated?(doc_sym)
    flag_attribute = "#{doc_sym}_validated".to_sym
    respond_to?(flag_attribute) && public_send(flag_attribute)
  end

  def notify_revalidation_request
    role_names = [ Role::ADMIN, Role::EXECUTIVE ]
    recipients = User.joins(:role).where(roles: { name: role_names })

    if recipients.empty?
      Rails.logger.warn "No recipients found for revalidation notification. Roles searched: #{role_names}"
    end

    actor = @current_user || (defined?(Current) && Current.respond_to?(:user) ? Current.user : nil)

    recipients.each do |recipient|
      Notification.create(
        recipient: recipient,
        actor: actor,
        action: "solicitó revalidación",
        notifiable: self
      )
    end
  end

  def documents_attached?
    DOCUMENT_FIELDS.any? { |field| public_send(field).attached? }
  end

  def imo_double_charge_applicable?
    clase_imo.to_s.strip != "0" && tipo_imo.to_s.strip != "0"
  end

  def imo_charge_multiplier
    imo_double_charge_applicable? ? 2.to_d : 1.to_d
  end

  def required_revalidation_documents
    consolidator = container&.consolidator_entity
    return DOCUMENT_FIELDS unless consolidator

    required = []
    required << :bl_endosado_documento if consolidator.respond_to?(:requires_bl_endosado_documento?) ? consolidator.requires_bl_endosado_documento? : true
    required << :liberacion_documento if consolidator.respond_to?(:requires_liberacion_documento?) ? consolidator.requires_liberacion_documento? : true
    required << :encomienda_documento if consolidator.respond_to?(:requires_encomienda_documento?) ? consolidator.requires_encomienda_documento? : true
    required << :pago_documento if consolidator.respond_to?(:requires_pago_documento?) ? consolidator.requires_pago_documento? : true

    required.presence || DOCUMENT_FIELDS
  end

  def notify_customs_agent_revalidation
    return unless customs_agent_id.present?

    recipients = User.where(entity_id: customs_agent_id)
    actor = @current_user || (defined?(Current) && Current.respond_to?(:user) ? Current.user : nil)

    recipients.each do |recipient|
      Notification.create(
        recipient: recipient,
        actor: actor,
        action: "revalidado",
        notifiable: self
      )
    end
  end

  def ensure_asignacion_electronica_service
    catalog = ServiceCatalog.find_by(name: "Asignación electrónica de carga", applies_to: "bl_house_line")
    return unless catalog

    bl_house_line_services.find_or_create_by(service_catalog: catalog) do |service|
      service.billed_to_entity_id ||= client_id
      service.creation_origin = BlHouseLineService::AUTO_ISSUE_ORIGIN_STATUS_TRANSITION
    end
  rescue StandardError => e
    Rails.logger.error("Failed to create asignación electrónica de carga service for BL #{id}: #{e.message}")
  end

  def ensure_storage_service_on_despachado
    catalog = storage_catalog
    return unless catalog

    result = storage_charge_result(unit_price: catalog.amount)
    if result.blank?
      Rails.logger.warn("Storage service skipped for BL #{id}: missing dispatch or desconsolidation date")
      return
    end

    if result.billable_days <= 0
      Rails.logger.info("Storage service skipped for BL #{id}: within grace period")
      return
    end

    service = bl_house_line_services.find_or_initialize_by(service_catalog: catalog)

    if service.persisted? && service.facturado?
      Rails.logger.info("Storage service unchanged for BL #{id}: already invoiced")
      return
    end

    service.billed_to_entity_id ||= client_id
    service.amount = result.total
    service.save! if service.new_record? || service.changed?
  rescue StandardError => e
    Rails.logger.error("Failed to create/update storage service for BL #{id}: #{e.message}")
  end

  def recalculate_storage_service_if_needed
    catalog = storage_catalog
    return unless catalog

    service = bl_house_line_services.find_by(service_catalog: catalog)
    return unless service
    return if service.facturado?

    result = storage_charge_result(unit_price: catalog.amount)
    if result.blank?
      Rails.logger.warn("Storage service recalculation skipped for BL #{id}: missing dispatch or desconsolidation date")
      return
    end

    if result.billable_days <= 0
      service.destroy!
      Rails.logger.info("Storage service removed for BL #{id}: within grace period")
      return
    end

    service.amount = result.total
    service.save! if service.changed?
  rescue StandardError => e
    Rails.logger.error("Failed to recalculate storage service for BL #{id}: #{e.message}")
  end

  def ensure_entcam_service_on_despachado
    catalog = entcam_catalog
    unless catalog
      Rails.logger.warn("ENTCAM service skipped for BL #{id}: missing catalog BL-ENTCAM")
      return
    end

    service = bl_house_line_services.find_or_initialize_by(service_catalog: catalog)

    if service.persisted? && service.facturado?
      Rails.logger.info("ENTCAM service unchanged for BL #{id}: already invoiced")
      return
    end

    result = entcam_charge_result(unit_price: catalog.amount)
    service.billed_to_entity_id ||= client_id
    service.amount = result.total
    service.save! if service.new_record? || service.changed?
  rescue StandardError => e
    Rails.logger.error("Failed to create/update ENTCAM service for BL #{id}: #{e.message}")
  end

  def recalculate_entcam_service_if_needed
    catalog = entcam_catalog
    return unless catalog

    service = bl_house_line_services.find_by(service_catalog: catalog)
    return unless service
    return if service.facturado?

    result = entcam_charge_result(unit_price: catalog.amount)
    service.amount = result.total
    service.save! if service.changed?
  rescue StandardError => e
    Rails.logger.error("Failed to recalculate ENTCAM service for BL #{id}: #{e.message}")
  end

  def recalculate_previo_service_if_needed
    catalog = previo_catalog
    return unless catalog

    service = bl_house_line_services.find_by(service_catalog: catalog)
    return unless service
    return if service.facturado?

    result = entcam_charge_result(unit_price: catalog.amount)
    service.amount = result.total
    service.save! if service.changed?
  rescue StandardError => e
    Rails.logger.error("Failed to recalculate PREVIO service for BL #{id}: #{e.message}")
  end

  def recalculate_recasu_service_if_needed
    catalog = recasu_catalog
    return unless catalog

    service = bl_house_line_services.find_by(service_catalog: catalog)
    return unless service
    return if service.facturado?

    result = entcam_charge_result(unit_price: catalog.amount)
    service.amount = result.total
    service.save! if service.changed?
  rescue StandardError => e
    Rails.logger.error("Failed to recalculate RECASU service for BL #{id}: #{e.message}")
  end

  def broker_matches_agency
    return if customs_broker_id.blank? || customs_agent_id.blank?

    unless AgencyBroker.exists?(agency_id: customs_agent_id, broker_id: customs_broker_id)
      errors.add(:customs_broker_id, "no pertenece a la agencia seleccionada")
    end
  end

  private

  def normalize_imo_fields
    self.clase_imo = normalize_imo_value(clase_imo)
    self.tipo_imo = normalize_imo_value(tipo_imo)
  end

  def normalize_imo_value(value)
    normalized = value.to_s.strip
    normalized.present? ? normalized : "0"
  end

  def storage_recalculation_triggered?
    saved_change_to_peso? ||
      saved_change_to_volumen? ||
      saved_change_to_fecha_despacho? ||
      saved_change_to_clase_imo? ||
      saved_change_to_tipo_imo?
  end

  def storage_catalog
    ServiceCatalog.active.find_by(code: "BL-ALMA", applies_to: "bl_house_line")
  end

  def entcam_catalog
    ServiceCatalog.active.find_by(code: "BL-ENTCAM", applies_to: "bl_house_line")
  end

  def previo_catalog
    ServiceCatalog.active.find_by(code: "BL-PREVIO", applies_to: "bl_house_line")
  end

  def recasu_catalog
    ServiceCatalog.active.find_by(code: "BL-RECASU", applies_to: "bl_house_line")
  end

  def storage_charge_result(unit_price:)
    BlHouseLines::StorageChargeCalculator.call(
      bl_house_line: self,
      desconsolidation_date: container&.fecha_desconsolidacion,
      dispatch_date: fecha_despacho,
      unit_price: unit_price
    )
  end

  def entcam_charge_result(unit_price:)
    BlHouseLines::EntregaAlmacenCamionCalculator.call(
      bl_house_line: self,
      unit_price: unit_price
    )
  end

  def assign_next_partida_number
    return if partida.present? || container_id.blank?

    self.partida = next_available_partida_number
  end

  def next_available_partida_number
    return 1 if container.blank?

    max_partida = container.bl_house_lines.maximum(:partida) || 0
    max_partida + 1
  end

  def track_status_change
    return unless saved_change_to_status?

    BlHouseLineStatusHistory.create!(
      bl_house_line: self,
      status: self.status,
      previous_status: status_before_last_save,
      changed_at: Time.current,
      changed_by: defined?(Current) && Current.respond_to?(:user) ? Current.user : nil
    )
  end

  private

  def capture_current_user
    @current_user = defined?(Current) && Current.respond_to?(:user) ? Current.user : nil
  end

  def assign_next_partida_number
    return if partida.present? || container_id.blank?

    self.partida = next_available_partida_number
  end

  def next_available_partida_number
    return 1 if container.blank?

    max_partida = container.bl_house_lines.maximum(:partida) || 0
    max_partida + 1
  end

  def create_initial_status_history
    BlHouseLineStatusHistory.create!(
      bl_house_line: self,
      status: status,
      previous_status: nil,
      changed_at: Time.current,
      user: @current_user
    )
  end

  def create_status_history
    BlHouseLineStatusHistory.create!(
      bl_house_line: self,
      status: status,
      previous_status: status_before_last_save,
      changed_at: Time.current,
      user: @current_user
    )
  end
end
