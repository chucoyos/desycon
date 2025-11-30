FactoryBot.define do
  factory :container_service do
    association :container
    sequence(:cliente) { |n| "Cliente #{n}" }
    cantidad { rand(100.0..5000.0).round(2) }
    sequence(:servicio) { |n| "Servicio #{n}" }
    fecha_programada { Date.today + rand(1..30).days }
    observaciones { 'Servicio programado' }
    sequence(:referencia) { |n| "REF-#{n.to_s.rjust(4, '0')}" }

    trait :facturado do
      sequence(:factura) { |n| "FAC-#{n.to_s.rjust(5, '0')}" }
    end

    trait :pendiente do
      factura { nil }
    end

    trait :maniobra do
      servicio { 'Maniobra de descarga' }
      cantidad { rand(1000.0..3000.0).round(2) }
    end

    trait :almacenaje do
      servicio { 'Almacenaje' }
      cantidad { rand(500.0..2000.0).round(2) }
    end

    trait :transporte do
      servicio { 'Transporte terrestre' }
      cantidad { rand(1500.0..4000.0).round(2) }
    end
  end
end
