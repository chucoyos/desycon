module BlHouseLines
  class StorageChargeCalculator
    GRACE_DAYS = 7
    MINIMUM_UNITS = 9
    VERACRUZ_DAILY_RATE_TIERS = [
      { from: 1, to: 15, rate: BigDecimal("126") },
      { from: 16, to: 45, rate: BigDecimal("196") },
      { from: 46, to: nil, rate: BigDecimal("299") }
    ].freeze
    ALTAMIRA_DAILY_RATE_TIERS = [
      { from: 1, to: 15, rate: BigDecimal("60") },
      { from: 16, to: 45, rate: BigDecimal("95") },
      { from: 46, to: nil, rate: BigDecimal("125") }
    ].freeze

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
      daily_subtotal = calculate_daily_subtotal(billable_days)
      price = unit_price.to_d

      Result.new(
        weight_units: weight_units,
        volume_units: volume_units,
        billable_units: billable_units,
        billable_days: billable_days,
        unit_price: price,
        total: (billable_units * daily_subtotal * imo_charge_multiplier).round(2)
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

    def calculate_daily_subtotal(billable_days)
      remaining = billable_days
      return BigDecimal("0") if remaining <= 0

      subtotal = BigDecimal("0")
      daily_rate_tiers.each do |tier|
        break if remaining <= 0

        days_in_tier = tier_days_for(remaining: remaining, tier: tier)
        remaining -= days_in_tier
        subtotal += days_in_tier * tier[:rate]
      end

      subtotal
    end

    def daily_rate_tiers
      return VERACRUZ_DAILY_RATE_TIERS unless bl_house_line&.container&.tipo_maniobra_importacion?

      case destination_port_code
      when "MXATM"
        ALTAMIRA_DAILY_RATE_TIERS
      else
        VERACRUZ_DAILY_RATE_TIERS
      end
    end

    def destination_port_code
      bl_house_line&.container&.destination_port&.code.to_s.upcase
    end

    def tier_days_for(remaining:, tier:)
      if tier[:to].nil?
        remaining
      else
        tier_span = tier[:to] - tier[:from] + 1
        [ remaining, tier_span ].min
      end
    end

    def imo_charge_multiplier
      return 1.to_d unless bl_house_line.respond_to?(:imo_charge_multiplier)

      bl_house_line.imo_charge_multiplier.to_d
    end
  end
end
