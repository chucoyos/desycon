FactoryBot.define do
  factory :photo_download_link do
    association :attachable, factory: :container
    association :created_by, factory: :user

    section { "apertura" }
    expires_at { 72.hours.from_now }
    revoked_at { nil }
    last_accessed_at { nil }

    trait :for_bl_house_line do
      association :attachable, factory: :bl_house_line
      section { "etiquetado" }
    end

    trait :revoked do
      association :revoked_by, factory: :user
      revoked_at { Time.current }
    end

    trait :expired do
      expires_at { 1.hour.ago }
    end
  end
end
