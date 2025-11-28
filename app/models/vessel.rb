class Vessel < ApplicationRecord
  belongs_to :shipping_line

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :shipping_line, presence: true

  scope :alphabetical, -> { order(:name) }
  scope :by_shipping_line, ->(shipping_line_id) { where(shipping_line_id: shipping_line_id) }

  def to_s
    name
  end
end
