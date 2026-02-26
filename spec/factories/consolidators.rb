FactoryBot.define do
  factory :consolidator do
    # Always create an entity with consolidator role
    entity { association :entity, :consolidator }

    # Traits para crear con datos completos
    trait :with_fiscal_profile do
      entity { association :entity, :consolidator, :with_fiscal_profile }
    end

    trait :with_fiscal_address do
      entity { association :entity, :consolidator, :with_address }
    end

    trait :with_addresses do
      entity { association :entity, :consolidator, :with_addresses }
    end

    trait :with_shipping_address do
      after(:create) do |consolidator|
        create(:address, :sucursal, addressable: consolidator.entity)
      end
    end

    trait :complete do
      entity { association :entity, :consolidator, :complete }
    end
  end
end
