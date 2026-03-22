require "rails_helper"

RSpec.describe BlHouseLines::EntregaAlmacenCamionCalculator do
  describe ".call" do
    let(:bl_house_line) { build(:bl_house_line, peso: peso, volumen: volumen) }
    let(:unit_price) { BigDecimal("126") }

    subject(:result) do
      described_class.call(
        bl_house_line: bl_house_line,
        unit_price: unit_price
      )
    end

    context "when weight has decimals" do
      let(:peso) { 13.2 }
      let(:volumen) { 8.1 }

      it "rounds weight up and uses it when greater" do
        expect(result.weight_units).to eq(14)
        expect(result.billable_units).to eq(14)
        expect(result.total).to eq(BigDecimal("1764"))
      end
    end

    context "when volume is greater than weight" do
      let(:peso) { 6.4 }
      let(:volumen) { 10.4 }

      it "charges using rounded volume" do
        expect(result.billable_units).to eq(12)
        expect(result.total).to eq(BigDecimal("1512"))
      end
    end

    context "when both are below minimum units" do
      let(:peso) { 3 }
      let(:volumen) { 6 }

      it "applies minimum of 12 units" do
        expect(result.billable_units).to eq(12)
        expect(result.total).to eq(BigDecimal("1512"))
      end
    end
  end
end
