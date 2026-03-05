module Facturador
  class IssuePaymentComplementService
    class << self
      def call(payment:, actor: nil)
        new(payment: payment, actor: actor).call
      end
    end

    def initialize(payment:, actor: nil)
      @payment = payment
      @actor = actor
    end

    def call
      return payment unless Config.enabled?
      return payment unless Config.payment_complements_enabled?

      invoice = payment.invoice
      raise RequestError, "Invoice must be issued to create payment complement" unless invoice.issued?

      complement = find_or_build_complement_for(invoice: invoice)
      complement.save! if complement.new_record?

      payment.update!(
        complement_invoice: complement,
        status: "complement_queued"
      )

      complement.queue_issue!(actor: actor)
      payment
    rescue Error => e
      payment.update!(status: "failed")
      payment.invoice.invoice_events.create!(
        event_type: "issue_failed",
        created_by: actor,
        request_payload: { payment_id: payment.id },
        response_payload: { error: e.message },
        provider_error_message: e.message
      )
      raise
    end

    private

    attr_reader :payment, :actor

    def find_or_build_complement_for(invoice:)
      key = Digest::SHA256.hexdigest("payment-complement:#{invoice.id}:#{payment.id}:#{payment.amount.to_s('F')}")
      Invoice.find_or_initialize_by(idempotency_key: key).tap do |complement|
        next unless complement.new_record?

        complement.assign_attributes(
          invoiceable: invoice.invoiceable,
          issuer_entity: invoice.issuer_entity,
          receiver_entity: invoice.receiver_entity,
          kind: "pago",
          status: "draft",
          currency: payment.currency,
          subtotal: payment.amount,
          tax_total: 0,
          total: payment.amount,
          payload_snapshot: {
            payment: {
              payment_id: payment.id,
              amount: payment.amount.to_s,
              paid_at: payment.paid_at.iso8601,
              payment_method: payment.payment_method,
              reference: payment.reference
            },
            source_invoice_uuid: invoice.sat_uuid
          },
          provider_response: {}
        )
      end
    end
  end
end
