FactoryBot.define do
  factory :entity_email_recipient do
    association :entity, factory: [ :entity, :customs_agent ]
    sequence(:email) { |n| "destinatario#{n}@correo.com" }
    active { true }
    primary_recipient { false }
    sequence(:position) { |n| n }

    trait :primary do
      primary_recipient { true }
      position { 0 }
    end
  end
end
