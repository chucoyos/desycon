class Container < ApplicationRecord
  # Asociaciones
  belongs_to :consolidator, optional: true  # Mantener temporalmente para compatibilidad
  belongs_to :consolidator_entity, class_name: "Entity", optional: true
  belongs_to :shipping_line
  belongs_to :vessel
  belongs_to :voyage
  belongs_to :origin_port, class_name: "Port", optional: false

  delegate :destination_port, to: :voyage, allow_nil: true

  # Compatibility setters to allow assigning ports directly on container in legacy code/specs
  def destination_port=(port)
    self.voyage ||= Voyage.new(vessel: vessel)
    voyage.destination_port = port
  end

  def viaje=(code)
    self.voyage ||= Voyage.new(vessel: vessel)
    voyage.viaje = code
  end

  # Legacy accessors
  has_many :container_status_histories, dependent: :destroy
  has_many :container_services, dependent: :destroy
  has_many :bl_house_lines, dependent: :restrict_with_error

  # Active Storage para documentos
  has_one_attached :bl_master_documento
  has_one_attached :tarja_documento

  attr_accessor :tarja_documento_attached_via_setter

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

  enum :container_type, {
    estandar: "estandar",
    high_cube: "high_cube",
    otro: "otro"
  }, prefix: true

  enum :size_ft, {
    ft20: "20",
    ft40: "40"
  }, prefix: true

  RECINTO_OPTIONS_BY_DESTINATION = {
    "manzanillo" => [ "CONTECON", "SSA", "OCUPA", "TIMSA" ],
    "veracruz" => [ "ICAVE", "CICE" ],
    "altamira" => [ "ATP", "IPM" ],
    "lazaro cardenas" => [ "LCTPC TERMINAL PORTUARIA DE CONTENEDORES (HPH)", "APM TERMINALS" ]
  }.freeze

  ALMACEN_OPTIONS_BY_DESTINATION = {
    "manzanillo" => [ "SSA", "OCUPA", "TIMSA", "FRIMAN", "HAZESA" ],
    "veracruz" => [ "CICE", "CICE LA OPCION MAS COMPLETA ", "CIF", "GOLMEX" ],
    "altamira" => [ "SERVICIOS CARRIER INTERPUERTOS" ],
    "lazaro cardenas" => [ "UTTSA RECINTO 173", "LCTPC RECINTO 200" ]
  }.freeze

  # Validaciones
  validates :number,
            presence: true,
            uniqueness: { case_sensitive: false, scope: :bl_master, message: "ya existe para este BL Master" },
            format: {
              with: /\A[A-Z]{4}\d{7}\z/,
              message: "debe tener el formato de contenedor (4 letras seguidas de 7 dígitos)"
            }
  validates :bl_master, presence: true, length: { maximum: 100 }
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :tipo_maniobra, presence: true, inclusion: { in: tipo_maniobras.keys }
  validates :viaje, presence: true, length: { maximum: 50 }
  validates :container_type, presence: true, inclusion: { in: container_types.keys }
  validates :size_ft, presence: true, inclusion: { in: size_fts.keys }
  validates :consolidator_entity, presence: true
  validates :shipping_line, presence: true

  validates :voyage, presence: true
  validates :recinto, length: { maximum: 100 }, presence: true
  validates :almacen, length: { maximum: 100 }, allow_blank: true
  validates :archivo_nr, length: { maximum: 100 }, presence: true
  validates :sello, length: { maximum: 50 }, presence: true
  validates :ejecutivo, length: { maximum: 50 }, presence: true
  validates :vessel, presence: true
  validates :fecha_arribo, presence: true
  validates :origin_port, presence: true

  validate :recinto_matches_destination_for_import, if: :tipo_maniobra_importacion?
  validate :almacen_matches_destination_for_import, if: -> { tipo_maniobra_importacion? && almacen.present? }
  validate :require_documents_for_desconsolidado, if: :status_changing_to_desconsolidado?
  validate :destination_port_present

  # Normalización
  before_validation :normalize_number

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :by_tipo_maniobra, ->(tipo) { where(tipo_maniobra: tipo) }
  scope :by_consolidator, ->(entity_id) { where(consolidator_entity_id: entity_id) }
  scope :by_shipping_line, ->(shipping_line_id) { where(shipping_line_id: shipping_line_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_fecha_arribo, -> { order(fecha_arribo: :desc) }
  scope :with_associations, -> { includes(:consolidator_entity, :shipping_line) }

  # Callbacks para historial de status
  before_create :capture_current_user
  before_update :capture_current_user
  after_create :create_initial_status_history
  after_update :create_status_history, if: :saved_change_to_status?
  after_commit :handle_tarja_uploaded, if: :tarja_documento_recently_attached?

  # Métodos de conveniencia
  def to_s
    number
  end

  def nombre_buque
    vessel&.name || "Sin asignar"
  end

  def nombre_linea_naviera
    shipping_line&.name || "Sin asignar"
  end

  def nombre_consolidador
    consolidator_entity&.name || consolidator&.name || "Sin asignar"
  end

  def nombre_puerto_origen
    origin_port&.display_name
  end

  # Legacy accessors used in views/tests
  def port
    origin_port
  end

  def port=(port)
    self.origin_port = port
  end

  def viaje
    voyage&.viaje
  end

  def self.recinto_options_for_port(port:, tipo_maniobra: "importacion")
    return [] unless tipo_maniobra.to_s == "importacion"

    key = recinto_destination_key(port)
    key ? RECINTO_OPTIONS_BY_DESTINATION[key] : []
  end

  def self.recinto_destination_key(port)
    return nil if port.nil?

    raw_name = port.respond_to?(:name) ? port.name : port
    normalized = ActiveSupport::Inflector.transliterate(raw_name.to_s).downcase
    RECINTO_OPTIONS_BY_DESTINATION.keys.find { |key| normalized.include?(key) }
  end

  def self.recinto_union
    RECINTO_OPTIONS_BY_DESTINATION.values.flatten.uniq
  end

  def self.almacen_options_for_port(port:, tipo_maniobra: "importacion")
    return [] unless tipo_maniobra.to_s == "importacion"

    key = recinto_destination_key(port)
    key ? ALMACEN_OPTIONS_BY_DESTINATION[key] : []
  end

  def self.almacen_union
    ALMACEN_OPTIONS_BY_DESTINATION.values.flatten.uniq
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
    (status_activo? || status_validar_documentos?) && documentos_completos?
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

  def tarja_documento=(attachable)
    super
    self.tarja_documento_attached_via_setter = true if attachable.present?
  end

  def any_bl_house_line_with_attachments?
    bl_house_lines.any?(&:documents_attached?)
  end

  def can_bulk_delete_bl_house_lines?
    bl_house_lines.any? && !any_bl_house_line_with_attachments?
  end

  private

  def recinto_matches_destination_for_import
    dest_port = voyage&.destination_port
    key = Container.recinto_destination_key(dest_port)
    return if key.nil?

    allowed = Container.recinto_options_for_port(port: dest_port, tipo_maniobra: tipo_maniobra)
    return if allowed.include?(recinto)

    errors.add(:recinto, "no es válido para el puerto de destino seleccionado")
  end

  def almacen_matches_destination_for_import
    dest_port = voyage&.destination_port
    key = Container.recinto_destination_key(dest_port)
    return if key.nil?

    allowed = Container.almacen_options_for_port(port: dest_port, tipo_maniobra: tipo_maniobra)
    return if allowed.include?(almacen)

    errors.add(:almacen, "no es válido para el puerto de destino seleccionado")
  end

  def capture_current_user
    @current_user = defined?(Current) && Current.respond_to?(:user) ? Current.user : nil
  end

  def destination_port_present
    return if voyage&.destination_port.present?

    errors.add(:destination_port, "no puede estar en blanco")
  end

  def normalize_number
    return if number.blank?

    cleaned = number.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    self.number = cleaned
  end

  def create_initial_status_history
    container_status_histories.create!(
      status: status,
      fecha_actualizacion: Time.current,
      observaciones: "Contenedor creado",
      user: @current_user
    )
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
        observaciones: "Status actualizado automáticamente",
        user: @current_user
      )
    end
  end

  def tarja_documento_recently_attached?
    return false unless tarja_documento.attached?

    flag = tarja_documento_attached_via_setter
    self.tarja_documento_attached_via_setter = false

    attachment_changes = tarja_documento_attachment&.previous_changes

    flag || attachment_changes.present?
  end

  def handle_tarja_uploaded
    return if status_desconsolidado?
    return unless documentos_completos?

    current_actor = @current_user || (defined?(Current) && Current.respond_to?(:user) ? Current.user : nil)

    cambiar_status!(:desconsolidado, current_actor, "Tarja adjunta automáticamente")

    bl_house_lines
      .where(status: BlHouseLine.statuses[:documentos_ok])
      .find_each do |line|
        next if line.revalidado?
        line.revalidado!
      end
  end

  def status_changing_to_desconsolidado?
    status == "desconsolidado" && (new_record? || will_save_change_to_status?)
  end

  def require_documents_for_desconsolidado
    return if documentos_completos?

    errors.add(:base, "Debe adjuntar tanto el BL Master como la Tarja para cambiar el estatus a desconsolidado.")
  end
end
