FactoryBot.define do
  factory :consolidator do
    sequence(:name) { |n| "Consolidador #{n}" }

    # Traits para crear con datos completos
    trait :with_fiscal_profile do
      after(:create) do |consolidator|
        create(:fiscal_profile, profileable: consolidator)
      end
    end

    trait :with_fiscal_address do
      after(:create) do |consolidator|
        create(:address, addressable: consolidator, tipo: 'fiscal')
      end
    end

    trait :with_shipping_address do
      after(:create) do |consolidator|
        create(:address, :envio, addressable: consolidator)
      end
    end

    trait :complete do
      after(:create) do |consolidator|
        create(:fiscal_profile, profileable: consolidator)
        create(:address, addressable: consolidator, tipo: 'fiscal')
        create(:address, :envio, addressable: consolidator)
      end
    end
  end
end
