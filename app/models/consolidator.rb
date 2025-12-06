class Consolidator < ApplicationRecord
  # Asociación con Entity (1:1)
  belongs_to :entity

  # Asociaciones con contenedores (mantener para compatibilidad temporal)
  has_many :containers, dependent: :restrict_with_error

  # Validaciones
  validates :entity_id, presence: true, uniqueness: true

  # Delegaciones a Entity para acceso conveniente
  delegate :name, :fiscal_profile, :build_fiscal_profile, :build_fiscal_profile_if_needed, :addresses, :customs_agent_patents,
           :fiscal_address, :shipping_addresses, :warehouse_addresses,
           to: :entity, allow_nil: true

  # Scopes
  scope :alphabetical, -> { joins(:entity).order("entities.name") }
  scope :with_fiscal_data, -> { includes(entity: :fiscal_profile) }
  scope :with_addresses, -> { includes(entity: :addresses) }

  # Métodos de conveniencia
  def to_s
    entity&.name || "Consolidator ##{id}"
  end

  def build_fiscal_profile_if_needed
    entity&.build_fiscal_profile_if_needed
  end

  def build_fiscal_address_if_needed
    entity&.build_fiscal_address_if_needed
  end
end
