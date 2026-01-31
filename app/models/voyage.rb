class Voyage < ApplicationRecord
  belongs_to :vessel
  belongs_to :destination_port, class_name: "Port", optional: true

  has_many :containers, dependent: :restrict_with_error

  enum :voyage_type, {
    arribo: "arribo",
    zarpe: "zarpe"
  }, prefix: true

  validates :viaje, presence: true, length: { maximum: 50 }
  validates :voyage_type, presence: true, inclusion: { in: voyage_types.keys }
  validates :vessel, presence: true
  validates :viaje, uniqueness: { scope: :vessel_id, case_sensitive: false }
end
