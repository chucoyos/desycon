FactoryBot.define do
  factory :invoice do
    association :invoiceable, factory: :container_service
    association :issuer_entity, factory: [ :entity, :customs_agent ]
    association :receiver_entity, factory: [ :entity, :client ]

    kind { 'ingreso' }
    status { 'draft' }
    currency { 'MXN' }
    subtotal { 1000 }
    tax_total { 160 }
    total { 1160 }
    payload_snapshot { {} }
    provider_response { {} }
  end
end
