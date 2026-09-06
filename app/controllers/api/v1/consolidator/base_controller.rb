module Api
  module V1
    module Consolidator
      class BaseController < ActionController::API
        before_action :authenticate_api_key!

        private

        attr_reader :api_credential, :consolidator_entity

        def authenticate_api_key!
          @api_credential = ConsolidatorApiCredential.authenticate(bearer_token)
          @consolidator_entity = @api_credential&.entity

          unless @api_credential && @consolidator_entity&.role_consolidator?
            render_error(code: "invalid_api_key", message: "API key is invalid or inactive.", status: :unauthorized)
            return
          end

          @api_credential.touch_last_used!
        end

        def bearer_token
          scheme, token = request.authorization.to_s.split(" ", 2)
          scheme&.casecmp?("Bearer") ? token : nil
        end

        def render_error(code:, message:, status:, details: {})
          render json: { error: { code: code, message: message, details: details } }, status: status
        end

        def render_collection(data:, scope:, page:, per_page:)
          render json: {
            data: data,
            meta: {
              page: page,
              per_page: per_page,
              total_count: scope.total_count,
              total_pages: scope.total_pages
            }
          }
        end
      end
    end
  end
end
