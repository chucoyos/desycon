FactoryBot.define do
  factory :photo_archive_request do
    association :attachable, factory: :container
    association :requested_by, factory: :user

    section { "apertura" }
    status { "pending" }
    photos_count { nil }
    error_message { nil }
    generated_at { nil }
    expires_at { nil }

    trait :completed do
      status { "completed" }
      generated_at { 1.hour.ago }
      expires_at { 2.months.from_now }
      photos_count { 3 }
    end

    trait :failed do
      status { "failed" }
      error_message { "error" }
    end
  end
end
