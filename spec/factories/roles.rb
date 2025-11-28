FactoryBot.define do
  factory :role do
    name { Role::OPERATOR }

    trait :admin do
      name { Role::ADMIN }
    end

    trait :operator do
      name { Role::OPERATOR }
    end

    trait :customs_broker do
      name { Role::CUSTOMS_BROKER }
    end
  end
end
