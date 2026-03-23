module Facturador
  class IssueGroupedPaymentComplementService
    class << self
      def call(payments:, actor: nil, group_key: nil)
        new(payments: payments, actor: actor, group_key: group_key).call
      end
    end

    def initialize(payments:, actor: nil, group_key: nil)
      @payments = Array(payments)
      @actor = actor
      @group_key = group_key
    end

    def call
      raise RequestError, "At least one payment is required" if payments.empty?

      invoices = payments.map(&:invoice)
      raise RequestError, "All payments must reference issued invoices" unless invoices.all?(&:issued?)
      raise RequestError, "All source invoices must include UUID" unless invoices.all? { |invoice| invoice.sat_uuid.present? }

      issuer_ids = invoices.map(&:issuer_entity_id).uniq
      receiver_ids = invoices.map(&:receiver_entity_id).uniq
      raise RequestError, "Grouped payment complement requires the same issuer" if issuer_ids.size > 1
      raise RequestError, "Grouped payment complement requires the same receiver" if receiver_ids.size > 1

      payment_methods = payments.map(&:payment_method).uniq
      raise RequestError, "Grouped payment complement requires the same payment method" if payment_methods.size > 1

      paid_dates = payments.map { |payment| payment.paid_at.to_date }.uniq
      raise RequestError, "Grouped payment complement requires payments on the same date" if paid_dates.size > 1

      complement = find_or_build_complement
      complement.save! if complement.new_record?

      payments.each do |payment|
        payment.update!(
          complement_invoice: complement,
          status: "complement_queued"
        )
      end

      complement.queue_issue!(actor: actor)
      complement
    rescue Error
      payments.each do |payment|
        payment.update!(status: "failed")
      rescue StandardError
        nil
      end
      raise
    end

    private

    attr_reader :payments, :actor, :group_key

    def find_or_build_complement
      Invoice.find_or_initialize_by(idempotency_key: idempotency_key).tap do |complement|
        next unless complement.new_record?

        first_invoice = payments.first.invoice
        grouped_payments_payload = payments.map do |payment|
          {
            payment_id: payment.id,
            source_invoice_id: payment.invoice_id,
            source_invoice_uuid: payment.invoice.sat_uuid,
            amount: payment.amount.to_s,
            paid_at: payment.paid_at.iso8601,
            payment_method: payment.payment_method,
            currency: payment.currency
          }
        end

        total_amount = payments.sum { |payment| payment.amount.to_d }

        complement.assign_attributes(
          invoiceable: first_invoice.invoiceable,
          issuer_entity: first_invoice.issuer_entity,
          receiver_entity: first_invoice.receiver_entity,
          kind: "pago",
          status: "draft",
          currency: first_invoice.currency,
          subtotal: total_amount,
          tax_total: 0,
          total: total_amount,
          payload_snapshot: {
            metadataInterna: {
              grouped_payments: grouped_payments_payload
            }
          },
          provider_response: {}
        )
      end
    end

    def idempotency_key
      return group_key if group_key.present?

      payment_ids = payments.map(&:id).sort.join(":")
      Digest::SHA256.hexdigest("payment-complement-group:#{payment_ids}")
    end
  end
end
