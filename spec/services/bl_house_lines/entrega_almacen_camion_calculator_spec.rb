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
      let(:peso) { 13_200 }
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
      let(:peso) { 6_400 }
      let(:volumen) { 10.4 }

      it "charges using rounded volume" do
        expect(result.billable_units).to eq(12)
        expect(result.total).to eq(BigDecimal("1512"))
      end
    end

    context "when both are below minimum units" do
      let(:peso) { 3_000 }
      let(:volumen) { 6 }

      it "applies minimum of 12 units" do
        expect(result.billable_units).to eq(12)
        expect(result.total).to eq(BigDecimal("1512"))
      end
    end

    context "when imo applies with clase and tipo different from 0" do
      let(:peso) { 13_200 }
      let(:volumen) { 8.1 }
      let(:bl_house_line) { build(:bl_house_line, peso: peso, volumen: volumen, clase_imo: "1", tipo_imo: "2") }

      it "doubles the total charge" do
        expect(result.billable_units).to eq(14)
        expect(result.total).to eq(BigDecimal("3528"))
      end
    end

    context "when only one imo field is different from 0" do
      let(:peso) { 13_200 }
      let(:volumen) { 8.1 }
      let(:bl_house_line) { build(:bl_house_line, peso: peso, volumen: volumen, clase_imo: "1", tipo_imo: "0") }

      it "does not double the total charge" do
        expect(result.total).to eq(BigDecimal("1764"))
      end
    end
  end

  describe "BL-PRV-LZC" do
    let(:unit_price) { BigDecimal("679") }

    def calculate(peso:, volumen:, code: "BL-PRV-LZC")
      described_class.call(bl_house_line: build(:bl_house_line, peso: peso, volumen: volumen), unit_price: unit_price, service_code: code)
    end

    it "applies a minimum of 10 units" do
      result = calculate(peso: 3_000, volumen: 4.2)
      expect(result.billable_units).to eq(10)
      expect(result.breakdown[:minimum_units]).to eq(10)
      expect(result.total).to eq(BigDecimal("6790"))
    end

    it "charges the greater of tons or cubic meters" do
      expect(calculate(peso: 13_200, volumen: 8.1).billable_units).to eq(14)
      expect(calculate(peso: 6_400, volumen: 15.2).billable_units).to eq(16)
    end

    it "keeps the minimum of 12 for other codes and case-insensitive matching" do
      expect(calculate(peso: 3_000, volumen: 4.2, code: "BL-PREVIO").billable_units).to eq(12)
      expect(calculate(peso: 3_000, volumen: 4.2, code: "bl-prv-lzc").billable_units).to eq(10)
    end
  end

  describe "BL-REAC-LZC" do
    def calculate(peso:, volumen:)
      described_class.call(bl_house_line: build(:bl_house_line, peso: peso, volumen: volumen), unit_price: BigDecimal("600"), service_code: "BL-REAC-LZC")
    end

    it "applies a minimum of 7 units" do
      result = calculate(peso: 3_000, volumen: 4.2)
      expect(result.billable_units).to eq(7)
      expect(result.total).to eq(BigDecimal("4200"))
    end

    it "charges the greater of tons or cubic meters above the minimum" do
      expect(calculate(peso: 13_200, volumen: 8.1).billable_units).to eq(14)
      expect(calculate(peso: 3_000, volumen: 9.5).total).to eq(BigDecimal("6000"))
    end
  end

  describe "BL-POSC-LZC" do
    def calculate(peso:, volumen:)
      described_class.call(bl_house_line: build(:bl_house_line, peso: peso, volumen: volumen), unit_price: BigDecimal("679"), service_code: "BL-POSC-LZC")
    end

    it "applies a minimum of 10 units" do
      result = calculate(peso: 3_000, volumen: 4.2)
      expect(result.billable_units).to eq(10)
      expect(result.total).to eq(BigDecimal("6790"))
    end

    it "charges the greater of tons or cubic meters above the minimum" do
      expect(calculate(peso: 13_200, volumen: 8.1).billable_units).to eq(14)
      expect(calculate(peso: 3_000, volumen: 15.2).billable_units).to eq(16)
    end
  end

  describe "BL-MF-LZC" do
    def calculate(peso:, volumen:)
      described_class.call(bl_house_line: build(:bl_house_line, peso: peso, volumen: volumen), unit_price: BigDecimal("626"), service_code: "BL-MF-LZC")
    end

    it "applies a minimum of 10 units" do
      result = calculate(peso: 3_000, volumen: 4.2)
      expect(result.billable_units).to eq(10)
      expect(result.total).to eq(BigDecimal("6260"))
    end

    it "charges the greater of tons or cubic meters above the minimum" do
      expect(calculate(peso: 13_200, volumen: 8.1).billable_units).to eq(14)
    end
  end
end
