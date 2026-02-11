require 'rails_helper'

# Specs in this file have access to a helper object that includes
# the BlHouseLinesHelper. For example:
#
# describe BlHouseLinesHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end
RSpec.describe BlHouseLinesHelper, type: :helper do
  describe "#bl_house_line_status_badge_class" do
    it "returns the badge class for known status" do
      expect(helper.bl_house_line_status_badge_class("activo")).to eq("bg-indigo-100 text-indigo-800")
    end

    it "falls back to default for unknown status" do
      expect(helper.bl_house_line_status_badge_class("unknown")).to eq("bg-gray-100 text-gray-800")
    end
  end

  describe "#bl_house_line_status_icon" do
    it "returns an svg string for known status" do
      expect(helper.bl_house_line_status_icon("activo")).to include("<svg")
    end
  end

  describe "#bl_house_line_status_nombre" do
    it "returns a human label for known status" do
      expect(helper.bl_house_line_status_nombre("revalidado")).to eq("Revalidado")
    end

    it "returns Desconocido for nil" do
      expect(helper.bl_house_line_status_nombre(nil)).to eq("Desconocido")
    end
  end
end
