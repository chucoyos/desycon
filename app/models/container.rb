class Container < ApplicationRecord
  # Asociaciones
  belongs_to :consolidator
  belongs_to :shipping_line
  belongs_to :vessel, optional: true

  has_many :container_status_histories, dependent: :destroy
  has_many :container_services, dependent: :destroy

  # Active Storage para documentos
  has_one_attached :bl_master_documento
  has_one_attached :tarja_documento

  # Nested attributes
  accepts_nested_attributes_for :container_services, allow_destroy: true, reject_if: :all_blank

  # Enums
  enum :status, {
    activo: "activo",
    validar_documentos: "validar_documentos",
    desconsolidado: "desconsolidado"
  }, prefix: true

  enum :tipo_maniobra, {
    importacion: "importacion",
    exportacion: "exportacion"
  }, prefix: true

  # Validaciones
  validates :number, presence: true, uniqueness: { case_sensitive: false }
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :tipo_maniobra, presence: true, inclusion: { in: tipo_maniobras.keys }
  validates :consolidator, presence: true
  validates :shipping_line, presence: true

  validates :bl_master, length: { maximum: 100 }, allow_blank: true
  validates :puerto_origen, length: { maximum: 100 }, allow_blank: true
  validates :viaje, length: { maximum: 50 }, allow_blank: true
  validates :recinto, length: { maximum: 100 }, allow_blank: true
  validates :archivo_nr, length: { maximum: 100 }, allow_blank: true
  validates :sello, length: { maximum: 50 }, allow_blank: true
  validates :cont_key, length: { maximum: 50 }, allow_blank: true

  # Normalización
  before_validation :normalize_number

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :by_tipo_maniobra, ->(tipo) { where(tipo_maniobra: tipo) }
  scope :by_consolidator, ->(consolidator_id) { where(consolidator_id: consolidator_id) }
  scope :by_shipping_line, ->(shipping_line_id) { where(shipping_line_id: shipping_line_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_fecha_arribo, -> { order(fecha_arribo: :desc) }
  scope :with_associations, -> { includes(:consolidator, :shipping_line, :vessel) }

  # Callbacks para historial de status
  after_update :create_status_history, if: :saved_change_to_status?

  # Métodos de conveniencia
  def to_s
    number
  end

  def nombre_buque
    vessel&.name || "Sin asignar"
  end

  def nombre_linea_naviera
    shipping_line.name
  end

  def nombre_consolidador
    consolidator.name
  end

  # Obtener el último status history
  def last_status_change
    container_status_histories.order(fecha_actualizacion: :desc).first
  end

  # Verificar si tiene documentos completos
  def documentos_completos?
    bl_master_documento.attached? && tarja_documento.attached?
  end

  # Verificar si puede ser desconsolidado
  def puede_desconsolidar?
    status_activo? && documentos_completos?
  end

  # Cambiar status con historial
  def cambiar_status!(new_status, user, observaciones = nil)
    transaction do
      # Marcador para evitar que el callback cree un historial duplicado
      @skip_auto_history = true
      update!(status: new_status)
      container_status_histories.create!(
        status: new_status,
        fecha_actualizacion: Time.current,
        observaciones: observaciones,
        user: user
      )
    end
  ensure
    @skip_auto_history = false
  end

  private

  def normalize_number
    self.number = number.to_s.upcase.strip if number.present?
  end

  def create_status_history
    # No crear historial automático si se está usando cambiar_status!
    return if @skip_auto_history

    # Este método se ejecuta automáticamente después de actualizar el status
    # pero solo si no se creó manualmente con cambiar_status!
    unless container_status_histories.where(
      status: status,
      fecha_actualizacion: Time.current.beginning_of_minute..Time.current.end_of_minute
    ).exists?
      container_status_histories.create!(
        status: status,
        fecha_actualizacion: Time.current,
        observaciones: "Status actualizado automáticamente"
      )
    end
  end
end
