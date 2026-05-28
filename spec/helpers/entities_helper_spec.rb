require 'rails_helper'

# Specs in this file have access to a helper object that includes
# the EntitiesHelper. For example:
#
# describe EntitiesHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end
RSpec.describe EntitiesHelper, type: :helper do
  it "exposes the helper" do
    expect(helper).to be_present
  end

  describe "#entity_event_change_rows" do
    it "expands address updates into field-level rows" do
      values = {
        "before" => [
          {
            "id" => 10,
            "tipo" => "matriz",
            "calle" => "Av. Uno",
            "numero_exterior" => "10",
            "email" => "old@example.com"
          }
        ],
        "after" => [
          {
            "id" => 10,
            "tipo" => "matriz",
            "calle" => "Av. Dos",
            "numero_exterior" => "20",
            "email" => "new@example.com"
          }
        ]
      }

      rows = helper.entity_event_change_rows("addresses", values)

      labels = rows.map { |row| row[:label] }
      expect(labels).to include("Domicilio - Calle")
      expect(labels).to include("Domicilio - Numero exterior")
      expect(labels).to include("Domicilio - Correo")
    end

    it "creates agregado row when a new address is added" do
      values = {
        "before" => [],
        "after" => [
          {
            "id" => 20,
            "tipo" => "sucursal",
            "calle" => "Nueva",
            "codigo_postal" => "01010",
            "pais" => "MX"
          }
        ]
      }

      rows = helper.entity_event_change_rows("addresses", values)

      expect(rows.first[:label]).to eq("Domicilio (agregado)")
      expect(rows.first[:before]).to be_nil
      expect(rows.first[:after]).to include("sucursal")
    end
  end

  describe "#entity_event_value_for_display" do
    it "formats blank values" do
      expect(helper.entity_event_value_for_display(nil)).to eq("(vacio)")
      expect(helper.entity_event_value_for_display("")).to eq("(vacio)")
    end

    it "formats booleans" do
      expect(helper.entity_event_value_for_display(true)).to eq("Si")
      expect(helper.entity_event_value_for_display(false)).to eq("No")
    end
  end
end
