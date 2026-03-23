module Facturador
  class RegisterGroupedInvoicePaymentsService
    Result = Struct.new(:payments, :complement_invoice, keyword_init: true)

    class << self
      def call(evidence:, invoice_amounts:, paid_at:, payment_method:, reference: nil, tracking_key: nil, notes: nil, actor: nil)
        new(
          evidence: evidence,
          invoice_amounts: invoice_amounts,
          paid_at: paid_at,
          payment_method: payment_method,
          reference: reference,
          tracking_key: tracking_key,
          notes: notes,
          actor: actor
        ).call
      end
    end

    def initialize(evidence:, invoice_amounts:, paid_at:, payment_method:, reference:, tracking_key:, notes:, actor: nil)
      @evidence = evidence
      @invoice_amounts = (invoice_amounts || {}).to_h.stringify_keys
      @paid_at = paid_at
      @payment_method = payment_method
      @reference = reference
      @tracking_key = tracking_key
      @notes = notes
      @actor = actor
    end

    def call
      selected_entries = normalized_entries
      raise RequestError, "Selecciona al menos una factura con monto mayor a cero." if selected_entries.empty?

      valid_invoice_ids = evidence.invoices_for_review.map(&:id)
      unless selected_entries.all? { |entry| valid_invoice_ids.include?(entry[:invoice].id) }
        raise RequestError, "Una o más facturas no pertenecen a la evidencia seleccionada."
      end

      payments = []
      ActiveRecord::Base.transaction do
        selected_entries.each do |entry|
          payment = RegisterInvoicePaymentService.call(
            invoice: entry[:invoice],
            amount: entry[:amount].to_s("F"),
            paid_at: paid_at,
            payment_method: payment_method,
            reference: reference,
            tracking_key: tracking_key,
            notes: notes,
            actor: actor,
            issue_payment_complement: false
          )
          payments << payment
        end

        if payments.many? && payments.all? { |payment| payment.invoice.payment_complement_eligible? }
          group_key = Digest::SHA256.hexdigest("evidence-grouped-rep:#{evidence.id}:#{payments.map(&:id).sort.join(':')}")
          complement_invoice = IssueGroupedPaymentComplementService.call(
            payments: payments,
            actor: actor,
            group_key: group_key
          )
          return Result.new(payments: payments, complement_invoice: complement_invoice)
        end

        payments.each do |payment|
          next unless payment.invoice.payment_complement_eligible?

          IssuePaymentComplementService.call(payment: payment, actor: actor)
        end
      end

      Result.new(payments: payments, complement_invoice: payments.first&.complement_invoice)
    end

    private

    attr_reader :evidence, :invoice_amounts, :paid_at, :payment_method, :reference, :tracking_key, :notes, :actor

    def normalized_entries
      allowed_invoices = evidence.invoices_for_review.index_by(&:id)

      invoice_amounts.filter_map do |invoice_id, raw_amount|
        invoice = allowed_invoices[invoice_id.to_i]
        next if invoice.blank?

        amount = raw_amount.to_d
        next unless amount.positive?

        { invoice: invoice, amount: amount }
      end
    end
  end
end
