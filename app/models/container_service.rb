class ContainerService < ApplicationRecord
  belongs_to :container
  belongs_to :service_catalog
  belongs_to :billed_to_entity, class_name: "Entity", optional: true

  before_validation :assign_default_billed_to_entity

  validates :service_catalog, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true, inclusion: { in: [ "MXN" ] }
  validates :factura, length: { maximum: 100 }, allow_blank: true
  validates :observaciones, length: { maximum: 1000 }, allow_blank: true

  scope :by_fecha_programada, -> { order(fecha_programada: :asc) }
  scope :pendientes, -> { where(factura: nil) }
  scope :facturados, -> { where.not(factura: nil) }
  scope :by_service_catalog, ->(service_catalog_id) { where(service_catalog_id: service_catalog_id) }

  def to_s
    service_catalog.display_name
  end

  def total
    amount
  end

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

    self.billed_to_entity_id = container&.consolidator_entity_id || container&.consolidator_id
  end
end
