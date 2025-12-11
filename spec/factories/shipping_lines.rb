FactoryBot.define do
  factory :shipping_line do
    sequence(:name) { |n| "Shipping Line #{n}" }
    sequence(:scac_code) { |n| "T#{n.to_s.rjust(3, '0')}" }
  end
end
