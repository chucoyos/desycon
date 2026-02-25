# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Crear roles
puts "Creando roles..."
admin_role = Role.find_or_create_by!(name: Role::ADMIN)
executive_role = Role.find_or_create_by!(name: Role::EXECUTIVE)
customs_broker_role = Role.find_or_create_by!(name: Role::CUSTOMS_BROKER)
puts "✓ Roles creados"

# Crear permisos
puts "Creando permisos..."
permissions_data = [
  { key: "containers.read", name: "Contenedores - Ver" },
  { key: "containers.create", name: "Contenedores - Crear" },
  { key: "containers.update", name: "Contenedores - Editar" },
  { key: "containers.destroy", name: "Contenedores - Eliminar" },

  { key: "bl_house_lines.read", name: "Partidas - Ver" },
  { key: "bl_house_lines.create", name: "Partidas - Crear" },
  { key: "bl_house_lines.update", name: "Partidas - Editar" },
  { key: "bl_house_lines.destroy", name: "Partidas - Eliminar" },

  { key: "catalogs.shipping_lines.manage", name: "Catálogos - Líneas Navieras" },
  { key: "catalogs.vessels.manage", name: "Catálogos - Buques" },
  { key: "catalogs.ports.manage", name: "Catálogos - Puertos" },
  { key: "catalogs.entities.manage", name: "Catálogos - Entidades" },
  { key: "catalogs.packagings.manage", name: "Catálogos - Embalajes" },

  { key: "admin.roles.manage", name: "Administración - Roles" },
  { key: "admin.users.manage", name: "Administración - Usuarios" },

  { key: "customs.dashboard.access", name: "Dashboard Agente Aduanal" }
]

permissions = permissions_data.map do |perm|
  Permission.find_or_create_by!(key: perm[:key]) do |p|
    p.name = perm[:name]
    p.description = perm[:description]
  end
end
puts "✓ #{Permission.count} permisos creados"

# Asignar permisos por rol (por defecto admin y ejecutivo tienen todos)
admin_role.permissions = permissions
executive_role.permissions = permissions
customs_broker_role.permissions = permissions.select { |p| %w[customs.dashboard.access bl_house_lines.read bl_house_lines.update].include?(p.key) }
puts "✓ Permisos asignados a roles"

# Crear usuario admin inicial (solo en desarrollo)
if Rails.env.development?
  puts "Creando usuario admin de prueba..."
  admin = User.find_or_initialize_by(email: 'admin@desycon.com')
  admin.password = 'password123' if admin.new_record?
  admin.password_confirmation = 'password123' if admin.new_record?
  admin.role = admin_role
  admin.save! if admin.changed? || admin.new_record?
  puts "✓ Usuario admin creado (admin@desycon.com / password123)"
end

# Crear puertos principales de México y USA
puts "Creando puertos..."

mexican_ports = [
  { name: 'Veracruz', code: 'MXVER', country_code: 'MX' },
  { name: 'Manzanillo', code: 'MXZLO', country_code: 'MX' },
  { name: 'Altamira', code: 'MXATM', country_code: 'MX' },
  { name: 'Lázaro Cárdenas', code: 'MXLZC', country_code: 'MX' },
  { name: 'Ensenada', code: 'MXENS', country_code: 'MX' },
  { name: 'Progreso', code: 'MXPGR', country_code: 'MX' },
  { name: 'Tuxpan', code: 'MXTUX', country_code: 'MX' },
  { name: 'Coatzacoalcos', code: 'MXCOA', country_code: 'MX' },
  { name: 'Tampico', code: 'MXTAM', country_code: 'MX' },
  { name: 'Guaymas', code: 'MXGYM', country_code: 'MX' }
]

