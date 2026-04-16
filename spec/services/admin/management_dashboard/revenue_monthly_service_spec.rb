require "rails_helper"

RSpec.describe Admin::ManagementDashboard::RevenueMonthlyService do
  include ActiveSupport::Testing::TimeHelpers

  describe ".call" do
    around do |example|
      travel_to(Time.zone.local(2026, 4, 15, 12, 0, 0)) { example.run }
    end

    it "returns monthly emitted and collected YTD totals" do
      jan_invoice = create(
        :invoice,
        kind: "ingreso",
        status: "issued",
        total: 1000,
        issued_at: Time.zone.local(2026, 1, 10)
      )
      create(
        :invoice,
        kind: "ingreso",
        status: "cancelled",
        total: 500,
        issued_at: Time.zone.local(2026, 1, 18)
      )

      create(:invoice_payment, invoice: jan_invoice, amount: 300, paid_at: Time.zone.local(2026, 2, 5))
      create(:invoice_payment, invoice: jan_invoice, amount: 200, paid_at: Time.zone.local(2026, 4, 2))

      result = described_class.call(year: 2026)

      expect(result[:month_numbers]).to eq((1..12).to_a)
      expect(result[:month_labels]).to eq(%w[Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic])
      expect(result[:emitted]).to eq([ 1000.to_d, 0.to_d, 0.to_d, 0.to_d ] + Array.new(8, 0.to_d))
      expect(result[:collected]).to eq([ 0.to_d, 300.to_d, 0.to_d, 200.to_d ] + Array.new(8, 0.to_d))
      expect(result.dig(:totals, :emitted)).to eq(1000.to_d)
      expect(result.dig(:totals, :collected)).to eq(500.to_d)
    end
  end
end
