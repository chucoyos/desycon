class EntityEvent < ApplicationRecord
  EVENT_TYPES = %w[entity_created entity_updated entity_baseline].freeze

  belongs_to :entity
  belongs_to :user, optional: true

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
end
