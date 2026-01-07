
admin_role = Role.find_by(name: Role::ADMIN)
exec_role = Role.find_by(name: Role::EXECUTIVE)

puts "Admin role found: #{admin_role.present?}"
puts "Executive role found: #{exec_role.present?}"

recipients = User.joins(:role).where(roles: { name: [Role::ADMIN, Role::EXECUTIVE] })
puts "Recipients found: #{recipients.count}"
recipients.each { |r| puts " - #{r.email}" }

# Simulate notification creation
if recipients.any? && BlHouseLine.last
  puts "Creating sample notification..."
  n = Notification.create!(
    recipient: recipients.first,
    actor: recipients.first, # Self notification for test
    action: "test notification",
    notifiable: BlHouseLine.last
  )
  puts "Notification created: #{n.persisted?}"
  puts "Broadcasting..."
  # n.broadcast_to_recipient # This is private, but after_create_commit should have triggered it
end
