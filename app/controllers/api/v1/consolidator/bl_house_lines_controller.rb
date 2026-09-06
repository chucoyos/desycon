module Api
  module V1
    module Consolidator
      class BlHouseLinesController < BaseController
        def index
          container = consolidator_containers.find_by(id: params[:container_id])
          return render_error(code: "not_found", message: "Container not found.", status: :not_found) unless container

          scope = container.bl_house_lines.includes(:client, :customs_agent, :customs_broker, :packaging)
          scope = scope.where(status: params[:status]) if params[:status].present?
          scope = scope.order(created_at: :desc, id: :desc).page(page).per(per_page)

          render_collection(data: scope.map { |bl_house_line| serialize(bl_house_line) }, scope: scope, page: page, per_page: per_page)
        rescue ArgumentError => e
          render_error(code: "invalid_parameter", message: e.message, status: :unprocessable_content)
        end

        private

        def consolidator_containers
          Container.where(consolidator_entity_id: consolidator_entity.id)
        end

        def serialize(bl_house_line)
          {
            id: bl_house_line.id,
            container_id: bl_house_line.container_id,
            partida: bl_house_line.partida,
            blhouse: bl_house_line.blhouse,
            cantidad: bl_house_line.cantidad,
            packaging: { id: bl_house_line.packaging_id, name: bl_house_line.packaging&.nombre },
            contiene: bl_house_line.contiene,
            marcas: bl_house_line.marcas,
            peso: bl_house_line.peso,
            volumen: bl_house_line.volumen,
            clase_imo: bl_house_line.clase_imo,
            tipo_imo: bl_house_line.tipo_imo,
            telex: bl_house_line.telex,
            status: bl_house_line.status,
            fecha_despacho: bl_house_line.fecha_despacho,
            created_at: bl_house_line.created_at,
            updated_at: bl_house_line.updated_at,
            client: { id: bl_house_line.client_id, name: bl_house_line.client&.name },
            customs_agent: { id: bl_house_line.customs_agent_id, name: bl_house_line.customs_agent&.name },
            customs_broker: { id: bl_house_line.customs_broker_id, name: bl_house_line.customs_broker&.name }
          }
        end

        def page
          value = params[:page].presence || 1
          Integer(value).tap { |number| raise ArgumentError, "page must be greater than zero" unless number.positive? }
        end

        def per_page
          value = Integer(params[:per_page].presence || 25)
          raise ArgumentError, "per_page must be between 1 and 100" unless value.between?(1, 100)

          value
        end
      end
    end
  end
end
