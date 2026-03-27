# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Crear roles
puts "Creando roles..."
admin_role = Role.find_or_create_by!(name: Role::ADMIN)
executive_role = Role.find_or_create_by!(name: Role::EXECUTIVE)
# Compatibilidad: se mantiene Role::CUSTOMS_BROKER como clave tecnica legacy en DB,
# pero en negocio/UI se muestra como "Agencia Aduanal".
customs_agency_role = Role.find_or_create_by!(name: Role::CUSTOMS_BROKER)
tramitador_role = Role.find_or_create_by!(name: Role::TRAMITADOR)
consolidator_role = Role.find_or_create_by!(name: Role::CONSOLIDATOR)
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
  permission = Permission.find_or_initialize_by(key: perm[:key])
  permission.name = perm[:name]
  permission.description = perm[:description]
  permission.save! if permission.changed? || permission.new_record?
  permission
end
puts "✓ #{Permission.count} permisos creados"

# Asignar permisos por rol (por defecto admin y ejecutivo tienen todos)
admin_role.permissions = permissions
executive_role.permissions = permissions
customs_agency_role.permissions = permissions.select { |p| %w[customs.dashboard.access bl_house_lines.read bl_house_lines.update].include?(p.key) }
tramitador_role.permissions = permissions.select { |p| %w[containers.read bl_house_lines.read].include?(p.key) }
consolidator_role.permissions = permissions.select { |p| %w[containers.read bl_house_lines.read].include?(p.key) }
puts "✓ Permisos asignados a roles"

# Datos demo deshabilitados por defecto para evitar sobreescrituras accidentales.
# Para habilitarlos temporalmente: SEED_DEMO_DATA=true bin/rails db:seed
seed_demo_data = ActiveModel::Type::Boolean.new.cast(ENV.fetch("SEED_DEMO_DATA", "false")) && !Rails.env.production?
puts "Modo demo deshabilitado (solo catálogo real)" unless seed_demo_data

# Crear usuario admin inicial (solo cuando se habilita modo demo)
if seed_demo_data
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
  { name: 'Zhenjiang',    code: 'CNZHE', country_code: 'CN' },
  { name: 'Jiaxing',      code: 'CNJIA', country_code: 'CN' },
  { name: 'Jiangyin', code: 'CNJIY', country_code: 'CN' },
  { name: 'Lianyungang', code: 'CNLYG', country_code: 'CN' },
  { name: 'Nansha', code: 'CNNAS', country_code: 'CN' },
  { name: 'Taicang', code: 'CNTCG', country_code: 'CN' },
  { name: 'Weihai', code: 'CNWEH', country_code: 'CN' },
  { name: 'Zhangjiagang', code: 'CNZJG', country_code: 'CN' },
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
  { name: "COSCO SHIPPING", iso_code: "COS" },
  { name: "LPA", iso_code: "LPA" },
  { name: "HAMBURG SUD", iso_code: "SUD" },
  { name: "CMA CGM", iso_code: "CMD" },
  { name: "ONE", iso_code: "ONE" },
  { name: "HAPAG-LLOYD MEXICO", iso_code: "HLM" },
  { name: "HYUNDAI DE MEXICO", iso_code: "HDM" },
  { name: "MAERSK", iso_code: "MRK" },
  { name: "EVERGREEN", iso_code: "EVG" },
  { name: "Mediterranean Shipping Company", iso_code: "MSO" },
  { name: "ORIENT OVERSEAS CONTAINER LINE", iso_code: "OOC" },
  { name: "WAN HAI LINES", iso_code: "WHL" },
  { name: "PIL/PACIFIC INTERNATIONAL LINES", iso_code: "PIL" },
  { name: "YANG MING MARINE TRANSPORT CORPORATION", iso_code: "YML" },
  { name: "Bal Container Line", iso_code: "BAL" },
  { name: "ZIM INTEGRATED SHIPPING SERVICES LTD", iso_code: "ZIM" },
  { name: "TS Lines", iso_code: "TSL" },
  { name: "SEA LEAD", iso_code: "SLD" },
  { name: "SINOKOR MERCHANT MARINE", iso_code: "SKR" },
  { name: "KOREA MARINE TRANSPORT", iso_code: "KMO" },
  { name: "REGIONAL CONTAINER LINE", iso_code: "RCO" }
]

