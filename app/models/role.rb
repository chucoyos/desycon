class Role < ApplicationRecord
  has_many :users

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # Constantes para los roles
  ADMIN = "admin"
  OPERATOR = "operator"
  CUSTOMS_BROKER = "customs_broker"

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
end
