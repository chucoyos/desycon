class ContainerService < ApplicationRecord
  belongs_to :container
  belongs_to :billed_to_entity, class_name: "Entity", optional: true

  # Validaciones
  validates :cliente, presence: true, length: { maximum: 200 }
  validates :cantidad, presence: true, numericality: { greater_than: 0 }
  validates :servicio, presence: true, length: { maximum: 200 }
  validates :referencia, length: { maximum: 100 }, allow_blank: true
  validates :factura, length: { maximum: 100 }, allow_blank: true
  validates :observaciones, length: { maximum: 1000 }, allow_blank: true

  # Scopes
  scope :by_cliente, ->(cliente) { where("cliente ILIKE ?", "%#{cliente}%") }
  scope :by_servicio, ->(servicio) { where("servicio ILIKE ?", "%#{servicio}%") }
  scope :by_fecha_programada, -> { order(fecha_programada: :asc) }
  scope :pendientes, -> { where(factura: nil) }
  scope :facturados, -> { where.not(factura: nil) }

  # Métodos
  def to_s
    "#{servicio} - #{cliente}"
  end

  def total
    cantidad
  end

  def facturado?
    factura.present?
  end

  def pendiente?
    !facturado?
  end
end
