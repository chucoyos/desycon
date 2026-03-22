module BlHouseLines
  class StorageChargeCalculator
    GRACE_DAYS = 7
    MINIMUM_UNITS = 9

    Result = Struct.new(
      :weight_units,
      :volume_units,
      :billable_units,
      :billable_days,
      :unit_price,
      :total,
      keyword_init: true
    )

    class << self
      def call(bl_house_line:, desconsolidation_date:, dispatch_date:, unit_price:)
        new(
          bl_house_line: bl_house_line,
          desconsolidation_date: desconsolidation_date,
          dispatch_date: dispatch_date,
          unit_price: unit_price
        ).call
      end
    end

    def initialize(bl_house_line:, desconsolidation_date:, dispatch_date:, unit_price:)
      @bl_house_line = bl_house_line
      @desconsolidation_date = desconsolidation_date
      @dispatch_date = dispatch_date
      @unit_price = unit_price
    end

    def call
      return nil if desconsolidation_date.blank? || dispatch_date.blank?

      weight_units = ceil_units(bl_house_line.peso)
      volume_units = ceil_units(bl_house_line.volumen)
      billable_units = [ weight_units, volume_units, MINIMUM_UNITS ].max
      billable_days = calculate_billable_days
      price = unit_price.to_d

      Result.new(
        weight_units: weight_units,
        volume_units: volume_units,
        billable_units: billable_units,
        billable_days: billable_days,
        unit_price: price,
        total: (billable_units * billable_days * price).round(2)
      )
    end

    private

    attr_reader :bl_house_line, :desconsolidation_date, :dispatch_date, :unit_price

    def ceil_units(value)
      value.to_d.ceil
    end

    def calculate_billable_days
      dispatch = dispatch_date.to_date
      grace_end = desconsolidation_date.to_date + (GRACE_DAYS - 1)
      days = (dispatch - grace_end).to_i

      [ days, 0 ].max
    end
  end
end
