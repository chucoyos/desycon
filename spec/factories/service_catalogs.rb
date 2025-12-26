FactoryBot.define do
  factory :service_catalog do
    sequence(:name) { |n| "Servicio #{n}" }
    applies_to { "container" }
    active { true }
    amount { 100.0 }
    currency { "MXN" }

    factory :service_catalog_maniobra do
      name { "Maniobra de descarga" }
      code { "CNT-MANI" }
      applies_to { "container" }
    end

    factory :service_catalog_almacenaje do
      name { "Almacenaje" }
      code { "CNT-ALM" }
      applies_to { "container" }
    end

    factory :service_catalog_transporte do
      name { "Transporte terrestre" }
      code { "CNT-TRANS" }
      applies_to { "container" }
    end
  end
end
