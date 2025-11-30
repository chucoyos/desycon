class Entity < ApplicationRecord
  # Relaciones polimórficas con tablas existentes
  has_many :addresses, as: :addressable, dependent: :destroy
  has_one :fiscal_profile, as: :profileable, dependent: :destroy

  # Relaciones con perfiles específicos (opcionales)
  has_one :consolidator_profile, class_name: "Consolidator", dependent: :destroy
  has_one :forwarder_profile, class_name: "Forwarder", dependent: :destroy
  has_one :client_profile, class_name: "Client", dependent: :destroy

  # Patentes aduanales (múltiples)
  has_many :customs_agent_patents, dependent: :destroy

  # Relaciones de negocio
  has_many :billed_services, class_name: "ContainerService",
           foreign_key: :billed_to_entity_id, dependent: :nullify
  has_many :containers, foreign_key: :consolidator_entity_id, dependent: :restrict_with_error

  # Nested attributes
  accepts_nested_attributes_for :addresses, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :fiscal_profile, reject_if: :all_blank
  accepts_nested_attributes_for :customs_agent_patents,
                                allow_destroy: true,
                                reject_if: :all_blank

  # Validaciones
  validates :name, presence: true
  validate :must_have_at_least_one_role

  # Scopes
  scope :consolidators, -> { where(is_consolidator: true) }
  scope :customs_agents, -> { where(is_customs_agent: true) }
  scope :forwarders, -> { where(is_forwarder: true) }
  scope :clients, -> { where(is_client: true) }

  # Callbacks
  after_update :sync_profiles

  def roles
    roles_array = []
    roles_array << "Consolidador" if is_consolidator
    roles_array << "Agente Aduanal" if is_customs_agent
    roles_array << "Forwarder" if is_forwarder
    roles_array << "Cliente" if is_client
    roles_array.join(", ")
  end

  def display_name
    "#{name} (#{roles})"
  end

  def active_patents
    customs_agent_patents.order(:patent_number)
  end

  # Address helper methods
  def fiscal_address
    addresses.fiscales.first
  end

  def shipping_addresses
    addresses.envio
  end

  def warehouse_addresses
    addresses.almacenes
  end

  def build_fiscal_profile_if_needed
    build_fiscal_profile if fiscal_profile.blank?
  end

  def build_fiscal_address_if_needed
    addresses.build(tipo: "fiscal") if addresses.fiscales.empty?
  end

  private

  def must_have_at_least_one_role
    unless is_consolidator || is_customs_agent || is_forwarder || is_client
      errors.add(:base, "Debe seleccionar al menos un rol")
    end
  end

  def sync_profiles
    # Crear perfil de consolidador si es necesario
    if is_consolidator && !consolidator_profile
      create_consolidator_profile
    elsif !is_consolidator && consolidator_profile
      consolidator_profile.destroy
    end

    # Similar para otros roles
    if is_forwarder && !forwarder_profile
      create_forwarder_profile
    elsif !is_forwarder && forwarder_profile
      forwarder_profile.destroy
    end

    if is_client && !client_profile
      create_client_profile
    elsif !is_client && client_profile
      client_profile.destroy
    end
  end
end
