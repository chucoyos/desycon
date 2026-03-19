FactoryBot.define do
  factory :role do
    name { Role::EXECUTIVE }

    trait :admin do
      name { Role::ADMIN }
    end

    trait :executive do
      name { Role::EXECUTIVE }
    end

    trait :customs_broker do
      name { Role::CUSTOMS_BROKER }
    end

    trait :tramitador do
      name { Role::TRAMITADOR }
    end

    trait :consolidator do
      name { Role::CONSOLIDATOR }
    end
  end
end
