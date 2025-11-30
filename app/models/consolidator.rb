class Consolidator < ApplicationRecord
  # Asociaciones polimórficas
  has_one :fiscal_profile, as: :profileable, dependent: :destroy
  has_many :addresses, as: :addressable, dependent: :destroy

  # Asociaciones con contenedores
  has_many :containers, dependent: :restrict_with_error

  # Nested attributes para crear/actualizar datos fiscales y direcciones en un solo form
  accepts_nested_attributes_for :fiscal_profile, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :addresses, allow_destroy: true, reject_if: :reject_empty_address

  # Validaciones
  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 200 }

  # Scopes
  scope :alphabetical, -> { order(:name) }
  scope :with_fiscal_data, -> { includes(:fiscal_profile) }
  scope :with_addresses, -> { includes(:addresses) }

  # Métodos de conveniencia
  def to_s
    name
  end

  def fiscal_address
    addresses.fiscales.first
  end

  def shipping_addresses
    addresses.envio
  end

  def warehouse_addresses
    addresses.almacenes
  end

  # Asegura que tenga datos fiscales
  def build_fiscal_profile_if_needed
    build_fiscal_profile if fiscal_profile.blank?
  end

  def build_fiscal_address_if_needed
    addresses.build(tipo: "fiscal") if addresses.fiscales.empty?
  end

  private

  # Rechazar direcciones vacías basándonos en campos obligatorios
  def reject_empty_address(attributes)
    # Si tiene ID, es una dirección existente - no rechazar (permitir edición)
    return false if attributes["id"].present?

    # Para direcciones nuevas, rechazar si TODOS los campos importantes están vacíos
    attributes["codigo_postal"].blank? &&
    attributes["estado"].blank? &&
    attributes["email"].blank? &&
    attributes["calle"].blank? &&
    attributes["tipo"].blank?
  end
end
