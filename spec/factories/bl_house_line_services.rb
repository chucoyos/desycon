FactoryBot.define do
  factory :bl_house_line_service do
    association :bl_house_line
    association :service_catalog
    fecha_programada { Date.today + rand(1..30).days }
    observaciones { 'Servicio BL programado' }

    trait :facturado do
      sequence(:factura) { |n| "BLF-#{n.to_s.rjust(5, '0')}" }
    end

    trait :pendiente do
      factura { nil }
    end
  end
end
