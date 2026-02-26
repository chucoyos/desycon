class AgencyBroker < ApplicationRecord
  belongs_to :agency, class_name: "Entity"
  belongs_to :broker, class_name: "Entity"

  validates :agency_id, uniqueness: { scope: :broker_id }
  validate :roles_match

  def roles_match
    errors.add(:agency, "debe ser una agencia aduanal") unless agency&.role_customs_agent?
    errors.add(:broker, "debe ser un agente aduanal (broker)") unless broker&.role_customs_broker?
  end
end
