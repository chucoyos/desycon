require "digest"

module Facturador
  class AutoIssueService
    class << self
      def call(invoiceable:, actor: nil, force: false)
        new(invoiceable: invoiceable, actor: actor, force: force).call
      end
    end

    def initialize(invoiceable:, actor: nil, force: false)
      @invoiceable = invoiceable
      @actor = actor
      @force = force
    end

    def call
      return unless Config.enabled?
      return unless force || Config.auto_issue_enabled?
      return if invoiceable.nil?

      receiver = invoiceable.billed_to_entity
      issuer = resolve_issuer_entity
      return if receiver.blank? || issuer.blank?
      return unless fiscal_ready?(receiver)
      return unless fiscal_ready?(issuer)
      return if skip_auto_issue_for_nipon_exception?(receiver: receiver)

      amount = invoiceable.amount.to_d
      return unless amount.positive?

      invoice = find_or_build_invoice(issuer: issuer, receiver: receiver, amount: amount)
      invoice.save! if invoice.new_record?
      invoice.queue_issue!(actor: actor)
      invoice
    rescue StandardError => e
      Rails.logger.error("Facturador::AutoIssueService failed for #{invoiceable.class.name}##{invoiceable.id}: #{e.message}")
      nil
    end

    private

    attr_reader :invoiceable, :actor, :force

    def find_or_build_invoice(issuer:, receiver:, amount:)
      Invoice.find_or_initialize_by(idempotency_key: idempotency_key(amount)).tap do |invoice|
        next unless invoice.new_record?

        tax_total = (amount * BigDecimal("0.16")).round(2)
        invoice.assign_attributes(
          invoiceable: invoiceable,
          issuer_entity: issuer,
          receiver_entity: receiver,
          kind: "ingreso",
          status: "draft",
          currency: "MXN",
          subtotal: amount,
          tax_total: tax_total,
          total: amount + tax_total,
          payload_snapshot: {},
          provider_response: {}
        )
      end
    end

    def idempotency_key(amount)
      Digest::SHA256.hexdigest("auto:#{invoiceable.class.name}:#{invoiceable.id}:#{amount.to_s('F')}")
    end

    def resolve_issuer_entity
      configured_id = Config.issuer_entity_id
      return Entity.find_by(id: configured_id) if configured_id.present?

      nil
    end

    def fiscal_ready?(entity)
      entity.fiscal_profile.present? && entity.fiscal_address.present?
    end

    def skip_auto_issue_for_nipon_exception?(receiver:)
      return false unless Config.auto_issue_nipon_exception_enabled?
      return false unless invoiceable.is_a?(BlHouseLineService)

      target_rfc = Config.auto_issue_nipon_rfc
      return false if target_rfc.blank?

      consolidator = invoiceable.bl_house_line&.container&.consolidator_entity
      return false if consolidator.blank?

      consolidator_rfc = normalized_rfc(consolidator)
      receiver_rfc = normalized_rfc(receiver)
      return false if consolidator_rfc.blank? || receiver_rfc.blank?
      return false unless consolidator_rfc == receiver_rfc
      return false unless consolidator_rfc == target_rfc

      Rails.logger.info(
        "Facturador::AutoIssueService skipped by Nipon exception for #{invoiceable.class.name}##{invoiceable.id} " \
        "(consolidator_id=#{consolidator.id}, receiver_id=#{receiver.id}, rfc=#{target_rfc})"
      )
      true
    end

    def normalized_rfc(entity)
      entity&.fiscal_profile&.rfc.to_s.upcase.strip.presence
    end
  end
end
