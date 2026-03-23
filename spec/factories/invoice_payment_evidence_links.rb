FactoryBot.define do
  factory :invoice_payment_evidence_link do
    association :invoice_payment_evidence
    association :invoice
  end
end
