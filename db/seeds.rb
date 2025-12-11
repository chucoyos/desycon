# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Crear roles
puts "Creando roles..."
admin_role = Role.find_or_create_by!(name: Role::ADMIN)
operator_role = Role.find_or_create_by!(name: Role::OPERATOR)
customs_broker_role = Role.find_or_create_by!(name: Role::CUSTOMS_BROKER)
puts "✓ Roles creados"

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

# Crear líneas navieras con sus códigos SCAC
puts "Creando líneas navieras..."

shipping_lines_data = [
  { name: "Maersk", scac_code: "MAEU" },
  { name: "CMA CGM", scac_code: "CMDU" },
  { name: "Evergreen", scac_code: "EGLV" },
  { name: "COSCO Shipping Lines", scac_code: "COSU" },
  { name: "Hapag-Lloyd", scac_code: "HPGL" },
  { name: "Hapag-Lloyd México", scac_code: "HPLM" },
  { name: "Yang Ming Marine Transport Corporation", scac_code: "YMLU" },
  { name: "ONE", scac_code: "ONEY" },
  { name: "Hyundai Merchant Marine", scac_code: "HDMU" },
  { name: "Hyundai de México", scac_code: "HDMX" },
  { name: "PIL Pacific International Lines", scac_code: "PABV" },
  { name: "ZIM", scac_code: "ZIMU" },
  { name: "Wan Hai Lines", scac_code: "WHLC" },
  { name: "Kawasaki Kisen Kaisha", scac_code: "KKLU" },
  { name: "MOL", scac_code: "MOLU" },
  { name: "Nippon Yusen Kaisha", scac_code: "NYKS" },
  { name: "China Shipping Container Lines", scac_code: "CSCL" },
  { name: "Regional Container Line", scac_code: "RCLU" },
  { name: "LPA", scac_code: "LPAA" },
  { name: "HAMBURG SUD", scac_code: "HSDU" },
  { name: "Mediterranean Shipping Company", scac_code: "MSCU" },
  { name: "Orient Overseas Container Line", scac_code: "OOLU" },
  { name: "Bal Container Line", scac_code: "BACL" },
  { name: "Consignataria Oseanica", scac_code: "COSO" },
  { name: "TS Lines", scac_code: "TSLU" },
  { name: "Sea Lead", scac_code: "SEAL" },
  { name: "Sinocor Merchant Marine", scac_code: "SKLU" },
  { name: "Corean Marine Transport Company", scac_code: "KMTC" }
]

shipping_lines_data.each do |line_data|
  shipping_line = ShippingLine.find_or_initialize_by(name: line_data[:name])
  shipping_line.scac_code = line_data[:scac_code] if shipping_line.scac_code.blank?
  shipping_line.save!(validate: false) if shipping_line.new_record? || shipping_line.changed?
end

puts "✓ #{ShippingLine.count} líneas navieras creadas"

puts "Seeds completados exitosamente!"
