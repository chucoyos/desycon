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
  describe "#bl_service_calculation_breakdown" do
    it "shows the flat-rate calculation for Lázaro storage" do
      allow(helper).to receive(:temporary_service_breakdown_enabled?).and_return(true)
      port = create(:port, code: "MXLZC", country_code: "MX")
      container = create(:container, voyage: create(:voyage, destination_port: port), fecha_desconsolidacion: Date.new(2026, 3, 20))
      line = create(:bl_house_line, container: container, peso: 12_000, volumen: 10, fecha_despacho: Time.zone.local(2026, 3, 27))
      catalog = create(:service_catalog, code: "BL-ALM-LZC", applies_to: "bl_house_line", amount: 100)
      service = create(:bl_house_line_service, bl_house_line: line, service_catalog: catalog)

      breakdown = helper.bl_service_calculation_breakdown(service)
      expect(breakdown[:calculated_amount]).to eq(1200)
      expect(helper.bl_service_breakdown_rows(breakdown)).to include([ "Precio unitario", BigDecimal("100") ])
    end
  end

  describe "#bl_service_breakdown_rows" do
    it "hides unit price for ALMA and includes tariff metadata" do
      rows = helper.bl_service_breakdown_rows(
        {
          service_code: "BL-ALMA",
          operation_type: "importacion",
          destination_port_code: "MXATM",
          tariff_source: "Tramos Altamira por puerto destino",
          unit_price: BigDecimal("126"),
          daily_subtotal: BigDecimal("9250")
        }
      )

      expect(rows).to include([ "Tipo maniobra", "importacion" ])
      expect(rows).to include([ "Fuente de tarifa", "Tramos Altamira por puerto destino" ])
      expect(rows).not_to include([ "Precio unitario", BigDecimal("126") ])
      expect(rows).to include([ "Subtotal diario", BigDecimal("9250") ])
    end

    it "keeps generic unit price label for non-ALMA services" do
      rows = helper.bl_service_breakdown_rows(
        {
          service_code: "BL-ENTCAM",
          unit_price: BigDecimal("126")
        }
      )

      expect(rows).to include([ "Precio unitario", BigDecimal("126") ])
    end
  end

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
