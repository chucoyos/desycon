module Api
  module V1
    module Consolidator
      class ContainersController < BaseController
        DATE_FIELDS = %w[created_at fecha_desconsolidacion].freeze
        MAX_PER_PAGE = 100

        def index
          scope = containers_scope
          scope = apply_filters(scope)
          if incremental_sync_requested?
            validate_incremental_parameters!
            containers, next_cursor, sync_until = incremental_page(
              scope: scope,
              resource: :containers,
              filters: {
                status: params[:status],
                number: params[:number],
                reference: params[:reference],
                bl_master: params[:bl_master]
              },
              per_page: per_page
            )
            return render_incremental_containers(containers, next_cursor, sync_until)
          end

          paginated_scope = scope.order(created_at: :desc, id: :desc).page(page).per(per_page)
          containers = paginated_scope.to_a
          bl_house_line_counts = BlHouseLine.where(container_id: containers.map(&:id)).group(:container_id).count

          render_collection(
            data: serialize_containers(containers, bl_house_line_counts),
            scope: paginated_scope,
            page: page,
            per_page: per_page
          )
        rescue ArgumentError => e
          render_error(code: "invalid_parameter", message: e.message, status: :unprocessable_content)
        end

        private

        def containers_scope
          Container
            .where(consolidator_entity_id: consolidator_entity.id)
            .includes(:consolidator_entity, :shipping_line, :vessel, :voyage, :origin_port)
        end

        def apply_filters(scope)
          scope = scope.where(status: params[:status]) if params[:status].present?
          scope = scope.where("number ILIKE ?", "%#{sanitize_like(params[:number])}%") if params[:number].present?
          scope = scope.where("archivo_nr ILIKE ?", "%#{sanitize_like(params[:reference])}%") if params[:reference].present?
          scope = scope.where("bl_master ILIKE ?", "%#{sanitize_like(params[:bl_master])}%") if params[:bl_master].present?

          date_field = params[:date_field].presence || "created_at"
          raise ArgumentError, "date_field is invalid" unless DATE_FIELDS.include?(date_field)

          return scope if incremental_sync_requested?

          apply_updated_since_or_date_range(scope, date_field: date_field, require_filter: true)
        end

        def render_incremental_containers(containers, next_cursor, sync_until)
          bl_house_line_counts = BlHouseLine.where(container_id: containers.map(&:id)).group(:container_id).count
          render_incremental_collection(
            data: serialize_containers(containers, bl_house_line_counts),
            next_cursor: next_cursor,
            sync_until: sync_until,
            per_page: per_page
          )
        end

        def serialize_containers(containers, bl_house_line_counts)
          containers.map do |container|
            serialize(container, bl_house_line_count: bl_house_line_counts.fetch(container.id, 0))
          end
        end

        def serialize(container, bl_house_line_count:)
          {
            id: container.id,
            number: container.number,
            bl_master: container.bl_master,
            reference: container.archivo_nr,
            status: container.status,
            tipo_maniobra: container.tipo_maniobra,
            type_size: container.type_size,
            recinto: container.recinto,
            almacen: container.almacen,
            fecha_desconsolidacion: container.fecha_desconsolidacion,
            fecha_descarga: container.fecha_descarga,
            created_at: container.created_at,
            updated_at: container.updated_at,
            consolidator: { id: container.consolidator_entity_id, name: container.consolidator_entity&.name },
            shipping_line: { id: container.shipping_line_id, name: container.shipping_line&.name },
            vessel: { id: container.vessel_id, name: container.vessel&.name },
            voyage: { id: container.voyage_id, code: container.voyage&.viaje },
            origin_port: { id: container.origin_port_id, name: container.origin_port&.display_name },
            bl_house_lines_count: bl_house_line_count
          }
        end

        def page
          value = params[:page].presence || 1
          Integer(value).tap { |number| raise ArgumentError, "page must be greater than zero" unless number.positive? }
        end

        def per_page
          value = Integer(params[:per_page].presence || 25)
          raise ArgumentError, "per_page must be between 1 and #{MAX_PER_PAGE}" unless value.between?(1, MAX_PER_PAGE)

          value
        end

        def sanitize_like(value)
          ActiveRecord::Base.sanitize_sql_like(value.to_s)
        end
      end
    end
  end
end
