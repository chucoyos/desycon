FactoryBot.define do
  factory :voyage do
    sequence(:viaje) { |n| "V#{n.to_s.rjust(3, '0')}" }
    voyage_type { 'arribo' }
    association :vessel
    association :destination_port, factory: :port
    eta { Time.current + 7.days }
    ata { Time.current + 10.days }
  end
end
