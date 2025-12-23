class Role < ApplicationRecord
  has_many :users, dependent: :restrict_with_error
  has_many :role_permissions, dependent: :destroy
  has_many :permissions, through: :role_permissions

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

  def allows?(permission_key)
    key = permission_key.to_s
    assigned_any = permissions.exists?
    return permissions.where(key: key).exists? if assigned_any

    # Default: if no permissions assigned, internal roles allow everything, others allow nothing
    admin_or_executive?
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
