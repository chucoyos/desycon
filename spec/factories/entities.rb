FactoryBot.define do
  sequence(:broker_patent_number) { |n| "#{3000 + n}" }

  factory :entity do
    sequence(:name) { |n| "Entidad #{n}" }
    is_consolidator { false }
    is_customs_agent { false }
    is_customs_broker { false }
    is_forwarder { false }
    is_client { true }
    trait :consolidator do
      is_consolidator { true }
    end

    trait :customs_agent do
      is_customs_agent { true }
    end

    trait :customs_broker do
      is_customs_broker { true }
      patent_number { generate(:broker_patent_number) }
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
        create(:address, addressable: entity, tipo: 'matriz') unless entity.addresses.any?
      end
    end

    trait :with_addresses do
      after(:create) do |entity|
        create_list(:address, 2, addressable: entity) if entity.addresses.empty?
      end
    end

    trait :with_patents do
      customs_broker
    end

    trait :client_of_customs_agent do
      is_client { true }
      is_customs_agent { false }
      customs_agent { create(:entity, :customs_agent) }
    end

    trait :complete do
      consolidator
      after(:create) do |entity|
        create(:fiscal_profile, profileable: entity)
        create(:address, addressable: entity, tipo: 'matriz')
      end
    end
  end
end
