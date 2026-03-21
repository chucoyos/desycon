FactoryBot.define do
  factory :invoice_service_link do
    association :invoice
    association :serviceable, factory: :container_service
  end
end
