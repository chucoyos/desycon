require "rails_helper"

RSpec.describe BlHouseLines::LabelTaggingChargeCalculator do
  describe ".call" do
    let(:unit_price) { BigDecimal("1.68") }

    context "when quantity is below minimum" do
      subject(:result) do
        described_class.call(
          service_code: "BL-ETIADH",
          quantity: 1000,
          unit_price: unit_price
        )
      end

      it "charges the minimum billable quantity" do
        expect(result.input_quantity).to eq(1000)
        expect(result.minimum_billable_quantity).to eq(1193)
        expect(result.billable_quantity).to eq(1193)
        expect(result.total).to eq(BigDecimal("2004.24"))
      end
    end

    context "when quantity equals minimum" do
      subject(:result) do
        described_class.call(
          service_code: "BL-ETICOS",
          quantity: 230,
          unit_price: BigDecimal("4.96")
        )
      end

      it "charges using the provided quantity" do
        expect(result.billable_quantity).to eq(230)
        expect(result.total).to eq(BigDecimal("1140.8"))
      end
    end

    context "when quantity is above minimum" do
      subject(:result) do
        described_class.call(
          service_code: "BL-ETICOS",
          quantity: 500,
          unit_price: BigDecimal("4.96")
        )
      end

      it "charges using the provided quantity" do
        expect(result.billable_quantity).to eq(500)
        expect(result.total).to eq(BigDecimal("2480.0"))
      end
    end

    context "when service code is unsupported" do
      subject(:result) do
        described_class.call(
          service_code: "BL-OTRO",
          quantity: 100,
          unit_price: unit_price
        )
      end

      it "returns nil" do
        expect(result).to be_nil
      end
    end
  end
end
