FactoryBot.define do
  factory :packaging do
    sequence(:nombre) { |n| "Packaging #{n}" }
  end
end
