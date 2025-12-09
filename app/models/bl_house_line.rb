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
    pendiente_pagos_locales: "pendiente_pagos_locales"
  }

  # Validations
  validates :blhouse, presence: true
  validates :partida, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :cantidad, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :peso, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :volumen, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Callbacks
  after_save :track_status_change

  # Methods
  def documentos_completos?
    bl_endosado_documento.attached? && liberacion_documento.attached? && bl_revalidado_documento.attached?
  end

  private

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
end
