FactoryBot.define do
  factory :bl_house_line do
    sequence(:blhouse) { |n| "BLH#{n.to_s.rjust(6, '0')}" }
    sequence(:partida) { |n| n }
    cantidad { 10 }
    contiene { "Contenido de prueba" }
    marcas { "Marcas de prueba" }
    peso { 100.5 }
    volumen { 2.5 }
    status { "activo" }
    association :customs_agent, factory: [ :entity, :customs_agent ]
    association :client, factory: [ :entity, :client ]
    association :container
    association :packaging
  end
end
