class BlHouseLine < ApplicationRecord
  # Relationships
  belongs_to :customs_agent, class_name: "Entity", optional: true
  belongs_to :client, class_name: "Entity", optional: true
  belongs_to :container, optional: true
  belongs_to :packaging, optional: true

  # Status history
  has_many :bl_house_line_status_histories, dependent: :destroy

  # Document attachments
  has_one_attached :bl_endosado_documento
  has_one_attached :liberacion_documento
  has_one_attached :bl_revalidado_documento
  has_one_attached :encomienda_documento

  # Enums
  enum :status, {
    activo: "activo",
    bl_original: "bl_original",
    documentos_ok: "documentos_ok",
    despachado: "despachado",
    pendiente_endoso_agente_aduanal: "pendiente_endoso_agente_aduanal",
    pendiente_endoso_consignatario: "pendiente_endoso_consignatario",
    finalizado: "finalizado",
    instrucciones_pendientes: "instrucciones_pendientes",
    pendiente_pagos_locales: "pendiente_pagos_locales",
    listo: "listo",
    revalidado: "revalidado"
  }

  # Validations
  validates :blhouse, presence: true
  validates :partida, presence: true, numericality: { only_integer: true, greater_than: 0 }, unless: -> { container_id.present? && partida.blank? }
  validates :partida, uniqueness: { scope: :container_id, message: "debe ser único dentro del contenedor" }, if: :container_id?
  validates :cantidad, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :peso, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :volumen, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Callbacks
  before_create :capture_current_user
  before_update :capture_current_user
  before_save :assign_next_partida_number, if: -> { partida.blank? && container_id.present? }
  after_create :create_initial_status_history
  after_update :create_status_history, if: :saved_change_to_status?
  def documentos_completos?
    bl_endosado_documento.attached? && liberacion_documento.attached? && bl_revalidado_documento.attached? && encomienda_documento.attached?
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
