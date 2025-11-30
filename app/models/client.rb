class Client < ApplicationRecord
  belongs_to :entity

  validates :entity_id, uniqueness: true

  delegate :name, :addresses, :fiscal_profile, to: :entity
end