normalized_shipping_lines = shipping_lines_data.each_with_object({}) do |line_data, acc|
  normalized_key = ActiveSupport::Inflector.transliterate(line_data[:name].to_s).upcase.gsub(/[^A-Z0-9]/, "")
  acc[normalized_key] ||= line_data
end

normalized_shipping_lines.values.each do |line_data|
  shipping_line = ShippingLine.find_by(iso_code: line_data[:iso_code]) ||
                  ShippingLine.find_by("LOWER(name) = ?", line_data[:name].downcase) ||
                  ShippingLine.new

  shipping_line.name = line_data[:name]
  shipping_line.iso_code = line_data[:iso_code]
  shipping_line.save! if shipping_line.new_record? || shipping_line.changed?
end

puts "✓ #{ShippingLine.count} líneas navieras creadas"

# Crear catálogo de buques
puts "Creando buques..."

vessel_names_raw = <<~VESSELS
  TEAM DEV
  AOTEA MAERSK
  CAP ANDREAS
  SM CHARLESTON
  TSINGTAO EXPRESS
  MSC ELISA
  SOVEREIGN MAERSK
  VANTAGE
  CMA CGM TUTI CORIN
  CZECH
  COPIAPO
  SEASPAN BRAVO
  RDO CONCORD
  VALOR
  MOL BEYOND
  MSC RUBY
  CMA CGM MUNDRA
  MOL BENEFACTOR
  VALUE
  MOL BENEFACTOR
  MSC MARGRIT
  SEASPAN BELIEF
  HMM BLESSING
  CMA CGM THAMES
  KOTA CANTIK
  CMA CGM ESTELLE
  SEASPAN BELLWETHER
  CAUTIN
  CMA CGM JACQUES JOSEPH
  MSC CAPELLA
  XIN FU ZHOU
  SEASPAN BEAUTY
  MOL BEACON
  CMA CGM OHIO
  CROATIA
  NAXOS
  MSC RENEE
  KOTA CEPAT
  COCHRANE
  COYHAIQUE
  NINGBO
  MSC PERLE
  CMA CGM ARKANSAS
  MSC KANOKO
  CORCOVADO
  WAN HAI 612
  VALIANT
  VALENCE
  CMA CGM MUMBAI
  CMA CGM GANGES
  MSC NATASHA
  CAUQUENES
  SKAGEN MAERSK
  NORDMARSH
  CISNES
  SAN FELIX
  KOTA CAHAYA
  MSC JEWEL
  MOL BEACON
  CAROLINE MAERSK
  SOFIE MAERSK
  A. P. MOLLER
  YM UTILITY
  NYK ISABEL
  CAPE PIONEER
  CHARLOTTE MAERSK
  EVER SUPERB
  SEALAND MICHIGAN
  XIN YA ZHOU
  HANSA GRANITE
  APL ESPLANADE
  CARSTEN MAERSK
  MERETE MAERSK
  SALLY MAERSK
  ITAL UNIVERSO
  CLIFFORD MAERSK
  DALI
  CMA CGM NIAGARA
  LONG BEACH TRADER
  SEASPAN BREEZE
  CORNELIUS MAERSK
  EVER LOTUS
  SAN FRANCISCO BRIDGE
  CSCL ASIA
  SVENDBORG MAERSK
  MAERSK STEPNICA
  COSCO PRINCE RUPERT
  SEASPAN BRIGHTNESS
  CMA CGM CALCUTTA
  NAVIGARE COLLECTOR
  SUSAN MAERSK
  CMA CGM ALASKA
  XIN OU ZHOU
  APL CHARLESTON
  CMA CGM NEVADA
  XIN SU ZHOU
  MAERSK SALINA
  EVER URANUS
  MAERSK SALALAH
  XIN FEI ZHOU
