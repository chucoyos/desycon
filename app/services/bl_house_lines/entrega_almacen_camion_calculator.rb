module BlHouseLines
  class EntregaAlmacenCamionCalculator
    MINIMUM_UNITS = 12

    Result = Struct.new(
      :weight_units,
      :volume_units,
      :billable_units,
      :unit_price,
      :total,
      keyword_init: true
    )

    class << self
      def call(bl_house_line:, unit_price:)
        new(bl_house_line: bl_house_line, unit_price: unit_price).call
      end
    end

    def initialize(bl_house_line:, unit_price:)
      @bl_house_line = bl_house_line
      @unit_price = unit_price
    end

    def call
      weight_units = ceil_units(bl_house_line.peso)
      volume_units = ceil_units(bl_house_line.volumen)
      billable_units = [ weight_units, volume_units, MINIMUM_UNITS ].max
      price = unit_price.to_d

      Result.new(
        weight_units: weight_units,
        volume_units: volume_units,
        billable_units: billable_units,
        unit_price: price,
        total: (billable_units * price * imo_charge_multiplier).round(2)
      )
    end

    private

    attr_reader :bl_house_line, :unit_price

    def ceil_units(value)
      value.to_d.ceil
    end

    def imo_charge_multiplier
      return 1.to_d unless bl_house_line.respond_to?(:imo_charge_multiplier)

      bl_house_line.imo_charge_multiplier.to_d
    end
  end
end
