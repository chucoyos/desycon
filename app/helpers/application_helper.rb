module ApplicationHelper
  # Retorna todos los países en español para select
  def countries_for_select
    ISO3166::Country.all.map do |country|
      [ country.translations["es"] || country.iso_short_name, country.alpha2 ]
    end.sort_by(&:first)
  end

  # Retorna los estados de México para select
  def mexico_states_for_select
    ISO3166::Country["MX"].subdivisions.map do |code, subdivision|
      [ subdivision["name"], code ]
    end.sort_by(&:first)
  end

  # Obtiene el nombre del país en español dado su código
  def country_name(country_code)
    return nil if country_code.blank?
    country = ISO3166::Country[country_code]
    country&.translations&.dig("es") || country&.iso_short_name
  end

  # Obtiene el nombre del estado dado el código del país y estado
  def state_name(country_code, state_code)
    return nil if country_code.blank? || state_code.blank?
    country = ISO3166::Country[country_code]
    country&.subdivisions&.dig(state_code, "name")
  end
end
