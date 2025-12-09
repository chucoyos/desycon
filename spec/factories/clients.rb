FactoryBot.define do
  factory :client do
    association :entity, factory: [ :entity, :client ]
  end
end
