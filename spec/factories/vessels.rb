FactoryBot.define do
  factory :vessel do
    sequence(:name) { |n| "Vessel #{n}" }
    shipping_line
  end
end
