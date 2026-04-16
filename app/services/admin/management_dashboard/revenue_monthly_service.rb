module Admin
  module ManagementDashboard
    class RevenueMonthlyService
      MONTH_LABELS = %w[Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic].freeze
      DESTINATION_PORT_LABELS_BY_CODE = {
        "MXZLO" => "Manzanillo",
        "MXLZC" => "Lazaro Cardenas",
        "MXVER" => "Veracruz",
        "MXATM" => "Altamira"
      }.freeze
      UNCLASSIFIED_PORT_LABEL = "Sin clasificar".freeze

      class << self
        def call(year:)
          new(year: year).call
        end
      end

      def initialize(year:)
        @year = year.to_i
      end

      def call
        {
          year: year,
          month_numbers: month_numbers,
          month_labels: month_labels,
          emitted: emitted_series,
          collected: collected_series,
          emitted_by_destination_port: emitted_by_destination_port_series,
          totals: {
            emitted: emitted_series.sum,
            collected: collected_series.sum
          }
        }
      end

      private

      attr_reader :year

      def month_numbers
        @month_numbers ||= (1..max_month).to_a
      end

      def month_labels
        month_numbers.map { |month| MONTH_LABELS[month - 1] }
      end

      def max_month
        12
      end

      def range_start
        Time.zone.local(year, 1, 1).beginning_of_day
      end

      def range_end
        Date.new(year, max_month, 1).end_of_month.end_of_day
      end

      def emitted_by_month
        rows = Invoice
          .where(kind: "ingreso")
          .where(issued_at: range_start..range_end)
          .where(status: %w[issued cancel_pending failed])
          .group("EXTRACT(MONTH FROM invoices.issued_at)")
          .sum(:total)

        normalize_month_hash(rows)
      end

      def collected_by_month
        rows = InvoicePayment
          .joins(:invoice)
          .where(paid_at: range_start..range_end)
          .where(invoices: { kind: "ingreso" })
          .where.not(invoices: { status: "cancelled" })
          .group("EXTRACT(MONTH FROM invoice_payments.paid_at)")
          .sum("invoice_payments.amount")

        normalize_month_hash(rows)
      end

      def emitted_series
        month_numbers.map { |month| emitted_by_month.fetch(month, 0.to_d) }
      end

      def collected_series
        month_numbers.map { |month| collected_by_month.fetch(month, 0.to_d) }
      end

      def emitted_by_destination_port_series
        labels = DESTINATION_PORT_LABELS_BY_CODE.values + [ UNCLASSIFIED_PORT_LABEL ]

        labels.each_with_object({}) do |port_label, acc|
          acc[port_label] = month_numbers.map { |month| emitted_by_month_and_destination_port.dig(port_label, month) || 0.to_d }
        end
      end

      def emitted_by_month_and_destination_port
        @emitted_by_month_and_destination_port ||= begin
          rows = Invoice
            .where(kind: "ingreso")
            .where(issued_at: range_start..range_end)
            .where(status: %w[issued cancel_pending failed])
            .group("EXTRACT(MONTH FROM invoices.issued_at)", emitted_serie_sql)
            .sum(:total)

          rows.each_with_object({}) do |((month, serie), total), acc|
            normalized_serie = serie.to_s.strip.upcase
            port_label = destination_port_label_by_serie.fetch(normalized_serie, UNCLASSIFIED_PORT_LABEL)
            acc[port_label] ||= {}
            acc[port_label][month.to_i] = total.to_d
          end
        end
      end

      def destination_port_label_by_serie
        @destination_port_label_by_serie ||= begin
          destination_series_by_port_code.each_with_object({}) do |(port_code, serie), acc|
            label = DESTINATION_PORT_LABELS_BY_CODE[port_code]
            next if label.blank?

            acc[serie.to_s.strip.upcase] = label
          end
        end
      end

      def destination_series_by_port_code
        environment = Facturador::Config.environment.to_s.strip.downcase

        if environment == "sandbox"
          Facturador::PayloadBuilder::IMPORT_DESTINATION_SERIES_BY_PORT_CODE_SANDBOX
        else
          Facturador::PayloadBuilder::IMPORT_DESTINATION_SERIES_BY_PORT_CODE_PRODUCTION
        end
      end

      def emitted_serie_sql
        @emitted_serie_sql ||= <<~SQL.squish
          COALESCE(
            NULLIF(invoices.provider_response->>'serie', ''),
            NULLIF(invoices.payload_snapshot->>'serie', ''),
            NULLIF(invoices.payload_snapshot->>'serie_override', ''),
            ''
          )
        SQL
      end

      def normalize_month_hash(rows)
        rows.each_with_object({}) do |(month, value), acc|
          acc[month.to_i] = value.to_d
        end
      end
    end
  end
end
