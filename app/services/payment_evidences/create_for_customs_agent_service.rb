module PaymentEvidences
  class CreateForCustomsAgentService
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

      invoices = eligible_invoices.where(id: @invoice_ids).to_a
      return failure("Una o más facturas no son válidas para tu agencia.") unless invoices.size == @invoice_ids.size

      evidence = nil
      ActiveRecord::Base.transaction do
        evidence = InvoicePaymentEvidence.new(
          invoice: invoices.first,
          customs_agent: @actor.entity,
          submitted_by: @actor,
          reference: @reference,
          tracking_key: @tracking_key.presence,
          status: "pending"
        )
        evidence.receipt_file.attach(@receipt_file)
        evidence.save!

        invoices.each do |invoice|
          evidence.invoice_payment_evidence_links.create!(invoice: invoice)
        end
      end

      Result.new(success?: true, evidence: evidence)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    private

    def eligible_invoices
      Invoice.joins(:receiver_entity)
        .left_joins(:invoice_payments)
        .where(entities: { customs_agent_id: @actor.entity_id })
        .where(kind: "ingreso")
        .where(status: ELIGIBLE_STATUSES)
        .group("invoices.id")
        .having("COALESCE(SUM(invoice_payments.amount), 0) < invoices.total")
        .order(created_at: :desc)
        .includes(:invoice_payments)
    end

    def failure(message)
      Result.new(success?: false, error_message: message)
    end
  end
end
