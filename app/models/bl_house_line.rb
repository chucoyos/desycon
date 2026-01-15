class BlHouseLine < ApplicationRecord
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

  validates :blhouse, presence: true
  validates :partida, presence: true, numericality: { only_integer: true, greater_than: 0 }, unless: -> { container_id.present? && partida.blank? }
  validates :partida, uniqueness: { scope: :container_id, message: "debe ser único dentro del contenedor" }, if: :container_id?
  validates :cantidad, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :peso, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :volumen, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  attr_accessor :skip_revalidation_notification

  # Callbacks
  before_create :capture_current_user
  before_update :capture_current_user
  before_save :assign_next_partida_number, if: -> { partida.blank? && container_id.present? }
  after_create :create_initial_status_history
  after_update :create_status_history, if: :saved_change_to_status?
  after_update :notify_revalidation_request, if: -> { !skip_revalidation_notification && saved_change_to_status? && validar_documentos? }
  after_update :notify_customs_agent_revalidation, if: -> { saved_change_to_status? && revalidado? }
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
end
