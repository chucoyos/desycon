class ContainerStatusHistory < ApplicationRecord
  belongs_to :container
  belongs_to :user, optional: true

  # Validaciones
  validates :status, presence: true
  validates :fecha_actualizacion, presence: true
  validates :observaciones, length: { maximum: 1000 }, allow_blank: true

  # Scopes
  scope :recent, -> { order(fecha_actualizacion: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_container, ->(container_id) { where(container_id: container_id) }

  # Métodos
  def usuario_nombre
    user&.email || "Sistema"
  end

  def status_humanizado
    I18n.t("container.statuses.#{status}", default: status.humanize)
  end
end
