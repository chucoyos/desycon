class Role < ApplicationRecord
  has_many :users, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # Constantes para los roles
  ADMIN = "admin"
  EXECUTIVE = "executive"
  CUSTOMS_BROKER = "agente aduanal"

  def admin?
    name == ADMIN
  end

  def executive?
    name == EXECUTIVE
  end

  def customs_broker?
    name == CUSTOMS_BROKER
  end

  def internal?
    admin_or_executive?
  end

  def admin_or_executive?
    admin? || executive?
  end

  # Nombre visible del role
  def display_name
    case name
    when EXECUTIVE
      "Ejecutivo"
    when CUSTOMS_BROKER
      "Agente Aduanal"
    else
      name
    end
  end
end