VESSELS

vessel_names = vessel_names_raw
  .split("\n")
  .map { |name| name.strip }
  .reject(&:blank?)
  .uniq

vessel_names.each do |name|
  vessel = Vessel.find_or_initialize_by(name: name)
  vessel.save! if vessel.new_record? || vessel.changed?
end

puts "✓ #{Vessel.count} buques creados"

# Crear catálogo de embalajes
puts "Creando embalajes..."

packagings_data = [
  "CAJAS DE MADERA",
  "SACOS",
  "ROLLOS",
  "PAQUETES",
  "PALLETS",
  "ATADOS",
  "CARTONES",
  "TAMBOS",
  "CUÑETES",
  "CAJAS"
]

packagings_data.each do |nombre|
  packaging = Packaging.find_by("LOWER(nombre) = ?", nombre.downcase) || Packaging.new
  packaging.nombre = nombre
  packaging.save! if packaging.new_record? || packaging.changed?
end

puts "✓ #{Packaging.count} embalajes creados"

upsert_entity = lambda do |attrs|
  entity = Entity.find_or_initialize_by(name: attrs[:name])
  entity.assign_attributes(attrs)
  entity.save! if entity.changed? || entity.new_record?
  entity
end

# Crear catálogo de agentes aduanales (personas con patente)
puts "Creando catálogo de agentes aduanales (personas con patente)..."

