FactoryBot.define do
  factory :photo do
    association :attachable, factory: :container
    section { "apertura" }

    after(:build) do |photo|
      next if photo.image.attached?

      photo.image.attach(
        io: StringIO.new("fake image data"),
        filename: "photo.jpg",
        content_type: "image/jpeg"
      )
    end

    trait :etiquetado do
      association :attachable, factory: :bl_house_line
      section { "etiquetado" }
    end
  end
end
