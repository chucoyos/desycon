module Api
  module V1
    module Consolidator
      class ContainersController < BaseController
        DATE_FIELDS = %w[created_at fecha_desconsolidacion].freeze
        MAX_PER_PAGE = 100

        def index
          scope = containers_scope
          scope = apply_filters(scope)
          paginated_scope = scope.order(created_at: :desc, id: :desc).page(page).per(per_page)

          render_collection(data: paginated_scope.map { |container| serialize(container) }, scope: paginated_scope, page: page, per_page: per_page)
        rescue ArgumentError => e
          render_error(code: "invalid_parameter", message: e.message, status: :unprocessable_content)
        end

        private

        def containers_scope
          Container
            .where(consolidator_entity_id: consolidator_entity.id)
            .includes(:consolidator_entity, :shipping_line, :vessel, :voyage, :origin_port, :bl_house_lines)
        end

        def apply_filters(scope)
          scope = scope.where(status: params[:status]) if params[:status].present?
          scope = scope.where("number ILIKE ?", "%#{sanitize_like(params[:number])}%") if params[:number].present?
          scope = scope.where("archivo_nr ILIKE ?", "%#{sanitize_like(params[:reference])}%") if params[:reference].present?
          scope = scope.where("bl_master ILIKE ?", "%#{sanitize_like(params[:bl_master])}%") if params[:bl_master].present?

          date_field = params[:date_field].presence || "created_at"
          raise ArgumentError, "date_field is invalid" unless DATE_FIELDS.include?(date_field)
          raise ArgumentError, "date_from and date_to are required" if params[:date_from].blank? || params[:date_to].blank?

          start_date = Date.iso8601(params[:date_from]).beginning_of_day
          end_date = Date.iso8601(params[:date_to]).end_of_day
          raise ArgumentError, "date_from must be on or before date_to" if start_date > end_date

          scope.where(date_field => start_date..end_date)
        end

        def serialize(container)
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
            bl_house_lines_count: container.bl_house_lines.size
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
