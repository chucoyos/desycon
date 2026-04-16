require "rails_helper"

RSpec.describe Admin::ManagementDashboard::OperationsMonthlyService do
  include ActiveSupport::Testing::TimeHelpers

  describe ".call" do
    around do |example|
      travel_to(Time.zone.local(2026, 4, 15, 12, 0, 0)) { example.run }
    end

    it "returns YTD operational metrics and destination port importation breakdown" do
      manzanillo = create(:port, :manzanillo)
      veracruz = create(:port, :veracruz)

      manzanillo_voyage = create(:voyage, destination_port: manzanillo)
      veracruz_voyage = create(:voyage, destination_port: veracruz)

      import_container = create(
        :container,
        tipo_maniobra: "importacion",
        voyage: manzanillo_voyage,
        recinto: "CONTECON",
        almacen: "SSA",
        created_at: Time.zone.local(2026, 1, 8)
      )
      export_container = create(
        :container,
        tipo_maniobra: "exportacion",
        voyage: veracruz_voyage,
        created_at: Time.zone.local(2026, 1, 12)
      )

      ContainerStatusHistory.create!(
        container: import_container,
        status: "descargado",
        fecha_actualizacion: Time.zone.local(2026, 2, 1)
      )
      ContainerStatusHistory.create!(
        container: import_container,
        status: "desconsolidado",
        fecha_actualizacion: Time.zone.local(2026, 2, 5)
      )

      bl = create(:bl_house_line, container: import_container, created_at: Time.zone.local(2026, 3, 2))
      create(:bl_house_line_status_history, bl_house_line: bl, status: "revalidado", changed_at: Time.zone.local(2026, 4, 1))
      create(:bl_house_line_status_history, bl_house_line: bl, status: "despachado", changed_at: Time.zone.local(2026, 4, 3))

      result = described_class.call(year: 2026)

      expect(result[:month_numbers]).to eq([ 1, 2, 3, 4 ])
      expect(result.dig(:containers, :created)).to eq([ 2, 0, 0, 0 ])
      expect(result.dig(:containers, :closed)).to eq([ 0, 1, 0, 0 ])
      expect(result.dig(:containers, :unconsolidated)).to eq([ 0, 1, 0, 0 ])

      expect(result.dig(:bl_house_lines, :created)).to eq([ 0, 0, 1, 0 ])
      expect(result.dig(:bl_house_lines, :revalidated)).to eq([ 0, 0, 0, 1 ])
      expect(result.dig(:bl_house_lines, :dispatched)).to eq([ 0, 0, 0, 1 ])

      expect(result.dig(:destination_port_importation, "Manzanillo")).to eq([ 1, 0, 0, 0 ])
      expect(result.dig(:destination_port_importation, "Veracruz")).to eq([ 0, 0, 0, 0 ])
      expect(result.dig(:destination_port_importation, "Lazaro Cardenas")).to eq([ 0, 0, 0, 0 ])
      expect(result.dig(:destination_port_importation, "Altamira")).to eq([ 0, 0, 0, 0 ])

      expect(export_container.tipo_maniobra).to eq("exportacion")
    end
  end
end
