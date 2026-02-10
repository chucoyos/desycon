class AgencyBroker < ApplicationRecord
  belongs_to :agency, class_name: "Entity"
  belongs_to :broker, class_name: "Entity"

  validates :agency_id, uniqueness: { scope: :broker_id }
  validate :roles_match

  def roles_match
    errors.add(:agency, "debe ser una agencia aduanal") unless agency&.is_customs_agent?
    errors.add(:broker, "debe ser un agente aduanal (broker)") unless broker&.is_customs_broker?
  end
end
