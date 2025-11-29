FactoryBot.define do
  factory :address do
    association :addressable, factory: :shipping_line
    tipo { 'fiscal' }
    pais { 'MX' }
    sequence(:codigo_postal) { |n| format('%05d', 10000 + n) }
    estado { 'Ciudad de México' }
    municipio { 'Cuauhtémoc' }
    localidad { 'Ciudad de México' }
    colonia { 'Centro' }
    sequence(:calle) { |n| "Avenida Reforma #{n}" }
    sequence(:numero_exterior) { |n| n.to_s }
    numero_interior { nil }
    sequence(:email) { |n| "contacto#{n}@empresa.com" }

    trait :envio do
      tipo { 'envio' }
      estado { 'Veracruz' }
      municipio { 'Veracruz' }
      colonia { 'Puerto' }
      calle { 'Calle del Muelle' }
    end

    trait :almacen do
      tipo { 'almacen' }
      estado { 'Nuevo León' }
      municipio { 'Monterrey' }
      colonia { 'Industrial' }
      calle { 'Parque Industrial' }
    end

    trait :sin_email do
      email { nil }
    end
  end
end
