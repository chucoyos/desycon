class Port < ApplicationRecord
  # Validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :country_code, presence: true, inclusion: { in: ISO3166::Country.codes }

  # Normalize code to uppercase before validation
  before_validation :normalize_code

  # Scopes
  scope :by_country, ->(country_code) { where(country_code: country_code) }
  scope :alphabetical, -> { order(:name) }

  # Methods
  def country
    ISO3166::Country[country_code]
  end

  def country_name
    country&.translations&.dig("es") || country&.iso_short_name
  end

  def display_name
    "#{name} (#{code})"
  end

  private

  def normalize_code
    self.code = code&.upcase&.strip
  end
end
