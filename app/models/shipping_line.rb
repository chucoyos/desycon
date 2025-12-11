class ShippingLine < ApplicationRecord
  has_many :vessels, dependent: :restrict_with_error
  has_many :containers, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :scac_code, presence: true, uniqueness: { case_sensitive: false }, length: { is: 4 }

  scope :alphabetical, -> { order(:name) }
end