customs_agents_with_patents_data = [
  [ "PRODUCTION SYNERGIC", "0000" ],
  [ "CASSO FLORES ROBERTO", "3712" ],
  [ "VILLAVERDE RODOLFO", "3317" ],
  [ "MERCADO OCAMPO SANTIAGO JORGE ENRIQUE", "3884" ],
  [ "ZENDEJAS PORTUGAL CARLOS FELIPE", "1600" ],
  [ "ALMEIDA VALLES CECILIA", "3697" ],
  [ "CASSO CASSO CASSO", "3236" ],
  [ "MORELOS PAVON JOSE MARIA", "0012" ],
  [ "TONATZI AHIAT HUITZILOPOXTLI", "1001" ],
  [ "ROMO ROMERO ANTONIO", "3365" ],
  [ "PIZ ENRIQUEZ RAUL FRANCISCO", "1681" ],
  [ "BARRIOS CASTAÑO VERONICA", "1487" ],
  [ "ALVAREZ RAMIREZ SERGIO", "3931" ],
  [ "VILLAFUERTE COELLO EDUARDO", "3788" ],
  [ "CAREAGA MONCAYO LUIS JOAQUIN", "3900" ],
  [ "DELGADILLO CASILLAS JUAN CARLOS", "3450" ],
  [ "GOMEZ BARQUIN RAMON", "3622" ],
  [ "VALDEZ GOMEZ ALFREDO", "3719" ],
  [ "VIGIL CALZADA SILVIA", "3915" ],
  [ "SALDAÑA ZOLEZZI BERTHA", "3149" ],
  [ "DOMINGUEZ MURO JOSE MARTIN", "3296" ],
  [ "GOMEZ BARQUIN ALEJANDRO", "1762" ],
  [ "ORTEGON MARTINEZ MANUEL JUAN", "3957" ],
  [ "VALVERDE MONTERO VERONICA ANA LUISA", "3374" ],
  [ "HINOJOSA AGUERREVERE ENRIQUE MANUEL", "3200" ],
  [ "ALCANTARA ACEVEDO MONICA LETICIA", "3794" ],
  [ "AGUILLON PADILLA JOSE PEDRO", "1641" ],
  [ "VIÑALS ORTIZ DE LA PEÑA LUIS FERNANDO", "3448" ],
  [ "GUERRERO FLORES JOSE ANTONIO", "3481" ],
  [ "VILLASEÑOR SANCHEZ ARTURO ELEAZAR", "3879" ],
  [ "CARMONA MILLAN HECTOR RICARDO", "3737" ],
  [ "GARZA LOPEZ VICTORIANO", "3451" ],
  [ "HOYO GARCIA LUIS", "3862" ],
  [ "ANDERE NOGUEIRA GERARDO", "3992" ],
  [ "GOMEZ ABAD JOAQUIN", "3458" ],
  [ "CERDA DE LA TORRE SONIA ERIKA", "6071" ],
  [ "PALAZUELOS PEREZ ORONOZ ANDRES ENRIQUE", "3098" ],
  [ "JARA BORDI MIGUEL ANGEL", "3878" ],
  [ "ARREDONDO FLORES SIGFRIDO LUCIANO ALBERTO", "3387" ],
  [ "HUERTA CASTRO RICARDO", "1691" ],
  [ "CARDENAS GARZA MANUEL", "3320" ],
  [ "DEL VALLE BETANZO FERNANDO", "1609" ],
  [ "MEJIA MARTINEZ MARIA DE LA LUZ", "3487" ],
  [ "MURIS SALINAS VICTOR HORACIO", "3475" ],
  [ "WILLY KOLTER SUSAN LYNN", "3503" ],
  [ "KUTZ GIRAULT ANDER", "1626" ],
  [ "TENA BETANCOURT JORGE FELIX", "3545" ],
  [ "HERRERA MIER JOSE HUGO", "3178" ],
  [ "LEON ZAMORA IRENE ANGELINA", "3807" ],
  [ "RAMOS RAMIREZ ENRIQUE", "3850" ],
  [ "VILLANUEVA Y VAZQUEZ ROBERTO", "3154" ],
  [ "VENEGAS CUBERO MARIO HERBE", "3772" ],
  [ "SORIANO RIVERA ADOLFO", "3985" ],
  [ "DIAZ CASTRO JONATHAN", "3259" ],
  [ "PEREZ ORTIZ ALBERTO", "3575" ],
  [ "DIAZ GARCIA JORGE", "3621" ],
  [ "REYES DIAZ CARLOS MIGUEL", "1788" ],
  [ "ENCISO HERNANDEZ MANUEL ALEXIS", "1805" ],
  [ "GUTIERREZ ROBINSON FIDEL JOSE", "3581" ],
  [ "FERNANDEZ ESPINOSA FORTINO", "3065" ],
  [ "PRIDA BARRIO NELSON", "3052" ],
  [ "OBREGON CARRANZA MAYO JESUS", "3586" ],
  [ "MARABOTO ECHANOVE MANUEL ANTONIO", "1707" ],
  [ "GAMAS LUNA VICTOR HUGO", "3711" ],
  [ "MEJIA GONZALEZ JACOBO", "1786" ],
  [ "PEREZ TEJADA FELIX JUAN MANUEL", "3743" ],
  [ "VILLA GARCIA JORGE VICENTE", "3446" ],
  [ "GALICIA ESTRELLA ERNESTO", "3638" ],
  [ "ABUIN SALGADO CLAUDIA JUANA", "3927" ],
  [ "RUANOVA ZARATE MARIO DAVID", "0491" ],
  [ "RAMOS CASAS ROBERTO JOSE", "3037" ],
  [ "ULLOA ESQUER JOSE EDMUNDO RAMON", "1639" ],
  [ "ROJAS PALACIOS CLAUDIA JOSEFINA", "3623" ],
  [ "PURON ACEVEDO PEDRO RAMON", "3752" ],
  [ "GARZA MATA HECTOR FIDENCIO", "3540" ],
  [ "MAYER MARTINEZ OSCAR ALBERTO", "3611" ],
  [ "BARRENECHEA NARANJO FERNANDO IÑIGO", "1759" ],
  [ "DIAZ GARCIA EDUARDO", "3009" ],
  [ "CARVAJAL UDAVE ROSALINDA", "3953" ],
  [ "DUEÑAS HERNANDEZ RAFAEL", "1785" ],
  [ "ESQUER LUKEN FRANCISCO JAVIER", "3710" ],
  [ "ALONSO PEREZ GUSTAVO", "1410" ],
  [ "PACHECO MUÑOZ ARTURO", "1752" ],
  [ "MARTINEZ RICO JORGE IVAN", "1782" ],
  [ "ARONOVICH GANON MARIO", "1698" ],
  [ "VILLANUEVA ROMERO JULIO CESAR", "3289" ],
  [ "MARTIN DEL CAMPO ENRIQUE GUILLEMIN", "3832" ],
  [ "RELLO SALVATIERRA CARLOS ALBERTO", "1791" ],
  [ "VALDEZ GARATE JOSE RAYMUNDO", "1068" ],
  [ "MEJIA ARREOLA FERNANDO", "3321" ],
  [ "BARAJAS HILL JUAN DE JESUS", "3573" ],
  [ "CAREAGA DIAZ JAVIER EDUARDO", "3163" ],
  [ "MORENO HERNANDEZ ADID", "3990" ],
  [ "GUERRERO LUGO RAUL MANUEL", "3963" ],
  [ "DIAZ RAYA JORGE ANDRES", "1625" ],
  [ "TORRES FRIAS CARLOS ALEJANDRO", "3010" ],
  [ "ACIERNO VAZQUEZ LORENZO", "1669" ],
  [ "RODRIGUEZ RUIZ MARTIN", "3708" ],
  [ "ACIERNO VAZQUEZ RODRIGO", "1730" ],
  [ "SITTON ZONANA EDUARDO", "3539" ]
]

