FactoryBot.define do
  factory :invoice_payment do
    association :invoice
    amount { 500.0 }
    currency { 'MXN' }
    paid_at { Time.current }
    payment_method { '03' }
    reference { 'REF-001' }
    status { 'registered' }
  end
end
