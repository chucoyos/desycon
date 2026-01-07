FactoryBot.define do
  factory :notification do
    recipient { nil }
    actor { nil }
    read_at { "2026-01-07 02:23:40" }
    action { "MyString" }
    notifiable { nil }
  end
end