china_ports = [
  { name: 'Shanghai', code: 'CNSHA', country_code: 'CN' },
  { name: 'Shenzhen', code: 'CNSZX', country_code: 'CN' },
  { name: 'Ningbo', code: 'CNNGB', country_code: 'CN' },
  { name: 'Guangzhou', code: 'CNCAN', country_code: 'CN' },
  { name: 'Qingdao', code: 'CNTAO', country_code: 'CN' },
  { name: 'Tianjin', code: 'CNTSN', country_code: 'CN' },
  { name: 'Xiamen', code: 'CNXMN', country_code: 'CN' },
  { name: 'Dalian', code: 'CNDLC', country_code: 'CN' },
  { name: 'Hong Kong', code: 'HKHKG', country_code: 'HK' },
  { name: 'Yantian', code: 'CNYTN', country_code: 'CN' },
  { name: 'Fuzhou', code: 'CNFOC', country_code: 'CN' },
  { name: 'Zhangjiagang', code: 'CNZJG', country_code: 'CN' },
  { name: 'Jiangyin', code: 'CNJIY', country_code: 'CN' },
  { name: 'Lianyungang', code: 'CNLYG', country_code: 'CN' },
  { name: 'Nansha', code: 'CNNAS', country_code: 'CN' },
  { name: 'Taicang', code: 'CNTCG', country_code: 'CN' },
  { name: 'Weihai', code: 'CNWEH', country_code: 'CN' },
  { name: 'Zhenjiang', code: 'CNZJG', country_code: 'CN' },
  { name: 'Zhoushan', code: 'CNZOS', country_code: 'CN' },
  { name: 'Beihai', code: 'CNBHY', country_code: 'CN' },
  { name: 'Changshu', code: 'CNCSU', country_code: 'CN' },
  { name: 'Chongqing', code: 'CNCQG', country_code: 'CN' },
  { name: 'Foshan', code: 'CNFOS', country_code: 'CN' },
  { name: 'Ganzhou', code: 'CNGZH', country_code: 'CN' },
  { name: 'Huangpu', code: 'CNHGP', country_code: 'CN' },
  { name: 'Jiujiang', code: 'CNJJG', country_code: 'CN' },
  { name: 'Kunming', code: 'CNKMG', country_code: 'CN' },
  { name: 'Lanzhou', code: 'CNLZH', country_code: 'CN' },
  { name: 'Nanchang', code: 'CNNCG', country_code: 'CN' },
  { name: 'Shantou', code: 'CNSWT', country_code: 'CN' },
  { name: 'Wuhan', code: 'CNWHG', country_code: 'CN' },
  { name: 'Xiangtan', code: 'CNXTG', country_code: 'CN' }
]

south_korea_ports = [
  { name: 'Busan', code: 'KRPUS', country_code: 'KR' },
  { name: 'Incheon', code: 'KRINC', country_code: 'KR' },
  { name: 'Gwangyang', code: 'KRGYG', country_code: 'KR' },
  { name: 'Ulsan', code: 'KRUSN', country_code: 'KR' }
]

japan_ports = [
  { name: 'Tokyo', code: 'JPTYO', country_code: 'JP' },
  { name: 'Yokohama', code: 'JPYOK', country_code: 'JP' },
  { name: 'Osaka', code: 'JPOSA', country_code: 'JP' },
  { name: 'Nagoya', code: 'JPNGO', country_code: 'JP' },
  { name: 'Kobe', code: 'JPKOB', country_code: 'JP' }
]

singapore_ports = [
  { name: 'Singapore', code: 'SGSIN', country_code: 'SG' }
]

malaysia_ports = [
  { name: 'Port Klang', code: 'MYPKL', country_code: 'MY' }
]

tailand_ports = [
  { name: 'Laem Chabang', code: 'THLCH', country_code: 'TH' }
]

united_states_ports = [
  { name: 'Los Angeles', code: 'USLAX', country_code: 'US' },
  { name: 'Long Beach', code: 'USLGB', country_code: 'US' },
  { name: 'New York', code: 'USNYC', country_code: 'US' },
  { name: 'Savannah', code: 'USSAV', country_code: 'US' },
  { name: 'Houston', code: 'USHOU', country_code: 'US' },
  { name: 'Seattle', code: 'USSEA', country_code: 'US' },
  { name: 'Charleston', code: 'USCHS', country_code: 'US' },
  { name: 'Oakland', code: 'USOAK', country_code: 'US' },
  { name: 'Miami', code: 'USMIA', country_code: 'US' },
  { name: 'Norfolk', code: 'USORF', country_code: 'US' },
  { name: 'Tacoma', code: 'USTAC', country_code: 'US' },
  { name: 'Port Everglades', code: 'USEVG', country_code: 'US' },
  { name: 'Jacksonville', code: 'USJAX', country_code: 'US' },
  { name: 'Baltimore', code: 'USBAL', country_code: 'US' },
  { name: 'San Francisco', code: 'USSFO', country_code: 'US' },
  { name: 'Philadelphia', code: 'USPHL', country_code: 'US' },
  { name: 'Boston', code: 'USBOS', country_code: 'US' },
  { name: 'Portland', code: 'USPDX', country_code: 'US' },
  { name: 'San Diego', code: 'USSAN', country_code: 'US' },
  { name: 'Cleveland', code: 'USCLE', country_code: 'US' }
]

chilean_ports = [
  { name: 'Valparaíso', code: 'CLVAP', country_code: 'CL' },
  { name: 'San Antonio', code: 'CLSAA', country_code: 'CL' },
  { name: 'Iquique', code: 'CLIQE', country_code: 'CL' },
  { name: 'Antofagasta', code: 'CLANF', country_code: 'CL' }
]

panamanian_ports = [
  { name: 'Balboa', code: 'PABLB', country_code: 'PA' },
  { name: 'Colón', code: 'PACON', country_code: 'PA' }
]

