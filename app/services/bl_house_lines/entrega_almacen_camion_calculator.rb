module BlHouseLines
  class EntregaAlmacenCamionCalculator
    MINIMUM_UNITS = 12
    LAZARO_MINIMUM_UNITS = { "BL-PRV-LZC" => 10, "BL-REAC-LZC" => 7, "BL-POSC-LZC" => 10, "BL-MF-LZC" => 10, "BL-ENT-LZC" => 10 }.freeze

    Result = Struct.new(
      :weight_units,
      :volume_units,
      :billable_units,
      :unit_price,
      :total,
      :breakdown,
      keyword_init: true
    )

    class << self
      def call(bl_house_line:, unit_price:, service_code: nil)
        new(bl_house_line: bl_house_line, unit_price: unit_price, service_code: service_code).call
      end
    end

    def initialize(bl_house_line:, unit_price:, service_code: nil)
      @bl_house_line = bl_house_line
      @unit_price = unit_price
      @service_code = service_code.to_s.upcase
    end

    def call
      peso_kg = bl_house_line.peso.to_d
      peso_ton = kilograms_to_tons(peso_kg)
      weight_units = ceil_units(peso_ton)
      volume_units = ceil_units(bl_house_line.volumen)
      billable_units = [ weight_units, volume_units, minimum_units ].max
      price = unit_price.to_d
      multiplier = imo_charge_multiplier
      total = (billable_units * price * multiplier).round(2)

      Result.new(
        weight_units: weight_units,
        volume_units: volume_units,
        billable_units: billable_units,
        unit_price: price,
        total: total,
        # TEMPORAL DEBUG: desglose para visualizar variables y formula en pruebas.
        # Remover cuando se cierre la validacion operativa de calculos.
        breakdown: {
          peso_kg_input: peso_kg,
          peso_ton_input: peso_ton,
          volumen_input: bl_house_line.volumen.to_d,
          weight_units: weight_units,
          volume_units: volume_units,
          minimum_units: minimum_units,
          billable_units: billable_units,
          unit_price: price,
          imo_multiplier: multiplier,
          formula: "unidades_cobrables * precio_unitario * multiplicador_imo",
          total: total
        }
      )
    end

    private

    attr_reader :bl_house_line, :unit_price, :service_code

    def minimum_units
      LAZARO_MINIMUM_UNITS.fetch(service_code, MINIMUM_UNITS)
    end

    def ceil_units(value)
      value.to_d.ceil
    end

    def kilograms_to_tons(value)
      value.to_d / 1000
    end

    def imo_charge_multiplier
      return 1.to_d unless bl_house_line.respond_to?(:imo_charge_multiplier)

      bl_house_line.imo_charge_multiplier.to_d
    end
  end
end
