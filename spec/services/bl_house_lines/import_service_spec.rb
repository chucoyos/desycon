# frozen_string_literal: true

require "rails_helper"
require "rack/test"

RSpec.describe BlHouseLines::ImportService do
  include Rack::Test::Methods

  let!(:packaging) { create(:packaging, nombre: "Caja") }
  let(:container) { create(:container) }
  let(:user) { create(:user) }

  def uploaded_csv(content)
    file = Tempfile.new([ "bl_lines", ".csv" ])
    file.write(content)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "text/csv")
  ensure
    file.close
  end

  context "when any row is invalid" do
    let(:csv_content) do
      <<~CSV
        blhouse,cantidad,embalaje,contiene,marcas,peso,volumen
        BL1,1,Caja,Contenido,Marca,10,1.2
        BL2,1,Caja,,Marca,10,1.2
      CSV
    end

    it "does not import any rows and reports errors" do
      service = described_class.new(container: container, file: uploaded_csv(csv_content), current_user: user)

      result = service.call

      expect(result.created_count).to eq(0)
      expect(result.errors).not_to be_empty
      expect(container.bl_house_lines.count).to eq(0)
    end
  end

  context "when all rows are valid" do
    let(:csv_content) do
      <<~CSV
        blhouse,cantidad,embalaje,contiene,marcas,peso,volumen
        BL1,1,Caja,Contenido,Marca,10,1.2
        BL2,2,Caja,Otro contenido,Otra marca,12,1.3
      CSV
    end

    it "imports every row" do
      service = described_class.new(container: container, file: uploaded_csv(csv_content), current_user: user)

      result = service.call

      expect(result.created_count).to eq(2)
      expect(result.errors).to be_empty
      expect(container.bl_house_lines.pluck(:blhouse)).to match_array(%w[BL1 BL2])
    end
  end
end
