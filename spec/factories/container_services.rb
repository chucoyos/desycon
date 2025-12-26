FactoryBot.define do
  factory :container_service do
    association :container
    association :service_catalog
    fecha_programada { Date.today + rand(1..30).days }
    observaciones { 'Servicio programado' }

    trait :facturado do
      sequence(:factura) { |n| "FAC-#{n.to_s.rjust(5, '0')}" }
    end

    trait :pendiente do
      factura { nil }
    end

    trait :maniobra do
      association :service_catalog, factory: :service_catalog_maniobra
    end

    trait :almacenaje do
      association :service_catalog, factory: :service_catalog_almacenaje
    end

    trait :transporte do
      association :service_catalog, factory: :service_catalog_transporte
    end
  end
end
