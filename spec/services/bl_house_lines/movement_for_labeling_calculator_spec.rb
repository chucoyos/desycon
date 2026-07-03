require "rails_helper"

RSpec.describe BlHouseLines::MovementForLabelingCalculator do
  describe ".call" do
    let(:destination_port) { build(:port, code: "MXATM") }
    let(:container) { build(:container, destination_port: destination_port) }
    let(:bl_house_line) { build(:bl_house_line, peso: peso, volumen: volumen, container: container) }

    subject(:result) { described_class.call(bl_house_line: bl_house_line) }

    context "when destination is MXATM and weight is greater than volume" do
      let(:peso) { 15_500 }
      let(:volumen) { 8.1 }

      it "charges weight units at $365/unit for MXATM with IMO multiplier" do
        expect(result.weight_units).to eq(16)
        expect(result.volume_units).to eq(9)
        expect(result.destination_port_code).to eq("MXATM")
        expect(result.unit_price).to eq(BigDecimal("365"))
        expect(result.billable_units).to eq(16)
        expect(result.imo_multiplier).to eq(BigDecimal("1"))
        expect(result.total).to eq(BigDecimal("5840"))
        expect(result.breakdown).to include(
          weight_units: 16,
          volume_units: 9,
          minimum_units: 12,
          billable_units: 16,
          destination_port_code: "MXATM",
          unit_price: BigDecimal("365"),
          imo_multiplier: BigDecimal("1"),
          formula: "unidades_cobrables * precio_unitario_por_puerto * multiplicador_imo",
          total: BigDecimal("5840")
        )
      end
    end

    context "when destination is MXVER and volume is greater than weight" do
      let(:destination_port) { build(:port, code: "MXVER") }
      let(:container) { build(:container, destination_port: destination_port) }
      let(:peso) { 5_000 }
      let(:volumen) { 32.5 }

      it "charges volume units at $240/unit for MXVER with IMO multiplier" do
        expect(result.weight_units).to eq(5)
        expect(result.volume_units).to eq(33)
        expect(result.destination_port_code).to eq("MXVER")
        expect(result.unit_price).to eq(BigDecimal("240"))
        expect(result.billable_units).to eq(33)
        expect(result.imo_multiplier).to eq(BigDecimal("1"))
        expect(result.total).to eq(BigDecimal("7920"))
      end
    end

    context "when both weight and volume are below minimum" do
      let(:peso) { 5_000 }
      let(:volumen) { 8.5 }

      it "applies minimum of 12 units at MXATM price with IMO multiplier" do
        expect(result.weight_units).to eq(5)
        expect(result.volume_units).to eq(9)
        expect(result.billable_units).to eq(12)
        expect(result.unit_price).to eq(BigDecimal("365"))
        expect(result.imo_multiplier).to eq(BigDecimal("1"))
        expect(result.total).to eq(BigDecimal("4380"))
      end
    end

    context "when IMO applies with clase and tipo different from 0" do
      let(:peso) { 15_500 }
      let(:volumen) { 8.1 }
      let(:bl_house_line) { build(:bl_house_line, peso: peso, volumen: volumen, container: container, clase_imo: "1", tipo_imo: "2") }

      it "doubles the total charge with IMO multiplier" do
        expect(result.billable_units).to eq(16)
        expect(result.imo_multiplier).to eq(BigDecimal("2"))
        expect(result.total).to eq(BigDecimal("11680"))
      end
    end

    context "when destination port is nil" do
      let(:container) { build(:container, destination_port: nil) }
      let(:peso) { 15_500 }
      let(:volumen) { 8.1 }

      it "defaults to MXVER price of $240 with IMO multiplier" do
        expect(result.destination_port_code).to eq("MXVER")
        expect(result.unit_price).to eq(BigDecimal("240"))
        expect(result.billable_units).to eq(16)
        expect(result.imo_multiplier).to eq(BigDecimal("1"))
        expect(result.total).to eq(BigDecimal("3840"))
      end
    end

    context "when bl_house_line has no container" do
      let(:bl_house_line) { build(:bl_house_line, peso: peso, volumen: volumen, container: nil) }
      let(:peso) { 15_500 }
      let(:volumen) { 8.1 }

      it "defaults to MXVER price of $240 with IMO multiplier" do
        expect(result.destination_port_code).to eq("MXVER")
        expect(result.unit_price).to eq(BigDecimal("240"))
        expect(result.billable_units).to eq(16)
        expect(result.imo_multiplier).to eq(BigDecimal("1"))
        expect(result.total).to eq(BigDecimal("3840"))
      end
    end

    context "when weight and volume have decimals requiring rounding up" do
      let(:peso) { 16_800 }
      let(:volumen) { 10.4 }

      it "rounds up both values and uses maximum with IMO multiplier" do
        expect(result.weight_units).to eq(17)
        expect(result.volume_units).to eq(11)
        expect(result.billable_units).to eq(17)
        expect(result.unit_price).to eq(BigDecimal("365"))
        expect(result.imo_multiplier).to eq(BigDecimal("1"))
        expect(result.total).to eq(BigDecimal("6205"))
      end
    end

    context "when all values equal minimum with IMO multiplier" do
      let(:peso) { 12_000 }
      let(:volumen) { 12 }
      let(:bl_house_line) { build(:bl_house_line, peso: peso, volumen: volumen, container: container, clase_imo: "1", tipo_imo: "1") }

      it "charges exactly 12 units with IMO multiplier" do
        expect(result.weight_units).to eq(12)
        expect(result.volume_units).to eq(12)
        expect(result.billable_units).to eq(12)
        expect(result.imo_multiplier).to eq(BigDecimal("2"))
        expect(result.total).to eq(BigDecimal("8760"))
      end
    end
  end
end
