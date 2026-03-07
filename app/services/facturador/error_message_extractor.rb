module Facturador
  class ErrorMessageExtractor
    MESSAGE_KEYS = %w[
      error_description
      message
      descripcion
      mensaje
      error
      detail
      title
      exceptionMessage
      exception_message
      exceptionType
      exception_type
    ].freeze
    CODE_KEYS = %w[codigo code].freeze

    class << self
      def call(payload, fallback: nil)
        new(payload, fallback: fallback).call
      end
    end

    def initialize(payload, fallback: nil)
      @payload = payload
      @fallback = fallback
    end

    def call
      messages = extract_messages(payload)
                 .map { |value| value.to_s.strip }
                 .reject(&:blank?)
                 .uniq

      return messages.join(" | ") if messages.any?

      fallback.to_s.strip.presence || "Error no detallado por proveedor"
    end

    private

    attr_reader :payload, :fallback

    def extract_messages(node)
      case node
      when String
        [ node ]
      when Array
        node.flat_map { |item| extract_messages(item) }
      when Hash
        hash = stringify_keys(node)
        messages = []

        messages.concat(MESSAGE_KEYS.filter_map { |key| normalized(hash[key]) })
        messages.concat(extract_error_collection(hash["errores"]))
        messages.concat(extract_error_collection(hash["errors"]))
        messages.concat(extract_error_collection(hash["details"]))
        messages.concat(extract_error_collection(hash["modelState"] || hash["model_state"]))

        messages
      else
        []
      end
    end

    def extract_error_collection(value)
      case value
      when nil
        []
      when String
        [ value ]
      when Array
        value.flat_map { |item| extract_error_item(item) }
      when Hash
        hash = stringify_keys(value)

        if error_item_hash?(hash)
          extract_error_item(hash)
        else
          hash.flat_map do |field, item|
            item_messages = extract_messages(item)
            next item_messages if field.to_s.match?(/\A\d+\z/)

            item_messages.map { |message| "#{field}: #{message}" }
          end
        end
      else
        []
      end
    end

    def extract_error_item(item)
      case item
      when String
        [ item ]
      when Hash
        hash = stringify_keys(item)
        code = CODE_KEYS.filter_map { |key| normalized(hash[key]) }.first
        message = MESSAGE_KEYS.filter_map { |key| normalized(hash[key]) }.first

        return [ "#{code}: #{message}" ] if code.present? && message.present?
        return [ message ] if message.present?
        return [ code ] if code.present?

        extract_messages(hash)
      else
        extract_messages(item)
      end
    end

    def error_item_hash?(hash)
      (MESSAGE_KEYS + CODE_KEYS).any? { |key| hash.key?(key) }
    end

    def stringify_keys(value)
      value.transform_keys(&:to_s)
    end

    def normalized(value)
      text = value.to_s.strip
      text.presence
    end
  end
end
