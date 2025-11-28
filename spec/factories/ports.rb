FactoryBot.define do
  factory :port do
    sequence(:name) { |n| "Puerto #{n}" }
    sequence(:code) { |n| "MXP#{n.to_s.rjust(2, '0')}" }
    country_code { "MX" }

    trait :veracruz do
      name { "Puerto de Veracruz" }
      code { "MXVER" }
      country_code { "MX" }
    end

    trait :manzanillo do
      name { "Puerto de Manzanillo" }
      code { "MXZLO" }
      country_code { "MX" }
    end

    trait :los_angeles do
      name { "Port of Los Angeles" }
      code { "USLAX" }
      country_code { "US" }
    end
  end
end
