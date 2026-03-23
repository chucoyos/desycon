module PaymentEvidences
  class CreateForConsolidatorService
    Result = Struct.new(:success?, :evidence, :error_message, keyword_init: true)

    ELIGIBLE_STATUSES = %w[issued cancel_pending].freeze

    def self.call(actor:, invoice_ids:, reference:, tracking_key:, receipt_file:)
      new(
        actor: actor,
        invoice_ids: invoice_ids,
        reference: reference,
        tracking_key: tracking_key,
        receipt_file: receipt_file
      ).call
    end

    def initialize(actor:, invoice_ids:, reference:, tracking_key:, receipt_file:)
      @actor = actor
      @invoice_ids = Array(invoice_ids).map(&:to_s).map(&:strip).reject(&:blank?).uniq
      @reference = reference.to_s.strip
      @tracking_key = tracking_key.to_s.strip
      @receipt_file = receipt_file
    end

    def call
      return failure("Selecciona al menos una factura.") if @invoice_ids.empty?
      return failure("Adjunta un comprobante de pago.") if @receipt_file.blank?

      eligible_invoices = Invoice
        .where(receiver_entity_id: @actor.entity_id)
        .where(status: ELIGIBLE_STATUSES)
        .where(id: @invoice_ids)
        .includes(:invoice_payments)

      return failure("Una o más facturas no son válidas para tu cuenta.") unless eligible_invoices.size == @invoice_ids.size

      ineligible_balance = eligible_invoices.detect { |invoice| !invoice.outstanding_amount.positive? }
      return failure("La factura ##{ineligible_balance.id} ya no tiene saldo pendiente.") if ineligible_balance

      evidence = nil
      ActiveRecord::Base.transaction do
        evidence = InvoicePaymentEvidence.new(
          customs_agent: @actor.entity,
          submitted_by: @actor,
          reference: @reference,
          tracking_key: @tracking_key.presence,
          status: "pending"
        )
        evidence.invoice = eligible_invoices.first
        evidence.receipt_file.attach(@receipt_file)
        evidence.save!

        eligible_invoices.each do |invoice|
          evidence.invoice_payment_evidence_links.create!(invoice: invoice)
        end
      end

      Result.new(success?: true, evidence: evidence)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    private

    def failure(message)
      Result.new(success?: false, error_message: message)
    end
  end
end
