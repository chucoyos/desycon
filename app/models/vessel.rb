class Vessel < ApplicationRecord
  has_many :containers, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :alphabetical, -> { order(:name) }

  def to_s
    name
  end
end
