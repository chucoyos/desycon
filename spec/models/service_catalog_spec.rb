require "rails_helper"

RSpec.describe ServiceCatalog, type: :model do
  describe "validations" do
    it "does not allow duplicate code within the same applies_to" do
      create(:service_catalog, applies_to: "container", code: "SRV-UNIQ")

      duplicate = build(:service_catalog, applies_to: "container", code: "srv-uniq")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors.of_kind?(:code, :taken)).to be(true)
    end

    it "allows same code for different applies_to" do
      create(:service_catalog, applies_to: "container", code: "SRV-CROSS")

      other_scope = build(:service_catalog, applies_to: "bl_house_line", code: "srv-cross")

      expect(other_scope).to be_valid
    end
  end
end