customs_agents_with_patents_data.each do |name, patent_number|
  entity = Entity.find_by(patent_number: patent_number) ||
           Entity.find_by("LOWER(name) = ?", name.downcase) ||
           Entity.new

  entity.name = name
  entity.role_kind = "customs_agent"
  entity.patent_number = patent_number
  entity.save! if entity.new_record? || entity.changed?
end

puts "✓ Agentes aduanales (personas con patente) cargados: #{customs_agents_with_patents_data.size}"

# Crear entidades de ejemplo
if seed_demo_data
  puts "Creando entidades de ejemplo..."

  # Clientes de ejemplo
  clients_data = [
    { name: "Importadora ABC S.A. de C.V.", role_kind: "client" },
    { name: "Comercial XYZ Ltda.", role_kind: "client" },
    { name: "Distribuidora Nacional", role_kind: "client" }
  ]

  clients_data.each do |client_data|
    upsert_entity.call(client_data)
  end
end

# Catálogo de servicios base
puts "Creando catálogo de servicios..."
services_catalog_data = [
  {
    name: "Coordinación de contenedor a almacén",
    applies_to: "container",
    code: "CONT-COOR",
    amount: 3500.00,
    currency: "MXN",
    sat_clave_prod_serv: "80151600",
    sat_clave_unidad: "E48",
    sat_objeto_imp: "02"
  },
  {
    name: "Asignación electrónica de carga",
    applies_to: "bl_house_line",
    code: "BL-ASIG",
    amount: 1200.00,
    currency: "MXN",
    sat_clave_prod_serv: "80151600",
    sat_clave_unidad: "E48",
    sat_objeto_imp: "02"
  },
  {
    name: "Almacenaje de Carga Suelta en Bodega",
    applies_to: "bl_house_line",
    code: "BL-ALMA",
    amount: 126.00,
    currency: "MXN",
    sat_clave_prod_serv: "80151600",
    sat_clave_unidad: "E48",
    sat_objeto_imp: "02"
  },
  {
    name: "Maniobra de Entrega Almacén a Camión",
    applies_to: "bl_house_line",
    code: "BL-ENTCAM",
    amount: 183.00,
    currency: "MXN",
    sat_clave_prod_serv: "80151600",
    sat_clave_unidad: "E48",
    sat_objeto_imp: "02"
  },
  {
    name: "Maniobra de Previo en Almacén",
    applies_to: "bl_house_line",
    code: "BL-PREVIO",
    amount: 365.00,
    currency: "MXN",
    sat_clave_prod_serv: "80151600",
    sat_clave_unidad: "E48",
    sat_objeto_imp: "02"
  },
  {
    name: "Reacomodo de Carga Suelta",
    applies_to: "bl_house_line",
    code: "BL-RECASU",
    amount: 183.00,
    currency: "MXN",
    sat_clave_prod_serv: "80151600",
    sat_clave_unidad: "E48",
    sat_objeto_imp: "02"
  }
]

