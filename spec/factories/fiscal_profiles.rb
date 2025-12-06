FactoryBot.define do
  factory :fiscal_profile do
    # association :profileable, factory: :shipping_line
    sequence(:razon_social) { |n| "Empresa de Prueba #{n} SA de CV" }
    sequence(:rfc) { |n| format('EMP%06d%03d', n, rand(100..999)) }
    regimen { '601' } # General de Ley Personas Morales
    uso_cfdi { 'G03' } # Gastos en general
    forma_pago { '03' } # Transferencia electrónica
    metodo_pago { 'PUE' } # Pago en una exhibición

    trait :regimen_simplificado do
      regimen { '626' }
    end

    trait :pago_diferido do
      metodo_pago { 'PPD' }
    end

    trait :efectivo do
      forma_pago { '01' }
    end
  end
end
