FactoryBot.define do
  factory :consolidator do
    # Always create an entity with consolidator role
    entity { association :entity, is_consolidator: true }

    # Traits para crear con datos completos
    trait :with_fiscal_profile do
      entity { association :entity, :with_fiscal_profile, is_consolidator: true }
    end

    trait :with_fiscal_address do
      entity { association :entity, :with_address, is_consolidator: true }
    end

    trait :with_addresses do
      entity { association :entity, :with_addresses, is_consolidator: true }
    end

    trait :with_shipping_address do
      after(:create) do |consolidator|
        create(:address, :envio, addressable: consolidator.entity)
      end
    end

    trait :complete do
      entity { association :entity, :complete, is_consolidator: true }
    end
  end
end