colombian_ports = [
  { name: 'Cartagena', code: 'COCTG', country_code: 'CO' },
  { name: 'Barranquilla', code: 'COBAQ', country_code: 'CO' }
]

brazilian_ports = [
  { name: 'Santos', code: 'BRSSZ', country_code: 'BR' },
  { name: 'Rio de Janeiro', code: 'BRRIO', country_code: 'BR' }
]

(mexican_ports + china_ports + south_korea_ports + japan_ports + singapore_ports +
 malaysia_ports + tailand_ports + united_states_ports + chilean_ports + panamanian_ports + colombian_ports + brazilian_ports).each do |port_data|
  port = Port.find_or_initialize_by(code: port_data[:code])
  port.assign_attributes(name: port_data[:name], country_code: port_data[:country_code])
  port.save! if port.changed?
end

puts "✓ #{Port.count} puertos creados"

# Crear líneas navieras con sus códigos ISO
puts "Creando líneas navieras..."

shipping_lines_data = [
  { name: "COSCO", iso_code: "COS" },
  { name: "LPA", iso_code: "LPA" },
  { name: "HAMBURG SUD", iso_code: "SUD" },
  { name: "CMA CGM", iso_code: "CMD" },
  { name: "ONE", iso_code: "ONE" },
  { name: "PACIFIC INTERNATIONAL LINES", iso_code: "PIL" },
  { name: "YANG MING LINE", iso_code: "YML" },
  { name: "ZIM", iso_code: "ZIM" },
  { name: "Wan Hai Lines", iso_code: "WHL" },
  { name: "Regional Container Lines", iso_code: "RCO" },
  { name: "Mediterranean Shipping Company", iso_code: "MSO" },
  { name: "Bal Container Line", iso_code: "BAL" },
  { name: "TS Lines", iso_code: "TSL" },
  { name: "Korea Marine Transport", iso_code: "KMO" }
]

shipping_lines_data.each do |line_data|
  shipping_line = ShippingLine.find_or_initialize_by(name: line_data[:name])
  shipping_line.iso_code = line_data[:iso_code] if shipping_line.iso_code.blank?
  shipping_line.save!(validate: false) if shipping_line.new_record? || shipping_line.changed?
end

puts "✓ #{ShippingLine.count} líneas navieras creadas"

# Crear entidades de ejemplo
puts "Creando entidades de ejemplo..."

# Agentes aduanales de ejemplo
customs_agents_data = [
  { name: "Agencia Aduanal García & Asociados", is_customs_agent: true },
  { name: "Despachos Aduanales Ramírez S.A.", is_customs_agent: true },
  { name: "Servicios Aduanales López", is_customs_agent: true },
  { name: "Agencia Aduanal Martínez", is_customs_agent: true }
]

customs_agents_data.each do |agent_data|
  entity = Entity.find_or_initialize_by(name: agent_data[:name])
  entity.assign_attributes(agent_data)
  entity.save! if entity.changed? || entity.new_record?
end

# Clientes de ejemplo
clients_data = [
  { name: "Importadora ABC S.A. de C.V.", is_client: true },
  { name: "Comercial XYZ Ltda.", is_client: true },
  { name: "Distribuidora Nacional", is_client: true }
]

clients_data.each do |client_data|
  entity = Entity.find_or_initialize_by(name: client_data[:name])
  entity.assign_attributes(client_data)
  entity.save! if entity.changed? || entity.new_record?
end

# Catálogo de servicios base
puts "Creando catálogo de servicios..."
services_catalog_data = [
  { name: "Coordinación de contenedor a almacén", applies_to: "container", code: "CONT-COOR", amount: 1500.00, currency: "MXN" },
  { name: "Asignación electrónica de carga", applies_to: "bl_house_line", code: "BL-ASIG", amount: 950.00, currency: "MXN" }
]

services_catalog_data.each do |service_data|
  service = ServiceCatalog.find_or_initialize_by(name: service_data[:name], applies_to: service_data[:applies_to])
  service.code = service_data[:code]
  service.amount = service_data[:amount]
  service.currency = service_data[:currency]
  service.active = true
  service.save! if service.changed? || service.new_record?
end
puts "✓ #{ServiceCatalog.count} servicios en catálogo"

# Consolidador de ejemplo (requerido por Container)
consolidators_data = [
  { name: "Consolidadora Demo", is_consolidator: true }
]

consolidators_data.each do |consolidator_data|
  entity = Entity.find_or_initialize_by(name: consolidator_data[:name])
  entity.assign_attributes(consolidator_data)
  entity.save! if entity.changed? || entity.new_record?
end

puts "✓ #{Entity.count} entidades creadas"

