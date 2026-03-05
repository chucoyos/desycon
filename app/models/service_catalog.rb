class ServiceCatalog < ApplicationRecord
  APPLIES_TO = %w[container bl_house_line].freeze
  SAT_OBJETO_IMP = %w[01 02 03].freeze

  attribute :sat_objeto_imp, :string, default: "02"
  attribute :sat_tasa_iva, :decimal, default: 0.16

  has_many :container_services, dependent: :restrict_with_exception
  has_many :bl_house_line_services, dependent: :restrict_with_exception

  validates :name, presence: true, length: { maximum: 200 }
  validates :applies_to, presence: true, inclusion: { in: APPLIES_TO }
  validates :code, length: { maximum: 50 }, allow_blank: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true, inclusion: { in: [ "MXN" ] }
  validates :sat_clave_prod_serv, length: { maximum: 8 }, allow_blank: true
  validates :sat_clave_unidad, length: { maximum: 3 }, allow_blank: true
  validates :sat_objeto_imp, presence: true, inclusion: { in: SAT_OBJETO_IMP }
  validates :sat_tasa_iva, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :for_containers, -> { active.where(applies_to: "container") }
  scope :for_bl_house_lines, -> { active.where(applies_to: "bl_house_line") }

  def display_name
    code.present? ? "#{name} (#{code})" : name
  end
end