services_catalog_data.each do |service_data|
  service = ServiceCatalog.find_or_initialize_by(name: service_data[:name], applies_to: service_data[:applies_to])
  service.code = service_data[:code]
  service.amount = service_data[:amount]
  service.currency = service_data[:currency]
  service.sat_clave_prod_serv = service_data[:sat_clave_prod_serv]
  service.sat_clave_unidad = service_data[:sat_clave_unidad]
  service.sat_objeto_imp = service_data[:sat_objeto_imp]
  service.active = true
  service.save! if service.changed? || service.new_record?
end
puts "✓ #{ServiceCatalog.count} servicios en catálogo"

# Consolidador de ejemplo (requerido por Container)
if seed_demo_data
  consolidators_data = [
    { name: "Consolidadora Demo", role_kind: "consolidator" }
  ]

  consolidators_data.each do |consolidator_data|
    upsert_entity.call(consolidator_data)
  end

  puts "✓ #{Entity.count} entidades creadas"

  # Crear usuarios de ejemplo asociados a entidades
  puts "Creando usuarios de ejemplo..."

  # Usuario demo para una agencia aduanal (usa una entidad real del catálogo de agentes con patente)
  customs_agency_role = Role.find_by(name: Role::CUSTOMS_BROKER)
  customs_agency_entity = Entity.find_by(name: "PRODUCTION SYNERGIC") ||
                          Entity.where(role_kind: "customs_agent").order(:name).first

  if customs_agency_role && customs_agency_entity
    customs_user = User.find_or_initialize_by(email: 'agente@garcia.com')
    customs_user.password = 'password123' if customs_user.new_record?
    customs_user.password_confirmation = 'password123' if customs_user.new_record?
    customs_user.role = customs_agency_role
    customs_user.entity = customs_agency_entity
    customs_user.save! if customs_user.changed? || customs_user.new_record?
    puts "✓ Usuario agente aduanal creado (agente@garcia.com / password123)"
  end

  # Crear BL House Lines de ejemplo
  puts "Creando BL House Lines de ejemplo..."

  client_entity = Entity.find_by(name: "Importadora ABC S.A. de C.V.")
  consolidator_entity = Entity.find_by(role_kind: "consolidator")
  shipping_line = ShippingLine.first
  vessel = Vessel.first || Vessel.find_or_create_by!(name: "SEED VESSEL")
  origin_port = Port.first || Port.find_or_create_by!(code: "MXMZO", name: "Manzanillo", country_code: "MX")
  destination_port = Port.where.not(id: origin_port&.id).first ||
                     Port.find_or_create_by!(code: "MXVER", name: "Veracruz", country_code: "MX")

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

  packaging = Packaging.find_by("LOWER(nombre) = ?", "cajas") || Packaging.first

  if customs_agency_entity && client_entity && container && packaging
    bl_house_lines_data = [
      { blhouse: "ABC123456789", status: "activo", cantidad: 100, partida: 1 },
      { blhouse: "DEF987654321", status: "documentos_ok", cantidad: 200, partida: 2 },
      { blhouse: "GHI456789123", status: "listo", cantidad: 150, partida: 3 },
      { blhouse: "JKL789123456", status: "revalidado", cantidad: 80, partida: 4 }
    ]

    bl_house_lines_data.each do |bl_data|
      bl = BlHouseLine.find_or_initialize_by(blhouse: bl_data[:blhouse])
      bl.assign_attributes(
        customs_agent: customs_agency_entity,
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
end

puts "Seeds completados exitosamente!"
