class Consolidator < ApplicationRecord
  # Asociaciones polimórficas
  has_one :fiscal_profile, as: :profileable, dependent: :destroy
  has_many :addresses, as: :addressable, dependent: :destroy

  # Nested attributes para crear/actualizar datos fiscales y direcciones en un solo form
  accepts_nested_attributes_for :fiscal_profile, allow_destroy: true
  accepts_nested_attributes_for :addresses, allow_destroy: true, reject_if: :all_blank

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
end
