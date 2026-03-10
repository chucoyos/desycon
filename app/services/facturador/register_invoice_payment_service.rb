module Facturador
  class RegisterInvoicePaymentService
    class << self
      def call(invoice:, amount:, paid_at:, payment_method:, reference: nil, notes: nil, actor: nil)
        new(
          invoice: invoice,
          amount: amount,
          paid_at: paid_at,
          payment_method: payment_method,
          reference: reference,
          notes: notes,
          actor: actor
        ).call
      end
    end

    def initialize(invoice:, amount:, paid_at:, payment_method:, reference:, notes:, actor: nil)
      @invoice = invoice
      @amount = amount
      @paid_at = paid_at
      @payment_method = payment_method
      @reference = reference
      @notes = notes
      @actor = actor
    end

    def call
      raise RequestError, "Invoice is not eligible for payment registration" unless invoice.issued? || invoice.status == "cancel_pending"
      raise RequestError, invoice.payment_complement_ineligibility_reason if invoice.payment_complement_ineligibility_reason.present?

      payment = invoice.invoice_payments.create!(
        amount: amount,
        currency: invoice.currency,
        paid_at: paid_at,
        payment_method: payment_method,
        reference: reference,
        notes: notes,
        status: "registered"
      )

      invoice.invoice_events.create!(
        event_type: "reconcile_requested",
        created_by: actor,
        request_payload: {
          payment_id: payment.id,
          amount: amount,
          paid_at: paid_at,
          payment_method: payment_method,
          reference: reference
        },
        response_payload: { status: "registered" }
      )

      IssuePaymentComplementService.call(payment: payment, actor: actor)
      payment
    end

    private

    attr_reader :invoice, :amount, :paid_at, :payment_method, :reference, :notes, :actor
  end
end
