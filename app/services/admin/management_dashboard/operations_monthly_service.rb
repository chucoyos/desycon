module Admin
  module ManagementDashboard
    class OperationsMonthlyService
      MONTH_LABELS = %w[Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic].freeze
      IMPORT_DESTINATION_PORTS = {
        "MXZLO" => "Manzanillo",
        "MXLZC" => "Lazaro Cardenas",
        "MXATM" => "Altamira",
        "MXVER" => "Veracruz"
      }.freeze

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
          containers: {
            created: container_created_series,
            closed: container_closed_series,
            unconsolidated: container_unconsolidated_series
          },
          bl_house_lines: {
            created: bl_created_series,
            revalidated: bl_revalidated_series,
            dispatched: bl_dispatched_series
          },
          destination_port_importation: destination_port_importation_series,
          totals: {
            containers_created: container_created_series.sum,
            containers_closed: container_closed_series.sum,
            containers_unconsolidated: container_unconsolidated_series.sum,
            bl_created: bl_created_series.sum,
            bl_revalidated: bl_revalidated_series.sum,
            bl_dispatched: bl_dispatched_series.sum
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

      def container_created_series
        month_numbers.map { |month| container_created_by_month.fetch(month, 0) }
      end

      def container_closed_series
        month_numbers.map { |month| container_closed_by_month.fetch(month, 0) }
      end

      def container_unconsolidated_series
        month_numbers.map { |month| container_unconsolidated_by_month.fetch(month, 0) }
      end

      def bl_created_series
        month_numbers.map { |month| bl_created_by_month.fetch(month, 0) }
      end

      def bl_revalidated_series
        month_numbers.map { |month| bl_revalidated_by_month.fetch(month, 0) }
      end

      def bl_dispatched_series
        month_numbers.map { |month| bl_dispatched_by_month.fetch(month, 0) }
      end

      def destination_port_importation_series
        IMPORT_DESTINATION_PORTS.to_h do |code, label|
          [
            label,
            month_numbers.map { |month| destination_port_importation_by_month_and_code.dig(code, month) || 0 }
          ]
        end
      end

      def container_created_by_month
        @container_created_by_month ||= begin
          rows = Container
            .where(created_at: range_start..range_end)
            .group("EXTRACT(MONTH FROM containers.created_at)")
            .count

          normalize_month_hash(rows)
        end
      end

      def container_closed_by_month
        @container_closed_by_month ||= begin
          rows = ContainerStatusHistory
            .where(status: %w[descargado desconsolidado], fecha_actualizacion: range_start..range_end)
            .group("EXTRACT(MONTH FROM container_status_histories.fecha_actualizacion)")
            .distinct
            .count(:container_id)

          normalize_month_hash(rows)
        end
      end

      def container_unconsolidated_by_month
        @container_unconsolidated_by_month ||= begin
          rows = ContainerStatusHistory
            .where(status: "desconsolidado", fecha_actualizacion: range_start..range_end)
            .group("EXTRACT(MONTH FROM container_status_histories.fecha_actualizacion)")
            .distinct
            .count(:container_id)

          normalize_month_hash(rows)
        end
      end

      def bl_created_by_month
        @bl_created_by_month ||= begin
          rows = BlHouseLine
            .where(created_at: range_start..range_end)
            .group("EXTRACT(MONTH FROM bl_house_lines.created_at)")
            .count

          normalize_month_hash(rows)
        end
      end

      def bl_revalidated_by_month
        @bl_revalidated_by_month ||= begin
          rows = BlHouseLineStatusHistory
            .where(status: "revalidado", changed_at: range_start..range_end)
            .group("EXTRACT(MONTH FROM bl_house_line_status_histories.changed_at)")
            .distinct
            .count(:bl_house_line_id)

          normalize_month_hash(rows)
        end
      end

      def bl_dispatched_by_month
        @bl_dispatched_by_month ||= begin
          rows = BlHouseLineStatusHistory
            .where(status: "despachado", changed_at: range_start..range_end)
            .group("EXTRACT(MONTH FROM bl_house_line_status_histories.changed_at)")
            .distinct
            .count(:bl_house_line_id)

          normalize_month_hash(rows)
        end
      end

      def destination_port_importation_by_month_and_code
        @destination_port_importation_by_month_and_code ||= begin
          rows = Container
            .joins(voyage: :destination_port)
            .where(tipo_maniobra: "importacion")
            .where(created_at: range_start..range_end)
            .where(ports: { code: IMPORT_DESTINATION_PORTS.keys })
            .group("ports.code", "EXTRACT(MONTH FROM containers.created_at)")
            .count

          rows.each_with_object({}) do |((code, month), count), acc|
            acc[code] ||= {}
            acc[code][month.to_i] = count
          end
        end
      end

      def normalize_month_hash(rows)
        rows.each_with_object({}) do |(month, value), acc|
          acc[month.to_i] = value.to_i
        end
      end
    end
  end
end
