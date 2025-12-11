FactoryBot.define do
  factory :shipping_line do
    sequence(:name) { |n| "Shipping Line #{n}" }
    sequence(:scac_code) { |n| "TEST#{n.to_s.rjust(1, '0')}" }
  end
end
