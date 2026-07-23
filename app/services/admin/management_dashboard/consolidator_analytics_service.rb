module Admin
  module ManagementDashboard
    class ConsolidatorAnalyticsService
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
        consolidators_data = consolidators_metrics

        {
          year: year,
          month_labels: month_labels,
          consolidators: consolidators_data,
          totals: {
            total_revenue: consolidators_data.sum { |c| c[:revenue] },
            total_containers: consolidators_data.sum { |c| c[:containers_count] },
            total_bl_total: consolidators_data.sum { |c| c[:bl_total] },
            total_bl_dispatched: consolidators_data.sum { |c| c[:bl_dispatched] },
            total_bl_pending: consolidators_data.sum { |c| c[:bl_pending] }
          }
        }
      end

      private

      attr_reader :year

      def month_labels
        @month_labels ||= MONTH_LABELS
      end

      def month_numbers
        @month_numbers ||= (1..12).to_a
      end

      def range_start
        Time.zone.local(year, 1, 1).beginning_of_day
      end

      def range_end
        Date.new(year, 12, 1).end_of_month.end_of_day
      end

      def consolidators_metrics
        consolidator_ids = consolidator_ids_with_activity
        return [] if consolidator_ids.empty?

        consolidators = Entity.where(id: consolidator_ids)
          .order(:name)

        consolidators.map do |consolidator|
          containers_count = containers_count_for_consolidator(consolidator.id)
          bl_total = bl_total_count_for_consolidator(consolidator.id)
          bl_dispatched = bl_dispatched_count_for_consolidator(consolidator.id)
          bl_pending = bl_total - bl_dispatched
          revenue = revenue_for_consolidator(consolidator.id)
          avg_per_container = containers_count.positive? ? (revenue / containers_count) : 0

          {
            id: consolidator.id,
            name: consolidator.name,
            revenue: revenue,
            avg_per_container: avg_per_container,
            containers_count: containers_count,
            bl_total: bl_total,
            bl_dispatched: bl_dispatched,
            bl_pending: bl_pending,
            monthly_series: monthly_revenue_series_for_consolidator(consolidator.id)
          }
        end.sort_by { |c| -c[:revenue] }
      end

      def consolidator_ids_with_activity
        @consolidator_ids_with_activity ||= begin
          Container
            .where(created_at: range_start..range_end)
            .where.not(consolidator_entity_id: nil)
            .distinct
            .pluck(:consolidator_entity_id)
            .compact
        end
      end

      def containers_count_for_consolidator(consolidator_id)
        @containers_count_cache ||= {}
        @containers_count_cache[consolidator_id] ||= begin
          Container
            .where(consolidator_entity_id: consolidator_id, created_at: range_start..range_end)
            .count
        end
      end

      def bl_total_count_for_consolidator(consolidator_id)
        @bl_total_cache ||= {}
        @bl_total_cache[consolidator_id] ||= begin
          BlHouseLine
            .joins(:container)
            .where(containers: { consolidator_entity_id: consolidator_id })
            .distinct
            .count
        end
      end

      def bl_dispatched_count_for_consolidator(consolidator_id)
        @bl_dispatched_cache ||= {}
        @bl_dispatched_cache[consolidator_id] ||= begin
          BlHouseLine
            .joins(:container)
            .where(containers: { consolidator_entity_id: consolidator_id })
            .where(status: "despachado")
            .distinct
            .count
        end
      end

      def revenue_for_consolidator(consolidator_id)
        @revenue_cache ||= {}
        @revenue_cache[consolidator_id] ||= begin
          Invoice
            .where(
              kind: "ingreso",
              status: "issued",
              invoiceable_type: "BlHouseLineService",
              issued_at: range_start..range_end
            )
            .joins("INNER JOIN bl_house_line_services ON bl_house_line_services.id = invoices.invoiceable_id AND invoices.invoiceable_type = 'BlHouseLineService'")
            .joins("INNER JOIN bl_house_lines ON bl_house_lines.id = bl_house_line_services.bl_house_line_id")
            .joins("INNER JOIN containers ON containers.id = bl_house_lines.container_id")
            .where(containers: { consolidator_entity_id: consolidator_id })
            .sum(:total)
            .to_d
        end
      end

      def monthly_revenue_series_for_consolidator(consolidator_id)
        @monthly_revenue_cache ||= {}
        @monthly_revenue_cache[consolidator_id] ||= begin
          rows = Invoice
            .where(
              kind: "ingreso",
              status: "issued",
              invoiceable_type: "BlHouseLineService",
              issued_at: range_start..range_end
            )
            .joins("INNER JOIN bl_house_line_services ON bl_house_line_services.id = invoices.invoiceable_id AND invoices.invoiceable_type = 'BlHouseLineService'")
            .joins("INNER JOIN bl_house_lines ON bl_house_lines.id = bl_house_line_services.bl_house_line_id")
            .joins("INNER JOIN containers ON containers.id = bl_house_lines.container_id")
            .where(containers: { consolidator_entity_id: consolidator_id })
            .group(month_extract_sql("invoices.issued_at"))
            .sum(:total)

          month_hash = rows.each_with_object({}) do |(month, value), acc|
            acc[month.to_i] = value.to_d
          end

          month_numbers.map { |month| month_hash.fetch(month, 0.to_d) }
        end
      end

      def month_extract_sql(column_name)
        "EXTRACT(MONTH FROM #{column_name})"
      end
    end
  end
end
