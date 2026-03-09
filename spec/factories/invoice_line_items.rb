FactoryBot.define do
  factory :invoice_line_item do
    association :invoice
    association :service_catalog

    position { 0 }
    description { service_catalog.name }
    sat_clave_prod_serv { "78101800" }
    sat_clave_unidad { "E48" }
    sat_objeto_imp { "02" }
    sat_tasa_iva { 0.16 }
    quantity { 1 }
    unit_price { 100 }
    subtotal { 100 }
    tax_amount { 16 }
    total { 116 }
  end
end
