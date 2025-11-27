FactoryBot.define do
  factory :shipping_line do
    sequence(:name) { |n| "Shipping Line #{n}" }
  end
end
