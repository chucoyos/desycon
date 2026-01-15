FactoryBot.define do
  factory :vessel do
    sequence(:name) { |n| "Vessel #{n}" }
  end
end
