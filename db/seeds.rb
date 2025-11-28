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
  { name: 'Dalian', code: 'CNDLC', country_code: 'CN' }
]

(mexican_ports + china_ports).each do |port_data|
  port = Port.find_or_initialize_by(code: port_data[:code])
  port.assign_attributes(name: port_data[:name], country_code: port_data[:country_code])
  port.save! if port.changed?
end

puts "✓ #{Port.count} puertos creados"

puts "Seeds completados exitosamente!"
