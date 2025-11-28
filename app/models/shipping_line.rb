class ShippingLine < ApplicationRecord
  has_many :vessels, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :alphabetical, -> { order(:name) }
end