# Crear usuarios de ejemplo asociados a entidades
puts "Creando usuarios de ejemplo..."

# Usuario para agencia aduanal
customs_broker_role = Role.find_by(name: Role::CUSTOMS_BROKER)
customs_agent_entity = Entity.find_by(name: "Agencia Aduanal García & Asociados")

if customs_broker_role && customs_agent_entity
  customs_user = User.find_or_initialize_by(email: 'agente@garcia.com')
  customs_user.password = 'password123' if customs_user.new_record?
  customs_user.password_confirmation = 'password123' if customs_user.new_record?
  customs_user.role = customs_broker_role
  customs_user.entity = customs_agent_entity
  customs_user.save! if customs_user.changed? || customs_user.new_record?
  puts "✓ Usuario agente aduanal creado (agente@garcia.com / password123)"
end

# Crear BL House Lines de ejemplo
puts "Creando BL House Lines de ejemplo..."

customs_agent_entity = Entity.find_by(name: "Agencia Aduanal García & Asociados")
client_entity = Entity.find_by(name: "Importadora ABC S.A. de C.V.")
consolidator_entity = Entity.find_by(is_consolidator: true)
shipping_line = ShippingLine.first
vessel = Vessel.first || Vessel.find_or_create_by!(name: "SEED VESSEL")
origin_port = Port.first || Port.find_or_create_by!(code: "MXMZO", name: "Manzanillo", country: "México")
destination_port = Port.where.not(id: origin_port&.id).first ||
                   Port.find_or_create_by!(code: "MXVER", name: "Veracruz", country: "México")

voyage = nil
if vessel && destination_port
  voyage = Voyage.find_or_create_by!(vessel: vessel, viaje: "SEED-001") do |v|
    v.voyage_type = "arribo"
    v.destination_port = destination_port
    v.eta = 7.days.from_now
  end
end

# Crear contenedor de ejemplo si no existe
container = Container.find_or_initialize_by(number: "ABCD1234567", bl_master: "BL-SEED-001")
container.assign_attributes(
  consolidator_entity: consolidator_entity,
  shipping_line: shipping_line,
  vessel: vessel,
  voyage: voyage,
  origin_port: origin_port,
  status: "activo",
  tipo_maniobra: "importacion",
  type_size: "40HC",
  recinto: "CONTECON",
  almacen: "SSA",
  archivo_nr: "NR-SEED-001",
  sello: "SELLO001",
  ejecutivo: "Seed Ejecutivo"
)
container.save! if container.changed? || container.new_record?

service_catalog_container = ServiceCatalog.find_by(name: "Coordinación de contenedor a almacén", applies_to: "container") || ServiceCatalog.for_containers.first
if container && service_catalog_container
  ContainerService.find_or_create_by!(container: container, service_catalog: service_catalog_container) do |service|
    service.fecha_programada = Date.today + 3.days
    service.observaciones = "Servicio de coordinación para traslado a almacén"
  end
end

packaging = Packaging.first || Packaging.create!(nombre: "Cajas")

if customs_agent_entity && client_entity && container && packaging
  bl_house_lines_data = [
    { blhouse: "ABC123456789", status: "activo", cantidad: 100, partida: 1 },
    { blhouse: "DEF987654321", status: "documentos_ok", cantidad: 200, partida: 2 },
    { blhouse: "GHI456789123", status: "listo", cantidad: 150, partida: 3 },
    { blhouse: "JKL789123456", status: "revalidado", cantidad: 80, partida: 4 }
  ]

  bl_house_lines_data.each do |bl_data|
    bl = BlHouseLine.find_or_initialize_by(blhouse: bl_data[:blhouse])
    bl.assign_attributes(
      customs_agent: customs_agent_entity,
      client: client_entity,
      container: container,
      packaging: packaging,
      status: bl_data[:status],
      cantidad: bl_data[:cantidad],
      partida: bl_data[:partida],
      peso: 1000.0,
      volumen: 10.0,
      contiene: "Mercancía de ejemplo",
      marcas: "SEED-MARCA"
    )
    bl.save! if bl.changed? || bl.new_record?
  end

  puts "✓ #{BlHouseLine.count} BL House Lines creadas"

  service_catalog_bl = ServiceCatalog.find_by(name: "Asignación electrónica de carga", applies_to: "bl_house_line") || ServiceCatalog.for_bl_house_lines.first
  if service_catalog_bl && (bl = BlHouseLine.find_by(blhouse: bl_house_lines_data.first[:blhouse]))
    BlHouseLineService.find_or_create_by!(bl_house_line: bl, service_catalog: service_catalog_bl) do |service|
      service.fecha_programada = Date.today + 5.days
      service.observaciones = "Asignación electrónica de la carga para despacho aduanal"
    end
  end
end

puts "Seeds completados exitosamente!"
