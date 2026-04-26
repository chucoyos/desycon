module BlHouseLines
  class LabelTaggingChargeCalculator
    MINIMUM_BILLABLE_QUANTITIES = {
      "BL-ETIADH" => 1193,
      "BL-ETICOS" => 230
    }.freeze

    Result = Struct.new(
      :input_quantity,
      :minimum_billable_quantity,
      :billable_quantity,
      :unit_price,
      :total,
      :breakdown,
      keyword_init: true
    )

    class << self
      def call(service_code:, quantity:, unit_price:)
        new(service_code: service_code, quantity: quantity, unit_price: unit_price).call
      end
    end

    def initialize(service_code:, quantity:, unit_price:)
      @service_code = service_code.to_s.upcase
      @quantity = quantity
      @unit_price = unit_price
    end

    def call
      minimum_billable_quantity = MINIMUM_BILLABLE_QUANTITIES[service_code]
      return nil if minimum_billable_quantity.blank?

      input_quantity = quantity.to_i
      billable_quantity = [ input_quantity, minimum_billable_quantity ].max
      price = unit_price.to_d
      total = (billable_quantity * price).round(2)

      Result.new(
        input_quantity: input_quantity,
        minimum_billable_quantity: minimum_billable_quantity,
        billable_quantity: billable_quantity,
        unit_price: price,
        total: total,
        breakdown: {
          input_quantity: input_quantity,
          minimum_billable_quantity: minimum_billable_quantity,
          billable_quantity: billable_quantity,
          unit_price: price,
          formula: "cantidad_cobrable * precio_unitario",
          total: total
        }
      )
    end

    private

    attr_reader :service_code, :quantity, :unit_price
  end
end
