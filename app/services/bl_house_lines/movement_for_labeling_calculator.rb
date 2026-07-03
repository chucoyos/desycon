module BlHouseLines
  class MovementForLabelingCalculator
    MINIMUM_UNITS = 12
    UNIT_PRICES = {
      "MXATM" => 365.to_d,
      "MXVER" => 240.to_d
    }.freeze

    Result = Struct.new(
      :weight_units,
      :volume_units,
      :billable_units,
      :destination_port_code,
      :unit_price,
      :total,
      :breakdown,
      keyword_init: true
    )

    class << self
      def call(bl_house_line:)
        new(bl_house_line: bl_house_line).call
      end
    end

    def initialize(bl_house_line:)
      @bl_house_line = bl_house_line
    end

    def call
      peso_kg = bl_house_line.peso.to_d
      peso_ton = kilograms_to_tons(peso_kg)
      weight_units = ceil_units(peso_ton)
      volume_units = ceil_units(bl_house_line.volumen)
      billable_units = [ weight_units, volume_units, MINIMUM_UNITS ].max
      port_code = destination_port_code
      price = unit_price_for_port(port_code)
      total = (billable_units * price).round(2)

      Result.new(
        weight_units: weight_units,
        volume_units: volume_units,
        billable_units: billable_units,
        destination_port_code: port_code,
        unit_price: price,
        total: total,
        breakdown: {
          peso_kg_input: peso_kg,
          peso_ton_input: peso_ton,
          volumen_input: bl_house_line.volumen.to_d,
          weight_units: weight_units,
          volume_units: volume_units,
          minimum_units: MINIMUM_UNITS,
          billable_units: billable_units,
          destination_port_code: port_code,
          unit_price: price,
          formula: "unidades_cobrables * precio_unitario_por_puerto",
          total: total
        }
      )
    end

    private

    attr_reader :bl_house_line

    def ceil_units(value)
      value.to_d.ceil
    end

    def kilograms_to_tons(value)
      value.to_d / 1000
    end

    def destination_port_code
      code = bl_house_line&.container&.destination_port&.code.to_s.upcase
      code.present? ? code : "MXVER"
    end

    def unit_price_for_port(port_code)
      UNIT_PRICES[port_code] || UNIT_PRICES["MXVER"]
    end
  end
end
