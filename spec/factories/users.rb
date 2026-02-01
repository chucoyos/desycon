FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    association :role

    trait :disabled do
      disabled { true }
    end

    trait :admin do
      association :role, :admin
    end

    trait :executive do
      association :role, :executive
    end

    trait :customs_broker do
      association :role, :customs_broker
      association :entity, :customs_agent
    end
  end
end
