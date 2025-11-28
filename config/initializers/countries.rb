# Configure countries gem
require "countries"

# Enable translations
ISO3166.configure do |config|
  config.locales = [ :es, :en ]
end

# Monkey patch para facilitar el uso en español
module CountriesHelper
  def self.all_for_select
    ISO3166::Country.all.map do |country|
      [ country.translations["es"] || country.iso_short_name, country.alpha2 ]
    end.sort
  end

  def self.mexico_states_for_select
    ISO3166::Country["MX"].subdivisions.map do |code, subdivision|
      [ subdivision["name"], code ]
    end.sort
  end
end
