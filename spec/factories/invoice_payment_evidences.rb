FactoryBot.define do
  factory :invoice_payment_evidence do
    association :invoice
    association :customs_agent, factory: [ :entity, :customs_agent ]
    association :submitted_by, factory: [ :user, :customs_broker ]
    reference { "BLH-REF-001" }
    tracking_key { "TRACK-001" }
    status { "pending" }

    after(:build) do |evidence|
      next if evidence.receipt_file.attached?

      evidence.receipt_file.attach(
        io: StringIO.new("fake receipt content"),
        filename: "receipt.pdf",
        content_type: "application/pdf"
      )
    end
  end
end
