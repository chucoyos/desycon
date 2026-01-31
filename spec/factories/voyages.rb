FactoryBot.define do
  factory :voyage do
    sequence(:viaje) { |n| "V#{n.to_s.rjust(3, '0')}" }
    voyage_type { 'arribo' }
    association :vessel
    association :destination_port, factory: :port
    eta { Date.today + 7.days }
    ata { Date.today + 10.days }
  end
end
