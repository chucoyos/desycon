FactoryBot.define do
  factory :notification do
    association :recipient, factory: :user
    association :actor, factory: :user
    action { "test notification" }
    association :notifiable, factory: :bl_house_line
    read_at { nil }

    trait :read do
      read_at { Time.current }
    end

    trait :unread do
      read_at { nil }
    end

    trait :revalidado do
      action { "revalidado" }
    end

    trait :solicitud_revalidacion do
      action { "solicitó revalidación" }
    end

    trait :recent do
      created_at { Time.current }
    end

    trait :old do
      created_at { 1.week.ago }
    end
  end
end
