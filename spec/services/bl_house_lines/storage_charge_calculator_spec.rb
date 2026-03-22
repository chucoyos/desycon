require "rails_helper"

RSpec.describe BlHouseLines::StorageChargeCalculator do
  describe ".call" do
    let(:bl_house_line) { build(:bl_house_line, peso: peso, volumen: volumen) }
    let(:desconsolidation_date) { Date.new(2026, 3, 20) }
    let(:dispatch_date) { Time.zone.local(2026, 3, 30, 10, 0, 0) }
    let(:unit_price) { BigDecimal("170.91") }

    subject(:result) do
      described_class.call(
        bl_house_line: bl_house_line,
        desconsolidation_date: desconsolidation_date,
        dispatch_date: dispatch_date,
        unit_price: unit_price
      )
    end

    context "when weight is greater than volume" do
      let(:peso) { 12 }
      let(:volumen) { 10 }

      it "charges by weight units" do
        expect(result.billable_units).to eq(12)
        expect(result.billable_days).to eq(4)
        expect(result.total).to eq(BigDecimal("8203.68"))
      end
    end

    context "when volume is greater than weight" do
      let(:peso) { 6 }
      let(:volumen) { 10.2 }

      it "charges by volume units rounded up" do
        expect(result.billable_units).to eq(11)
      end
    end

    context "when both units are below minimum" do
      let(:peso) { 3 }
      let(:volumen) { 6 }

      it "charges the minimum 9 units" do
        expect(result.billable_units).to eq(9)
      end
    end

    context "when values include decimals" do
      let(:peso) { 1.1 }
      let(:volumen) { 2.2 }

      it "rounds up to the next whole unit" do
        expect(result.weight_units).to eq(2)
        expect(result.volume_units).to eq(3)
      end
    end

    context "when dispatch date is within grace period" do
      let(:peso) { 12 }
      let(:volumen) { 10 }
      let(:dispatch_date) { Time.zone.local(2026, 3, 26, 10, 0, 0) }

      it "returns zero billable days" do
        expect(result.billable_days).to eq(0)
        expect(result.total).to eq(BigDecimal("0.0"))
      end
    end

    context "when required dates are missing" do
      let(:peso) { 12 }
      let(:volumen) { 10 }
      let(:dispatch_date) { nil }

      it "returns nil" do
        expect(result).to be_nil
      end
    end
  end
end
