FactoryBot.define do
  factory :customs_agent_patent do
    association :entity
    sequence(:patent_number) { |n| "#{3000 + n}" }
  end
end
