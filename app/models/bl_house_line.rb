class BlHouseLine < ApplicationRecord
  # Default values
  attribute :clase_imo, :string, default: "0"
  attribute :tipo_imo, :string, default: "0"

  # Relationships
  belongs_to :customs_agent, class_name: "Entity", optional: true
  belongs_to :customs_agent_patent, optional: true
  belongs_to :client, class_name: "Entity", optional: true
  belongs_to :container, optional: true
  belongs_to :packaging, optional: true

  # Status history
  has_many :bl_house_line_status_histories, dependent: :destroy

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
    bl_original: "bl_original",
    documentos_ok: "documentos_ok",
    documentos_rechazados: "documentos_rechazados",
    despachado: "despachado",
    pendiente_endoso_agente_aduanal: "pendiente_endoso_agente_aduanal",
    pendiente_endoso_consignatario: "pendiente_endoso_consignatario",
    finalizado: "finalizado",
    instrucciones_pendientes: "instrucciones_pendientes",
    pendiente_pagos_locales: "pendiente_pagos_locales",
    listo: "listo",
    revalidado: "revalidado",
    validar_documentos: "validar_documentos"
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
  validates :clase_imo, length: { maximum: 4 }, allow_blank: true
  validates :tipo_imo, length: { maximum: 4 }, allow_blank: true

  scope :visible_to_customs_agent, -> { where(hidden_from_customs_agent: false) }

  attr_accessor :skip_revalidation_notification

  # Callbacks
  before_create :capture_current_user
  before_update :capture_current_user
  before_save :assign_next_partida_number, if: -> { partida.blank? && container_id.present? }
  after_create :create_initial_status_history
  after_update :create_status_history, if: :saved_change_to_status?
  after_update :notify_revalidation_request, if: -> { !skip_revalidation_notification && saved_change_to_status? && validar_documentos? }
  after_update :notify_customs_agent_revalidation, if: -> { saved_change_to_status? && revalidado? }
  after_update :ensure_asignacion_electronica_service, if: -> { saved_change_to_status? && revalidado? }
  def documentos_completos?
    bl_endosado_documento.attached? && liberacion_documento.attached? && encomienda_documento.attached?
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

  def required_revalidation_documents
    agent = customs_agent
    return DOCUMENT_FIELDS unless agent

    required = []
    required << :bl_endosado_documento if agent.respond_to?(:requires_bl_endosado_documento?) ? agent.requires_bl_endosado_documento? : true
    required << :liberacion_documento if agent.respond_to?(:requires_liberacion_documento?) ? agent.requires_liberacion_documento? : true
    required << :encomienda_documento if agent.respond_to?(:requires_encomienda_documento?) ? agent.requires_encomienda_documento? : true
    required << :pago_documento if agent.respond_to?(:requires_pago_documento?) ? agent.requires_pago_documento? : true

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
    end
  rescue StandardError => e
    Rails.logger.error("Failed to create asignación electrónica de carga service for BL #{id}: #{e.message}")
  end

  private

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
