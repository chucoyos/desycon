require "rails_helper"

RSpec.describe Photo, type: :model do
  describe "validations" do
    it "is valid for container aperture photo" do
      photo = build(:photo, section: "apertura")

      expect(photo).to be_valid
    end

    it "rejects invalid section for container" do
      photo = build(:photo, section: "etiquetado")

      expect(photo).not_to be_valid
      expect(photo.errors[:section]).to include("no es válida para este registro")
    end

    it "allows etiquetado for bl house line" do
      photo = build(:photo, :etiquetado)

      expect(photo).to be_valid
    end

    it "requires an attached image" do
      photo = build(:photo)
      photo.image.detach

      expect(photo).not_to be_valid
      expect(photo.errors[:image]).to include("debe adjuntarse")
    end

    it "rejects non-image content types" do
      photo = build(:photo)
      photo.image.detach
      photo.image.attach(io: StringIO.new("pdf"), filename: "doc.pdf", content_type: "application/pdf")

      expect(photo).not_to be_valid
      expect(photo.errors[:image]).to include("debe ser una imagen válida (JPG, PNG, WEBP o HEIC)")
    end
  end
end
