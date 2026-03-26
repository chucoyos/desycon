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
        expect(result.breakdown).to include(
          weight_units: 14,
          volume_units: 9,
          minimum_units: 12,
          billable_units: 14,
          unit_price: BigDecimal("126"),
          imo_multiplier: BigDecimal("1"),
          formula: "unidades_cobrables * precio_unitario * multiplicador_imo",
          total: BigDecimal("1764")
        )
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

    context "when imo applies with clase and tipo different from 0" do
      let(:peso) { 13.2 }
      let(:volumen) { 8.1 }
      let(:bl_house_line) { build(:bl_house_line, peso: peso, volumen: volumen, clase_imo: "1", tipo_imo: "2") }

      it "doubles the total charge" do
        expect(result.billable_units).to eq(14)
        expect(result.total).to eq(BigDecimal("3528"))
      end
    end

    context "when only one imo field is different from 0" do
      let(:peso) { 13.2 }
      let(:volumen) { 8.1 }
      let(:bl_house_line) { build(:bl_house_line, peso: peso, volumen: volumen, clase_imo: "1", tipo_imo: "0") }

      it "does not double the total charge" do
        expect(result.total).to eq(BigDecimal("1764"))
      end
    end
  end
end
