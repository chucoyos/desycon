require "json"
require "net/http"
require "uri"

module Heroku
  class ScaleFormationJob < ApplicationJob
    queue_as :default

    PROCESS_TYPES = %w[web worker_active_storage].freeze
    PROFILE_TO_SIZE = {
      "day" => "standard-2x",
      "night" => "standard-1x"
    }.freeze
    API_BASE_URL = "https://api.heroku.com".freeze

    def perform(profile)
      ensure_production_environment!

      normalized_profile = profile.to_s.downcase
      target_size = PROFILE_TO_SIZE[normalized_profile]
      raise ArgumentError, "Invalid profile '#{profile}'. Allowed: #{PROFILE_TO_SIZE.keys.join(', ')}" if target_size.blank?

      app_name = ENV["SCALE_APP_NAME"].to_s.presence || ENV["HEROKU_SCALE_APP"].to_s.presence || ENV["HEROKU_APP_NAME"].to_s.presence
      api_key = ENV["SCALE_HEROKU_API_KEY"].to_s.presence || ENV["HEROKU_API_KEY"].to_s

      if ENV["SCALE_APP_NAME"].blank? && ENV["HEROKU_SCALE_APP"].present?
        Rails.logger.warn("[Heroku::ScaleFormationJob] Using legacy env var HEROKU_SCALE_APP. Prefer SCALE_APP_NAME.")
      end

      if ENV["SCALE_HEROKU_API_KEY"].blank? && ENV["HEROKU_API_KEY"].present?
        Rails.logger.warn("[Heroku::ScaleFormationJob] Using legacy env var HEROKU_API_KEY. Prefer SCALE_HEROKU_API_KEY.")
      end

      raise ArgumentError, "Missing SCALE_APP_NAME config var (legacy fallback: HEROKU_SCALE_APP/HEROKU_APP_NAME)" if app_name.blank?
      raise ArgumentError, "Missing SCALE_HEROKU_API_KEY config var (legacy fallback: HEROKU_API_KEY)" if api_key.blank?

      formation = request_json(
        method: :get,
        path: "/apps/#{app_name}/formation",
        api_key: api_key
      )

      updates = build_updates(formation: formation, target_size: target_size)

      if updates.empty?
        Rails.logger.info("[Heroku::ScaleFormationJob] No updates needed profile=#{normalized_profile} target_size=#{target_size}")
        return
      end

      request_json(
        method: :patch,
        path: "/apps/#{app_name}/formation",
        api_key: api_key,
        body: { updates: updates }
      )

      Rails.logger.info(
        "[Heroku::ScaleFormationJob] Applied updates profile=#{normalized_profile} target_size=#{target_size} updates=#{updates.map { |u| "#{u['type']}:#{u['size']}" }.join(',')}"
      )
    end

    private

    def ensure_production_environment!
      raise "Heroku::ScaleFormationJob can run only in production" unless Rails.env.production?
    end

    def build_updates(formation:, target_size:)
      PROCESS_TYPES.each_with_object([]) do |process_type, acc|
        current = formation.find { |entry| entry["type"] == process_type }

        if current.blank?
          Rails.logger.warn("[Heroku::ScaleFormationJob] Missing process type in formation: #{process_type}")
          next
        end

        current_size = current["size"].to_s
        next if current_size == target_size

        acc << {
          "type" => process_type,
          "size" => target_size,
          "quantity" => current["quantity"].to_i
        }
      end
    end

    def request_json(method:, path:, api_key:, body: nil)
      uri = URI.join(API_BASE_URL, path)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = build_request(method: method, uri: uri)
      request["Accept"] = "application/vnd.heroku+json; version=3"
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.dump(body) if body.present?

      response = http.request(request)
      parsed_body = parse_body(response.body)

      return parsed_body if response.is_a?(Net::HTTPSuccess)

      error_message = parsed_body.is_a?(Hash) ? parsed_body["message"].to_s : response.body.to_s
      raise "Heroku API error (#{response.code}): #{error_message.presence || 'unknown error'}"
    end

    def build_request(method:, uri:)
      case method
      when :get
        Net::HTTP::Get.new(uri)
      when :patch
        Net::HTTP::Patch.new(uri)
      else
        raise ArgumentError, "Unsupported HTTP method: #{method}"
      end
    end

    def parse_body(payload)
      return [] if payload.to_s.strip.empty?

      JSON.parse(payload)
    rescue JSON::ParserError
      payload
    end
  end
end
