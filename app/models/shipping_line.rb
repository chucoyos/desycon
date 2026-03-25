class ShippingLine < ApplicationRecord
  has_many :containers, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :iso_code, presence: true, uniqueness: { case_sensitive: false }, length: { is: 3 }

  scope :alphabetical, -> { order(:name) }
  scope :search_by_name, lambda { |query|
    term = query.to_s.strip
    if term.blank?
      none
    else
      sanitized = ActiveRecord::Base.sanitize_sql_like(term.downcase)
      where("LOWER(name) LIKE ?", "%#{sanitized}%").order(:name)
    end
  }
end
