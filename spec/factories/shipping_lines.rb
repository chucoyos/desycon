FactoryBot.define do
  factory :shipping_line do
    sequence(:name) { |n| "Shipping Line #{n}" }
    sequence(:iso_code) { |n| ('A'.ord + (n - 1) % 26).chr * 3 }
  end
end
