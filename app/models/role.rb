class Role < ApplicationRecord
  has_many :users, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # Constantes para los roles
  ADMIN = "admin"
  OPERATOR = "operator"
  CUSTOMS_BROKER = "agente aduanal"

  def admin?
    name == ADMIN
  end

  def operator?
    name == OPERATOR
  end

  def customs_broker?
    name == CUSTOMS_BROKER
  end

  def internal?
    admin? || operator?
  end

  # Nombre visible del role
  def display_name
    case name
    when OPERATOR
      "Operador"
    when CUSTOMS_BROKER
      "Agente Aduanal"
    else
      name
    end
  end
end
