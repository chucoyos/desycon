FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    association :role

    trait :admin do
      association :role, :admin
    end

    trait :operator do
      association :role, :operator
    end

    trait :customs_broker do
      association :role, :customs_broker
    end
  end
end
