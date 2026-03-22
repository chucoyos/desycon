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
        expect(result.total).to eq(BigDecimal("6048"))
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

    context "when billable days are 15" do
      let(:peso) { 12 }
      let(:volumen) { 10 }
      let(:dispatch_date) { Time.zone.local(2026, 4, 10, 10, 0, 0) }

      it "uses only first tier" do
        expect(result.billable_days).to eq(15)
        expect(result.total).to eq(BigDecimal("22680"))
      end
    end

    context "when billable days are 16" do
      let(:peso) { 12 }
      let(:volumen) { 10 }
      let(:dispatch_date) { Time.zone.local(2026, 4, 11, 10, 0, 0) }

      it "uses first tier plus one day of second tier" do
        expect(result.billable_days).to eq(16)
        expect(result.total).to eq(BigDecimal("25032"))
      end
    end

    context "when billable days are 45" do
      let(:peso) { 12 }
      let(:volumen) { 10 }
      let(:dispatch_date) { Time.zone.local(2026, 5, 10, 10, 0, 0) }

      it "uses full first and second tiers" do
        expect(result.billable_days).to eq(45)
        expect(result.total).to eq(BigDecimal("93240"))
      end
    end

    context "when billable days are 46" do
      let(:peso) { 12 }
      let(:volumen) { 10 }
      let(:dispatch_date) { Time.zone.local(2026, 5, 11, 10, 0, 0) }

      it "adds third tier from day 46 onwards" do
        expect(result.billable_days).to eq(46)
        expect(result.total).to eq(BigDecimal("96828"))
      end
    end
  end
end
