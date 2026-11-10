# Servicios de partida para Lázaro Cárdenas (LZC). Idempotente.
# Ejecutar solo este archivo: bin/rails runner db/seeds/lzc_services.rb
puts "Creando servicios LZC..."

LZC_SERVICES = [
  { code: "BL-PRV-LZC", name: "Coordinación previo de carga en almacén LZC", amount: 679.00 },
  { code: "BL-REAC-LZC", name: "Coordinación reacomodo de carga LZC", amount: 600.00 },
  { code: "BL-POSC-LZC", name: "Coordinación posicionamiento de carga LZC", amount: 679.00 },
  { code: "BL-MF-LZC", name: "Coordinación Maniobra en falso LZC", amount: 626.00 },
  { code: "BL-PA-LZC", name: "Coordinación Personal Adicional LZC", amount: 1300.00 },
  { code: "BL-ETQ-LZC", name: "Coordinación Colocación de etiqueta LZC", amount: 10.00 },
  { code: "BL-PER-LZC", name: "Coordinación Pernoctaje en recinto LZC", amount: 2500.00 },
  { code: "BL-PMD-LZC", name: "Programación mismo día LZC", amount: 3447.00 },
  { code: "BL-EMP-LZC", name: "Coordinación emplaye LZC", amount: 500.00 },
  { code: "BL-FLJ-LZC", name: "Coordinación fleje LZC", amount: 300.00 },
  { code: "BL-GRP-LZC", name: "Coordinación sello metálico/ Grapas LZC", amount: 20.00 },
  { code: "BL-CLVS-LZC", name: "Coordinación clavos LZC", amount: 15.00 },
  { code: "BL-REF-LZC", name: "Refacturación LZC", amount: 1200.00 }
].freeze

LZC_SERVICES.each do |attrs|
  catalog = ServiceCatalog.find_or_initialize_by(applies_to: "bl_house_line", code: attrs[:code])
  catalog.assign_attributes(
    name: attrs[:name],
    amount: attrs[:amount],
    currency: "MXN",
    active: true,
    sat_clave_prod_serv: "80151600", # Servicios de comercio internacional
    sat_clave_unidad: "E48",         # Unidad de servicio
    sat_objeto_imp: "02"
  )
  catalog.save!
  puts "  #{catalog.code}: #{catalog.name}"
end
