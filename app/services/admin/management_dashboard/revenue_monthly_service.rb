module Admin
  module ManagementDashboard
    class RevenueMonthlyService
      MONTH_LABELS = %w[Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic].freeze

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
        today = Time.zone.today
        year == today.year ? today.month : 12
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

      def normalize_month_hash(rows)
        rows.each_with_object({}) do |(month, value), acc|
          acc[month.to_i] = value.to_d
        end
      end
    end
  end
end
