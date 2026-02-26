class Entity < ApplicationRecord
  ROLE_KIND_PRIORITY = {
    customs_agent: :is_customs_agent,
    consolidator: :is_consolidator,
    customs_broker: :is_customs_broker,
    client: :is_client,
    forwarder: :is_forwarder
  }.freeze

  ROLE_KINDS = ROLE_KIND_PRIORITY.keys.map(&:to_s).freeze

  enum :role_kind, {
    customs_agent: "customs_agent",
    consolidator: "consolidator",
    customs_broker: "customs_broker",
    client: "client",
    forwarder: "forwarder"
  }, prefix: :role

  # Relaciones polimórficas con tablas existentes
  has_many :addresses, as: :addressable, dependent: :destroy
  has_one :fiscal_profile, as: :profileable, dependent: :destroy
  has_many :users, dependent: :restrict_with_error

  # Relación Agencia Aduanal - Clientes
  belongs_to :customs_agent, class_name: "Entity", optional: true
  has_many :clients, class_name: "Entity", foreign_key: "customs_agent_id", dependent: :nullify

  # Relaciones con BL House Lines
  has_many :bl_house_lines_as_customs_agent, class_name: "BlHouseLine",
           foreign_key: "customs_agent_id", dependent: :restrict_with_error
  has_many :bl_house_lines_as_client, class_name: "BlHouseLine",
           foreign_key: "client_id", dependent: :restrict_with_error

  # Relaciones con perfiles específicos (opcionales)
  has_one :consolidator_profile, class_name: "Consolidator", dependent: :destroy
  has_one :forwarder_profile, class_name: "Forwarder", dependent: :destroy
  has_one :client_profile, class_name: "Client", dependent: :destroy

  # Brokers (agentes aduanales) vinculados a la agencia
  has_many :agency_broker_links_as_agency, class_name: "AgencyBroker", foreign_key: :agency_id, dependent: :destroy
  has_many :customs_brokers, through: :agency_broker_links_as_agency, source: :broker

  # Agencias vinculadas a un broker
  has_many :agency_broker_links_as_broker, class_name: "AgencyBroker", foreign_key: :broker_id, dependent: :destroy
  has_many :customs_agencies, through: :agency_broker_links_as_broker, source: :agency

  # Relaciones de negocio
  has_many :billed_services, class_name: "ContainerService",
           foreign_key: :billed_to_entity_id, dependent: :nullify
  has_many :containers, foreign_key: :consolidator_entity_id, dependent: :restrict_with_error

  # Nested attributes
  accepts_nested_attributes_for :addresses, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :fiscal_profile, reject_if: :all_blank
  # No nested brokers here; brokers are managed separately

  # Validaciones
  validates :name, presence: true
  validate :validate_addresses_if_present
  validate :validate_fiscal_profile
  validate :must_have_at_least_one_role
  validate :broker_patent_required
  validate :patent_only_for_broker
  validates :patent_number, uniqueness: true, allow_blank: true
  validates :role_kind, inclusion: { in: ROLE_KINDS }, allow_nil: true, if: :role_kind_column_present?

  # Scopes
  scope :consolidators, -> { where(role_kind: "consolidator") }
  scope :customs_agents, -> { where(role_kind: "customs_agent") }
  scope :customs_brokers, -> { where(role_kind: "customs_broker") }
  scope :forwarders, -> { where(role_kind: "forwarder") }
  scope :clients, -> { where(role_kind: "client") }

  # Callbacks
  before_validation :normalize_patent_number
  before_validation :apply_role_kind_consistency, if: :role_kind_column_present?
  after_update :sync_profiles

  def roles
    role_label
  end

  def display_name
    "#{name} (#{roles})"
  end

  # Address helper methods
  def fiscal_address
    addresses.matriz.first
  end

  def shipping_addresses
    addresses.sucursales
  end

  def warehouse_addresses
    addresses.sucursales
  end

  def build_fiscal_profile_if_needed
    build_fiscal_profile if fiscal_profile.blank?
  end

  def build_fiscal_address_if_needed
    addresses.build(tipo: "matriz") if addresses.matriz.empty?
  end

  private

  def must_have_at_least_one_role
    has_role = role_kind_column_present? ? role_kind.present? : inferred_role_kind_from_flags.present?

    unless has_role
      errors.add(:base, "Debe seleccionar al menos un rol")
    end
  end

  def broker_patent_required
    return unless role_customs_broker?

    if patent_number.blank?
      errors.add(:patent_number, "es obligatoria para agentes aduanales")
    end
  end

  def patent_only_for_broker
    return if patent_number.blank? || role_customs_broker?

    errors.add(:patent_number, "solo aplica a agentes aduanales")
  end

  def normalize_patent_number
    self.patent_number = nil if patent_number.blank?
  end

  def apply_role_kind_consistency
    if role_kind.blank? || legacy_role_flags_changed?
      self.role_kind = inferred_role_kind_from_flags
    end

    sync_flags_from_role_kind if role_kind.present?
  end

  def inferred_role_kind_from_flags
    ROLE_KIND_PRIORITY.each do |role_kind, role_flag|
      next unless role_flag_present?(role_flag)
      return role_kind.to_s if self[role_flag]
    end

    nil
  end

  def role_label
    case role_kind
    when "consolidator"
      "Consolidador"
    when "customs_agent"
      "Agencia Aduanal"
    when "customs_broker"
      "Agente Aduanal (Broker)"
    when "forwarder"
      "Forwarder"
    when "client"
      "Cliente"
    else
      "Sin rol"
    end
  end

  def sync_flags_from_role_kind
    sync_role_flag(:is_consolidator, role_kind == "consolidator")
    sync_role_flag(:is_customs_agent, role_kind == "customs_agent")
    sync_role_flag(:is_customs_broker, role_kind == "customs_broker")
    sync_role_flag(:is_forwarder, role_kind == "forwarder")
    sync_role_flag(:is_client, role_kind == "client")
  end

  def legacy_role_flags_changed?
    %i[is_consolidator is_customs_agent is_customs_broker is_forwarder is_client].any? do |role_flag|
      role_flag_present?(role_flag) && will_save_change_to_attribute?(role_flag)
    end
  end

  def role_flag_present?(role_flag)
    has_attribute?(role_flag)
  end

  def sync_role_flag(role_flag, value)
    return unless role_flag_present?(role_flag)

    self[role_flag] = value
  end

  def role_kind_column_present?
    self.class.column_names.include?("role_kind")
  end

  def addresses_loaded_and_present?
    addresses.reject(&:marked_for_destruction?).any? do |addr|
      addr.persisted? || user_provided_address_data?(addr)
    end
  end

  private

  def validate_addresses_if_present
    return unless addresses_loaded_and_present?

    addresses.each do |address|
      next if address.marked_for_destruction?

      unless address.valid?
        # Add address validation errors to the entity
        address.errors.each do |error|
          errors.add(:addresses, error.message)
        end
      end
    end
  end

  def user_provided_address_data?(address)
    # Check only user-editable fields, excluding Rails internal attributes
    user_fields = [ :tipo, :pais, :codigo_postal, :estado, :municipio, :localidad,
                   :colonia, :calle, :numero_exterior, :numero_interior, :email ]

    user_fields.any? { |field| address.send(field).present? }
  end

  def sync_profiles
    # Crear perfil de consolidador si es necesario
    if role_consolidator? && !consolidator_profile
      create_consolidator_profile
    elsif !role_consolidator? && consolidator_profile
      consolidator_profile.destroy
    end

    # Similar para otros roles
    if role_forwarder? && !forwarder_profile
      create_forwarder_profile
    elsif !role_forwarder? && forwarder_profile
      forwarder_profile.destroy
    end

    if role_client? && !client_profile
      create_client_profile
    elsif !role_client? && client_profile
      client_profile.destroy
    end
  end

  def validate_fiscal_profile
    return unless fiscal_profile.present?

    # Validar el fiscal_profile y mantener sus errores
    unless fiscal_profile.valid?
      # Agregar un error general a la entidad para que validates_associated no sea necesario
      errors.add(:fiscal_profile, "no es válido")
    end
  end

  private
end
