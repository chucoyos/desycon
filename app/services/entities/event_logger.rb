module Entities
  class EventLogger
    TRACKED_ENTITY_FIELDS = %w[
      name
      role_kind
      customs_agent_id
      patent_number
      enforce_overdue_payment_rule
      requires_bl_endosado_documento
      requires_liberacion_documento
      requires_encomienda_documento
      requires_pago_documento
    ].freeze

    TRACKED_FISCAL_FIELDS = %w[
      rfc
      razon_social
      regimen
      uso_cfdi
      forma_pago
      metodo_pago
    ].freeze

    TRACKED_ADDRESS_FIELDS = %w[
      id
      tipo
      calle
      numero_exterior
      numero_interior
      colonia
      municipio
      localidad
      estado
      codigo_postal
      pais
      email
    ].freeze

    TRACKED_EMAIL_RECIPIENT_FIELDS = %w[
      id
      email
      position
      active
      primary_recipient
    ].freeze

    class << self
      def snapshot(entity)
        new(entity: entity).snapshot
      end

      def log_created(entity:, user: nil)
        snapshot_data = snapshot(entity)

        entity.entity_events.create!(
          event_type: "entity_created",
          user: user,
          changed_fields_json: {},
          snapshot_json: snapshot_data
        )
      rescue StandardError => e
        Rails.logger.warn("EntityEvent log_created skipped for entity=#{entity.id}: #{e.message}")
      end

      def log_updated(entity:, user: nil, before_snapshot:)
        after_snapshot = snapshot(entity)
        changed_fields = diff(before_snapshot, after_snapshot)
        return if changed_fields.blank?

        entity.entity_events.create!(
          event_type: "entity_updated",
          user: user,
          changed_fields_json: changed_fields,
          snapshot_json: after_snapshot
        )
      rescue StandardError => e
        Rails.logger.warn("EntityEvent log_updated skipped for entity=#{entity.id}: #{e.message}")
      end

      def log_baseline(entity:)
        snapshot_data = snapshot(entity)

        entity.entity_events.create!(
          event_type: "entity_baseline",
          user: nil,
          changed_fields_json: {},
          snapshot_json: snapshot_data,
          created_at: entity.created_at,
          updated_at: entity.created_at
        )
      rescue StandardError => e
        Rails.logger.warn("EntityEvent log_baseline skipped for entity=#{entity.id}: #{e.message}")
      end

      private

      def diff(before_snapshot, after_snapshot)
        before_hash = normalize_hash(before_snapshot)
        after_hash = normalize_hash(after_snapshot)

        compare_hash(before_hash, after_hash)
      end

      def compare_hash(before_hash, after_hash, prefix = nil, acc = {})
        (before_hash.keys | after_hash.keys).each do |key|
          path = [ prefix, key ].compact.join(".")
          before_value = before_hash[key]
          after_value = after_hash[key]

          if before_value.is_a?(Hash) && after_value.is_a?(Hash)
            compare_hash(before_value, after_value, path, acc)
          elsif before_value != after_value
            acc[path] = {
              "before" => before_value,
              "after" => after_value
            }
          end
        end

        acc
      end

      def normalize_hash(value)
        value.to_h.deep_stringify_keys
      end
    end

    def initialize(entity:)
      @entity = entity
    end

    def snapshot
      entity.reload

      {
        "entity" => entity.attributes.slice(*TRACKED_ENTITY_FIELDS),
        "fiscal_profile" => fiscal_profile_snapshot,
        "addresses" => addresses_snapshot,
        "email_recipients" => email_recipients_snapshot
      }
    end

    private

    attr_reader :entity

    def fiscal_profile_snapshot
      entity.fiscal_profile&.attributes&.slice(*TRACKED_FISCAL_FIELDS) || {}
    end

    def addresses_snapshot
      entity.addresses.order(:id).map do |address|
        address.attributes.slice(*TRACKED_ADDRESS_FIELDS)
      end
    end

    def email_recipients_snapshot
      entity.entity_email_recipients.order(:position, :id).map do |recipient|
        recipient.attributes.slice(*TRACKED_EMAIL_RECIPIENT_FIELDS)
      end
    end
  end
end
