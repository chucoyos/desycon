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
  User.find_or_create_by!(email: 'admin@desycon.com') do |user|
    user.password = 'password123'
    user.password_confirmation = 'password123'
    user.role = admin_role
  end
  puts "✓ Usuario admin creado (admin@desycon.com / password123)"
end

puts "Seeds completados exitosamente!"
