FactoryBot.define do
  sequence(:broker_patent_number) { |n| "#{3000 + n}" }

  factory :entity do
    sequence(:name) { |n| "Entidad #{n}" }
    role_kind { "client" }

    trait :consolidator do
      role_kind { "consolidator" }
    end

    trait :customs_agent do
      role_kind { "customs_agent" }
    end

    trait :customs_broker do
      role_kind { "customs_broker" }
      patent_number { generate(:broker_patent_number) }
    end

    trait :forwarder do
      role_kind { "forwarder" }
    end

    trait :client do
      role_kind { "client" }
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
      role_kind { "client" }
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
