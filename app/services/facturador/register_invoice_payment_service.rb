module Facturador
  class RegisterInvoicePaymentService
    class << self
      def call(invoice:, amount:, paid_at:, payment_method:, reference: nil, tracking_key: nil, notes: nil, receipt_file: nil, actor: nil)
        new(
          invoice: invoice,
          amount: amount,
          paid_at: paid_at,
          payment_method: payment_method,
          reference: reference,
          tracking_key: tracking_key,
          notes: notes,
          receipt_file: receipt_file,
          actor: actor
        ).call
      end
    end

    def initialize(invoice:, amount:, paid_at:, payment_method:, reference:, tracking_key:, notes:, receipt_file:, actor: nil)
      @invoice = invoice
      @amount = amount
      @paid_at = paid_at
      @payment_method = payment_method
      @reference = reference
      @tracking_key = tracking_key
      @notes = notes
      @receipt_file = receipt_file
      @actor = actor
    end

    def call
      raise RequestError, "Invoice is not eligible for payment registration" unless invoice.issued? || invoice.status == "cancel_pending"
      raise RequestError, invoice.payment_registration_ineligibility_reason if invoice.payment_registration_ineligibility_reason.present?

      payment = invoice.invoice_payments.create!(
        amount: amount,
        currency: invoice.currency,
        paid_at: paid_at,
        payment_method: payment_method,
        reference: reference,
        tracking_key: tracking_key,
        notes: notes,
        status: "registered"
      )

      payment.receipt_file.attach(receipt_file) if receipt_file.present?

      if invoice.payment_complement_eligible?
        invoice.invoice_events.create!(
          event_type: "payment_registered",
          created_by: actor,
          request_payload: {
            payment_id: payment.id,
            amount: amount,
            paid_at: paid_at,
            payment_method: payment_method,
            reference: reference,
            tracking_key: tracking_key,
            receipt_attached: payment.receipt_file.attached?
          },
          response_payload: { status: "registered" }
        )

        IssuePaymentComplementService.call(payment: payment, actor: actor)
      end
      payment
    end

    private

    attr_reader :invoice, :amount, :paid_at, :payment_method, :reference, :tracking_key, :notes, :receipt_file, :actor
  end
end
