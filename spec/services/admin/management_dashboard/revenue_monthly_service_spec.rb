require "rails_helper"

RSpec.describe Admin::ManagementDashboard::RevenueMonthlyService do
  include ActiveSupport::Testing::TimeHelpers

  describe ".call" do
    around do |example|
      travel_to(Time.zone.local(2026, 4, 15, 12, 0, 0)) { example.run }
    end

    it "returns monthly emitted and collected YTD totals" do
      allow(Facturador::Config).to receive(:environment).and_return("production")

      jan_invoice = create(
        :invoice,
        kind: "ingreso",
        status: "issued",
        total: 1000,
        issued_at: Time.zone.local(2026, 1, 10),
        provider_response: { "serie" => "GMZO" }
      )
      create(
        :invoice,
        kind: "ingreso",
        status: "issued",
        total: 400,
        issued_at: Time.zone.local(2026, 2, 11),
        provider_response: { "serie" => "GVRZ" }
      )
      create(
        :invoice,
        kind: "ingreso",
        status: "issued",
        total: 150,
        issued_at: Time.zone.local(2026, 3, 8),
        provider_response: { "serie" => "ZZZ" }
      )
      apr_cancel_pending_invoice = create(
        :invoice,
        kind: "ingreso",
        status: "cancel_pending",
        total: 200,
        issued_at: Time.zone.local(2026, 4, 4),
        provider_response: { "serie" => "GATM" }
      )
      create(
        :invoice,
        kind: "ingreso",
        status: "cancelled",
        total: 500,
        issued_at: Time.zone.local(2026, 1, 18)
      )
      failed_invoice = create(
        :invoice,
        kind: "ingreso",
        status: "failed",
        total: 900,
        issued_at: Time.zone.local(2026, 1, 20),
        provider_response: { "serie" => "GMZO" }
      )

      create(:invoice_payment, invoice: jan_invoice, amount: 300, paid_at: Time.zone.local(2026, 2, 5))
      create(:invoice_payment, invoice: jan_invoice, amount: 200, paid_at: Time.zone.local(2026, 4, 2))
      create(:invoice_payment, invoice: apr_cancel_pending_invoice, amount: 50, paid_at: Time.zone.local(2026, 4, 10))
      create(:invoice_payment, invoice: failed_invoice, amount: 400, paid_at: Time.zone.local(2026, 3, 10))

      result = described_class.call(year: 2026)

      expect(result[:month_numbers]).to eq((1..12).to_a)
      expect(result[:month_labels]).to eq(%w[Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic])
      expect(result[:emitted]).to eq([ 1000.to_d, 400.to_d, 150.to_d, 200.to_d ] + Array.new(8, 0.to_d))
      expect(result[:collected]).to eq([ 0.to_d, 300.to_d, 0.to_d, 250.to_d ] + Array.new(8, 0.to_d))
      expect(result[:outstanding]).to eq([ 500.to_d, 400.to_d, 150.to_d, 150.to_d ] + Array.new(8, 0.to_d))
      expect(result.dig(:totals, :emitted)).to eq(1750.to_d)
      expect(result.dig(:totals, :collected)).to eq(550.to_d)
      expect(result.dig(:totals, :outstanding)).to eq(1200.to_d)

      emitted_by_port = result[:emitted_by_destination_port]
      expect(emitted_by_port.fetch("Manzanillo")).to eq([ 1000.to_d, 0.to_d, 0.to_d, 0.to_d ] + Array.new(8, 0.to_d))
      expect(emitted_by_port.fetch("Veracruz")).to eq([ 0.to_d, 400.to_d, 0.to_d, 0.to_d ] + Array.new(8, 0.to_d))
      expect(emitted_by_port.fetch("Lazaro Cardenas")).to eq(Array.new(12, 0.to_d))
      expect(emitted_by_port.fetch("Altamira")).to eq([ 0.to_d, 0.to_d, 0.to_d, 200.to_d ] + Array.new(8, 0.to_d))
      expect(emitted_by_port.fetch("Sin clasificar")).to eq([ 0.to_d, 0.to_d, 150.to_d, 0.to_d ] + Array.new(8, 0.to_d))
    end

    it "groups emitted totals by app timezone month near UTC boundary" do
      allow(Facturador::Config).to receive(:environment).and_return("production")

      tz = Time.zone
      create(
        :invoice,
        kind: "ingreso",
        status: "issued",
        total: 250,
        # Local time is still April, even if UTC timestamp crosses into May.
        issued_at: tz.local(2026, 4, 30, 18, 0, 0)
      )

      result = described_class.call(year: 2026)

      expect(result[:emitted][3]).to eq(250.to_d) # Abril
      expect(result[:emitted][4]).to eq(0.to_d)   # Mayo
    end
  end
end
