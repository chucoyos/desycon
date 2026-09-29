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

        def render_incremental_collection(data:, next_cursor:, sync_until:, per_page:)
          render json: {
            data: data,
            meta: {
              per_page: per_page,
              next_cursor: next_cursor,
              sync_until: sync_until.iso8601(6)
            }
          }
        end

        def incremental_sync_requested?
          params[:updated_since].present? || params[:cursor].present?
        end

        def validate_incremental_parameters!
          if params[:date_from].present? || params[:date_to].present?
            raise ArgumentError, "updated_since cannot be combined with date_from or date_to"
          end
          raise ArgumentError, "cursor cannot be combined with updated_since" if params[:cursor].present? && params[:updated_since].present?
          raise ArgumentError, "page cannot be used with cursor pagination" if params[:page].present?
        end

        def incremental_page(scope:, resource:, filters:, per_page:)
          filter_signature = Digest::SHA256.hexdigest(filters.stringify_keys.sort.to_h.to_json)

          if params[:cursor].present?
            cursor_data = decode_incremental_cursor(params[:cursor], resource:, filter_signature:)
            since = Time.iso8601(cursor_data.fetch("since"))
            sync_until = Time.iso8601(cursor_data.fetch("sync_until"))
            after_updated_at = Time.iso8601(cursor_data.fetch("after_updated_at"))
            after_id = Integer(cursor_data.fetch("after_id"))
          else
            since = parse_updated_since(params[:updated_since].presence || raise(ArgumentError, "updated_since is required"))
            sync_until = [ Time.current, since ].max
            after_updated_at = nil
            after_id = nil
          end

          updated_at = scope.klass.arel_table[:updated_at]
          scope = scope.where(updated_at.gteq(since)).where(updated_at.lteq(sync_until))
          if after_updated_at
            id = scope.klass.arel_table[:id]
            scope = scope.where(updated_at.gt(after_updated_at).or(updated_at.eq(after_updated_at).and(id.gt(after_id))))
          end

          records = scope.reorder(updated_at: :asc, id: :asc).limit(per_page + 1).to_a
          has_more = records.length > per_page
          records = records.first(per_page)
          next_cursor = if has_more
                          encode_incremental_cursor(
                            resource:,
                            filter_signature:,
                            since:,
                            sync_until:,
                            last_record: records.last
                          )
          end

          [ records, next_cursor, sync_until ]
        end

        def apply_updated_since_or_date_range(scope, date_field:, require_filter:)
          updated_since = params[:updated_since].presence
          date_range_requested = params[:date_from].present? || params[:date_to].present?

          if updated_since
            raise ArgumentError, "updated_since cannot be combined with date_from or date_to" if date_range_requested

            timestamp = parse_updated_since(updated_since)
            return scope.where(scope.klass.arel_table[:updated_at].gteq(timestamp))
          end

          return scope unless date_range_requested || require_filter
          raise ArgumentError, "date_from and date_to are required" if params[:date_from].blank? || params[:date_to].blank?

          start_date = Date.iso8601(params[:date_from]).beginning_of_day
          end_date = Date.iso8601(params[:date_to]).end_of_day
          raise ArgumentError, "date_from must be on or before date_to" if start_date > end_date

          scope.where(scope.klass.table_name => { date_field => start_date..end_date })
        end

        def parse_updated_since(value)
          timestamp = Time.iso8601(value)
          return timestamp if timestamp.utc_offset.zero? && value.match?(/(?:Z|\+00:00)\z/)

          raise ArgumentError, "updated_since must be an ISO 8601 UTC timestamp"
        rescue ArgumentError, TypeError
          raise ArgumentError, "updated_since must be an ISO 8601 UTC timestamp"
        end

        def encode_incremental_cursor(resource:, filter_signature:, since:, sync_until:, last_record:)
          payload = {
            "entity_id" => consolidator_entity.id,
            "resource" => resource.to_s,
            "filter_signature" => filter_signature,
            "since" => since.iso8601(6),
            "sync_until" => sync_until.iso8601(6),
            "after_updated_at" => last_record.updated_at.iso8601(6),
            "after_id" => last_record.id
          }

          incremental_cursor_verifier.generate(payload, purpose: resource.to_s)
        end

        def decode_incremental_cursor(token, resource:, filter_signature:)
          payload = incremental_cursor_verifier.verify(token, purpose: resource.to_s)
          valid = payload["entity_id"] == consolidator_entity.id &&
            payload["resource"] == resource.to_s &&
            payload["filter_signature"] == filter_signature
          raise ArgumentError unless valid

          payload
        rescue ActiveSupport::MessageVerifier::InvalidSignature, KeyError, ArgumentError, TypeError
          raise ArgumentError, "cursor is invalid or does not match this request"
        end

        def incremental_cursor_verifier
          Rails.application.message_verifier("consolidator_incremental_sync")
        end
      end
    end
  end
end
