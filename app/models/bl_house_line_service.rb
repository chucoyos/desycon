class BlHouseLineService < ApplicationRecord
  belongs_to :bl_house_line
  belongs_to :service_catalog
  belongs_to :billed_to_entity, class_name: "Entity", optional: true

  before_validation :assign_default_billed_to_entity

  validates :service_catalog, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true, inclusion: { in: [ "MXN" ] }
  validates :observaciones, length: { maximum: 1000 }, allow_blank: true
  validates :factura, length: { maximum: 100 }, allow_blank: true

  scope :facturados, -> { where.not(factura: nil) }
  scope :pendientes, -> { where(factura: nil) }
  scope :by_fecha_programada, -> { order(fecha_programada: :asc) }

  def facturado?
    factura.present?
  end

  def pendiente?
    !facturado?
  end

  def amount
    service_catalog&.amount
  end

  def currency
    service_catalog&.currency
  end

  private

  def assign_default_billed_to_entity
    return if billed_to_entity_id.present?

    self.billed_to_entity_id = bl_house_line&.client_id
  end
end
