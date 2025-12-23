class Permission < ApplicationRecord
  has_many :role_permissions, dependent: :destroy
  has_many :roles, through: :role_permissions

  validates :name, :key, presence: true
  validates :key, uniqueness: true

  scope :ordered, -> { order(:name) }
end
