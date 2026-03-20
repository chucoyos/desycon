class Role < ApplicationRecord
  has_many :users, dependent: :restrict_with_error
  has_many :role_permissions, dependent: :destroy
  has_many :permissions, through: :role_permissions

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # Constantes para los roles
  ADMIN = "admin"
  EXECUTIVE = "executive"
  CUSTOMS_BROKER = "agente aduanal"
  TRAMITADOR = "tramitador"
  CONSOLIDATOR = "consolidador"

  ENTITY_ROLE_KIND_BY_USER_ROLE = {
    CONSOLIDATOR => "consolidator",
    CUSTOMS_BROKER => "customs_agent"
  }.freeze

  def admin?
    name == ADMIN
  end

  def executive?
    name == EXECUTIVE
  end

  def customs_broker?
    name == CUSTOMS_BROKER
  end

  def tramitador?
    name == TRAMITADOR
  end

  def consolidator?
    name == CONSOLIDATOR
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
    when TRAMITADOR
      "Tramitador"
    when CONSOLIDATOR
      "Consolidador"
    else
      name
    end
  end

  # Maps user role names to the entity role_kind that can be assigned in user forms.
  # Returns nil for internal roles that do not require an entity.
  def entity_role_kind_for_users
    ENTITY_ROLE_KIND_BY_USER_ROLE[name]
  end
end
