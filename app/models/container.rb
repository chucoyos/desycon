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

  attr_accessor :tarja_documento_attached_via_setter, :bl_master_documento_attached_via_setter

  # Nested attributes
  accepts_nested_attributes_for :container_services, allow_destroy: true, reject_if: :all_blank

  # Enums
  enum :status, {
    activo: "activo",
    bl_revalidado: "bl_revalidado",
    fecha_tentativa_desconsolidacion: "fecha_tentativa_desconsolidacion",
    cita_transferencia: "cita_transferencia",
    descargado: "descargado",
    desconsolidado: "desconsolidado"
  }, prefix: true

  enum :tentativa_turno, { primer_turno: 0, segundo_turno: 1, tercer_turno: 2 }, prefix: true

  enum :tipo_maniobra, {
    importacion: "importacion",
    exportacion: "exportacion"
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
  validates :type_size, presence: true, length: { maximum: 50 }
  validates :consolidator_entity, presence: true
  validates :shipping_line, presence: true

  validates :voyage, presence: true
  validates :recinto, length: { maximum: 100 }, presence: true
  validates :almacen, length: { maximum: 100 }, allow_blank: true
  validates :archivo_nr, length: { maximum: 100 }, presence: true
  validates :sello, length: { maximum: 50 }, presence: true
  validates :ejecutivo, length: { maximum: 50 }, presence: true
  validates :vessel, presence: true
  validates :origin_port, presence: true

  validate :recinto_matches_destination_for_import, if: :tipo_maniobra_importacion?
  validate :almacen_matches_destination_for_import, if: -> { tipo_maniobra_importacion? && almacen.present? }
  validate :require_documents_for_desconsolidado, if: :status_changing_to_desconsolidado?
  validate :destination_port_present
  validate :tentative_fields_together

  # Normalización
  before_validation :normalize_number

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :by_tipo_maniobra, ->(tipo) { where(tipo_maniobra: tipo) }
  scope :by_consolidator, ->(entity_id) { where(consolidator_entity_id: entity_id) }
  scope :by_shipping_line, ->(shipping_line_id) { where(shipping_line_id: shipping_line_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_associations, -> { includes(:consolidator_entity, :shipping_line) }

  # Callbacks para historial de status
  before_create :capture_current_user
  before_update :capture_current_user
  before_save :auto_set_status_from_fields

  after_create :create_initial_status_history
  after_update :create_status_history, if: :saved_change_to_status?
  after_commit :handle_tarja_uploaded, if: :tarja_documento_recently_attached?
  after_commit :handle_bl_master_uploaded, if: :bl_master_documento_recently_attached?
  after_commit :ensure_coordination_service_on_desconsolidado, on: :update, if: :status_changed_to_desconsolidado?
  after_commit :propagate_bl_house_lines_on_desconsolidado, on: :update, if: :status_changed_to_desconsolidado?

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
    !status_desconsolidado? && documentos_completos?
  end

  # Cambiar status con historial
  def cambiar_status!(new_status, user, observaciones = nil)
    transaction do
      # Marcador para evitar que el callback cree un historial duplicado
      @skip_auto_history = true
      @skip_auto_status = true
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
    @skip_auto_status = false
  end

  def tarja_documento=(attachable)
    super
    self.tarja_documento_attached_via_setter = true if attachable.present?
  end

  def bl_master_documento=(attachable)
    super
    self.bl_master_documento_attached_via_setter = true if attachable.present?
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

  def auto_set_status_from_fields
    return if @skip_auto_status
    return if status_desconsolidado?
    return if changed_attributes.key?("status") # Don't override if status was explicitly changed

    target = target_status_from_fields
    return if target.nil?

    self.status = target
  end

  def target_status_from_fields
    return :desconsolidado if documentos_completos? && fecha_desconsolidacion.present?
    return :fecha_tentativa_desconsolidacion if fecha_transferencia.present? && fecha_tentativa_desconsolidacion.present?
    return :cita_transferencia if fecha_transferencia.present?
    return :descargado if fecha_descarga.present?
    return :bl_revalidado if bl_master_documento.attached? || fecha_revalidacion_bl_master.present?

    :activo
  end

  def status_rank(key)
    status_order.index(key.to_s) || -1
  end

  def status_order
    %w[activo bl_revalidado descargado cita_transferencia fecha_tentativa_desconsolidacion desconsolidado]
  end

  def advance_status!(new_status, actor, observaciones)
    return if status_rank(new_status) <= status_rank(status)

    cambiar_status!(new_status, actor, observaciones)
  end

  def tarja_documento_recently_attached?
    return false unless tarja_documento.attached?

    flag = tarja_documento_attached_via_setter
    self.tarja_documento_attached_via_setter = false

    attachment_changes = tarja_documento_attachment&.previous_changes

    flag || attachment_changes.present?
  end

  def bl_master_documento_recently_attached?
    return false unless bl_master_documento.attached?

    flag = bl_master_documento_attached_via_setter
    self.bl_master_documento_attached_via_setter = false

    attachment_changes = bl_master_documento_attachment&.previous_changes

    flag || attachment_changes.present?
  end

  def handle_tarja_uploaded
    return if status_desconsolidado?
    return unless documentos_completos?
    return if fecha_desconsolidacion.blank?

    current_actor = @current_user || (defined?(Current) && Current.respond_to?(:user) ? Current.user : nil)

    advance_status!(:desconsolidado, current_actor, "Tarja adjunta automáticamente")

    propagate_bl_house_lines_on_desconsolidado
  end

  def handle_bl_master_uploaded
    return if status_desconsolidado?

    update_column(:fecha_revalidacion_bl_master, Time.current)

    current_actor = @current_user || (defined?(Current) && Current.respond_to?(:user) ? Current.user : nil)
    advance_status!(:bl_revalidado, current_actor, "BL Master adjunto")
  end

  def status_changing_to_desconsolidado?
    status == "desconsolidado" && (new_record? || will_save_change_to_status?)
  end

  def require_documents_for_desconsolidado
    if fecha_desconsolidacion.blank?
      errors.add(:fecha_desconsolidacion, "no puede estar en blanco")
    end

    return if documentos_completos?

    errors.add(:base, "Debe adjuntar tanto el BL Master como la Tarja para cambiar el estatus a desconsolidado.")
  end

  def tentative_fields_together
    if fecha_tentativa_desconsolidacion.present? && tentativa_turno.blank?
      errors.add(:tentativa_turno, "debe seleccionarse cuando se establece la fecha tentativa")
    elsif tentativa_turno.present? && fecha_tentativa_desconsolidacion.blank?
      errors.add(:fecha_tentativa_desconsolidacion, "debe establecerse cuando se selecciona el turno tentativo")
    end
  end

  def status_changed_to_desconsolidado?
    saved_change_to_status? && status_desconsolidado?
  end

  def propagate_bl_house_lines_on_desconsolidado
    bl_house_lines
      .where(status: BlHouseLine.statuses[:documentos_ok])
      .find_each do |line|
        line.with_lock do
          next if line.revalidado?
          line.revalidado!
          line.ensure_asignacion_electronica_service
        end
      end
  end

  def ensure_coordination_service_on_desconsolidado
    service = ServiceCatalog.active.find_by(code: "CONT-COOR", applies_to: "container") ||
              ServiceCatalog.active.find_by(name: "Coordinación de contenedor a almacén", applies_to: "container")
    return unless service
    return if container_services.exists?(service_catalog_id: service.id)

    container_services.create!(service_catalog: service)
  end
end
