module Api
  module V1
    module Consolidator
      class PhotosController < BaseController
        PRESIGNED_URL_TTL = 5.minutes

        def index
          attachable = find_attachable
          return render_error(code: "not_found", message: "Resource not found.", status: :not_found) unless attachable

          scope = attachable.photos.for_section(params[:section].presence || default_section).recent.includes(image_attachment: :blob)
          scope = scope.page(page).per(per_page)

          render_collection(data: scope.map { |photo| serialize(photo) }, scope: scope, page: page, per_page: per_page)
        rescue ArgumentError => e
          render_error(code: "invalid_parameter", message: e.message, status: :unprocessable_content)
        end

        private

        def find_attachable
          if params[:bl_house_line_id].present?
            BlHouseLine
              .joins(:container)
              .where(containers: { consolidator_entity_id: consolidator_entity.id })
              .find_by(id: params[:bl_house_line_id])
          else
            Container
              .where(consolidator_entity_id: consolidator_entity.id)
              .find_by(id: params[:container_id])
          end
        end

        def default_section
          params[:bl_house_line_id].present? ? "etiquetado" : "apertura"
        end

        def serialize(photo)
          {
            id: photo.id,
            section: photo.section,
            filename: photo.image.filename.to_s,
            content_type: photo.image.content_type,
            byte_size: photo.image.byte_size,
            created_at: photo.created_at,
            download_url: download_url_for(photo),
            expires_at: presigned_url?(photo) ? PRESIGNED_URL_TTL.from_now.iso8601 : nil
          }
        end

        def download_url_for(photo)
          return photo.image.service.url(
            photo.image.blob.key,
            expires_in: PRESIGNED_URL_TTL,
            disposition: "inline",
            filename: photo.image.filename,
            content_type: photo.image.content_type
          ) if presigned_url?(photo)

          Rails.application.routes.url_helpers.rails_blob_path(
            photo.image,
            disposition: "inline",
            only_path: true
          )
        end

        def presigned_url?(photo)
          photo.image.blob.service_name.to_s == "amazon"
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
