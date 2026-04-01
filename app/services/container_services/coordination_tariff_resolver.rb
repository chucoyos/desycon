module ContainerServices
  class CoordinationTariffResolver
    EWE_RFC = "EWE1709045U0".freeze
    NIPPON_RFC = "NEM901109BC2".freeze

    MANZANILLO_RULES = [
      { rfc: "PTM0701119T6", terminal: :all, warehouse: :all, amount: BigDecimal("3775") },
      { rfc: "NEM901109BC2", terminal: [ "CONTECON" ], warehouse: [ "HAZESA" ], amount: nil },
      { rfc: "NEM901109BC2", terminal: [ "CONTECON" ], warehouse: %w[SSA OCUPA FRIMAN], amount: BigDecimal("3500") },
      { rfc: "NEM901109BC2", terminal: [ "SSA" ], warehouse: %w[SSA FRIMAN OCUPA], amount: nil },
      { rfc: "NEM901109BC2", terminal: [ "OCUPA" ], warehouse: %w[SSA FRIMAN OCUPA], amount: nil },
      { rfc: "NEM901109BC2", terminal: [ "TIMSA" ], warehouse: %w[SSA OCUPA FRIMAN], amount: BigDecimal("3500") },
      { rfc: "MFO250717B72", terminal: [ "SSA" ], warehouse: %w[SSA FRIMAN OCUPA], amount: nil },
      { rfc: "MFO250717B72", terminal: [ "OCUPA" ], warehouse: %w[SSA FRIMAN OCUPA], amount: nil },
      { rfc: "MFO250717B72", terminal: [ "TIMSA" ], warehouse: %w[SSA FRIMAN OCUPA], amount: BigDecimal("5500") },
      { rfc: "MFO250717B72", terminal: [ "CONTECON" ], warehouse: %w[HAZESA SSA FRIMAN OCUPA], amount: BigDecimal("6500") },
      { rfc: "SBM0601253SA", terminal: [ "SSA" ], warehouse: %w[SSA OCUPA FRIMAN], amount: nil },
      { rfc: "SBM0601253SA", terminal: [ "TIMSA" ], warehouse: %w[SSA OCUPA FRIMAN], amount: BigDecimal("5000") },
      { rfc: "SBM0601253SA", terminal: [ "OCUPA" ], warehouse: %w[SSA OCUPA FRIMAN], amount: nil },
      { rfc: "SBM0601253SA", terminal: [ "CONTECON" ], warehouse: %w[SSA OCUPA FRIMAN], amount: BigDecimal("3500") },
      { rfc: "SBM0601253SA", terminal: [ "CONTECON" ], warehouse: [ "HAZESA" ], amount: nil },
      { rfc: "VFS150518BT0", terminal: :all, warehouse: :all, amount: BigDecimal("3000") }
    ].freeze

    VERACRUZ_RATES = {
      "PTM0701119T6" => BigDecimal("3800"),
      "SBM0601253SA" => BigDecimal("3800"),
      "VFS150518BT0" => BigDecimal("3800")
    }.freeze

    ALTAMIRA_RATES = {
      "PTM0701119T6" => BigDecimal("3800")
    }.freeze

    class << self
      def call(container:)
        new(container: container).call
      end
    end

    def initialize(container:)
      @container = container
    end

    def call
      return nil if consolidator_rfc.blank?

      case destination_port_code
      when "MXZLO"
        resolve_manzanillo_rate
      when "MXVER"
        VERACRUZ_RATES[effective_consolidator_rfc]
      when "MXATM"
        ALTAMIRA_RATES[effective_consolidator_rfc]
      else
        nil
      end
    end

    private

    attr_reader :container

    def resolve_manzanillo_rate
      terminal = normalize_location(container.recinto)
      warehouse = normalize_location(container.almacen)

      rule = MANZANILLO_RULES.find do |entry|
        entry[:rfc] == effective_consolidator_rfc &&
          matches_dimension?(terminal, entry[:terminal]) &&
          matches_dimension?(warehouse, entry[:warehouse])
      end

      rule&.fetch(:amount, nil)
    end

    def matches_dimension?(value, rule_values)
      return true if rule_values == :all

      Array(rule_values).any? { |rule_value| value == normalize_location(rule_value) }
    end

    def consolidator_rfc
      @consolidator_rfc ||= container&.consolidator_entity&.fiscal_profile&.rfc.to_s.upcase.strip.presence
    end

    def effective_consolidator_rfc
      if non_production_alias_enabled? && consolidator_rfc == EWE_RFC
        NIPPON_RFC
      else
        consolidator_rfc
      end
    end

    def destination_port_code
      container&.destination_port&.code.to_s.upcase
    end

    def non_production_alias_enabled?
      Rails.env.development? || Rails.env.staging?
    end

    def normalize_location(value)
      normalized = ActiveSupport::Inflector.transliterate(value.to_s).upcase.strip
      normalized = "SSA" if normalized == "SSAM"
      normalized
    end
  end
end
