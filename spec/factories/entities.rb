FactoryBot.define do
  factory :entity do
    sequence(:name) { |n| "Entidad #{n}" }
    is_consolidator { true }
    is_customs_agent { true }
    is_forwarder { false }
    is_client { false }

    trait :consolidator do
      is_consolidator { true }
    end

    trait :customs_agent do
      is_customs_agent { true }
    end

    trait :forwarder do
      is_forwarder { true }
    end

    trait :client do
      is_client { true }
    end

    trait :with_fiscal_profile do
      after(:create) do |entity|
        create(:fiscal_profile, profileable: entity) unless entity.fiscal_profile.present?
      end
    end

    trait :with_address do
      after(:create) do |entity|
        create(:address, addressable: entity, tipo: 'fiscal') unless entity.addresses.any?
      end
    end

    trait :with_addresses do
      after(:create) do |entity|
        create_list(:address, 2, addressable: entity) if entity.addresses.empty?
      end
    end

    trait :with_patents do
      customs_agent

      after(:create) do |entity|
        create_list(:customs_agent_patent, 2, entity: entity)
      end
    end

    trait :complete do
      consolidator
      after(:create) do |entity|
        create(:fiscal_profile, profileable: entity)
        create(:address, addressable: entity, tipo: 'fiscal')
      end
    end
  end
end
