class ServiceCatalog < ApplicationRecord
  APPLIES_TO = %w[container bl_house_line].freeze

  has_many :container_services, dependent: :restrict_with_exception
  has_many :bl_house_line_services, dependent: :restrict_with_exception

  validates :name, presence: true, length: { maximum: 200 }
  validates :applies_to, presence: true, inclusion: { in: APPLIES_TO }
  validates :code, length: { maximum: 50 }, allow_blank: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true, inclusion: { in: [ "MXN" ] }

  scope :active, -> { where(active: true) }
  scope :for_containers, -> { active.where(applies_to: "container") }
  scope :for_bl_house_lines, -> { active.where(applies_to: "bl_house_line") }

  def display_name
    code.present? ? "#{name} (#{code})" : name
  end
end
