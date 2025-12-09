class Packaging < ApplicationRecord
  # Validations
  validates :nombre, presence: true, uniqueness: { case_sensitive: false }
end
