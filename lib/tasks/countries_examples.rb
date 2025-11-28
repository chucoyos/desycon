# Ejemplo de uso de la gema countries en modelos y formularios
#
# 1. En un modelo (ejemplo: Address, Port, etc.)
# ================================================
#
# class Address < ApplicationRecord
#   # Solo guardas códigos en la DB:
#   # - country_code: string (ej: "MX", "US")
#   # - state_code: string (ej: "JAL", "TX")
#
#   validates :country_code, inclusion: { in: ISO3166::Country.codes }
#
#   def country
#     ISO3166::Country[country_code]
#   end
#
#   def country_name
#     country&.translations&.dig('es') || country&.iso_short_name
#   end
#
#   def state_name
#     country&.subdivisions&.dig(state_code, 'name')
#   end
#
#   def states_for_select
#     return [] unless country
#     country.subdivisions.map { |code, data| [data['name'], code] }.sort
#   end
# end
#
# 2. En un formulario (ejemplo: _form.html.erb)
# ================================================
#
# <%= form.label :country_code, "País" %>
# <%= form.select :country_code,
#     countries_for_select,
#     { prompt: "Selecciona un país" },
#     { class: "form-select" }
# %>
#
# <%= form.label :state_code, "Estado" %>
# <%= form.select :state_code,
#     mexico_states_for_select,
#     { prompt: "Selecciona un estado" },
#     { class: "form-select" }
# %>
#
# 3. En las vistas (ejemplo: show.html.erb)
# ================================================
#
# <p><strong>País:</strong> <%= country_name(@address.country_code) %></p>
# <p><strong>Estado:</strong> <%= state_name(@address.country_code, @address.state_code) %></p>
#
# 4. En consola de Rails
# ================================================
#
# # Obtener país
# mx = ISO3166::Country['MX']
# mx.translations['es']  # => "México"
# mx.alpha2              # => "MX"
# mx.alpha3              # => "MEX"
#
# # Estados de México
# mx.subdivisions        # => Hash de todos los estados
# mx.subdivisions['JAL'] # => {"name"=>"Jalisco", ...}
#
# # Todos los países en español
# ISO3166::Country.all.map { |c| [c.translations['es'], c.alpha2] }.sort
#
# 5. Validaciones útiles
# ================================================
#
# validates :country_code,
#   inclusion: {
#     in: ISO3166::Country.codes,
#     message: "no es un código de país válido"
#   }
#
# validate :valid_state_code
#
# private
#
# def valid_state_code
#   return if state_code.blank? || country_code.blank?
#
#   country = ISO3166::Country[country_code]
#   unless country&.subdivisions&.key?(state_code)
#     errors.add(:state_code, "no es válido para este país")
#   end
# end

puts "Este archivo contiene ejemplos de uso. Ver comentarios."
