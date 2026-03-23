class ConsolidatorPaymentEvidencesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_consolidator!

  def new
    @selected_invoice_ids = selected_invoice_ids
    @eligible_invoices = eligible_invoices.where(id: @selected_invoice_ids).limit(200)
    @payment_evidence = InvoicePaymentEvidence.new
    missing_invoice_ids = @selected_invoice_ids.map(&:to_i) - @eligible_invoices.pluck(:id)

    if @selected_invoice_ids.blank?
      @payment_evidence.errors.add(:base, "Selecciona al menos una factura.")
    elsif missing_invoice_ids.any?
      @payment_evidence.errors.add(:base, "Una o más facturas no son válidas para tu cuenta.")
    end

    return unless turbo_frame_request?

    render partial: "consolidator_payment_evidences/modal"
  end

  def create
    result = PaymentEvidences::CreateForConsolidatorService.call(
      actor: current_user,
      invoice_ids: payment_evidence_params[:invoice_ids],
      reference: payment_evidence_params[:reference],
      tracking_key: payment_evidence_params[:tracking_key],
      receipt_file: payment_evidence_params[:receipt_file]
    )

    if result.success?
      if turbo_frame_request?
        return render partial: "consolidator_payment_evidences/success"
      end

      redirect_to invoices_path, notice: "Comprobante enviado para revisión del ejecutivo."
      return
    end

    @selected_invoice_ids = selected_invoice_ids_from_params
    @eligible_invoices = eligible_invoices.where(id: @selected_invoice_ids).limit(200)
    @payment_evidence = InvoicePaymentEvidence.new(
      reference: payment_evidence_params[:reference],
      tracking_key: payment_evidence_params[:tracking_key]
    )
    @payment_evidence.errors.add(:base, result.error_message)

    if turbo_frame_request?
      render partial: "consolidator_payment_evidences/modal", status: :unprocessable_content
    else
      redirect_to invoices_path, alert: result.error_message
    end
  end

  private

  def ensure_consolidator!
    return if current_user.consolidator? && current_user.entity&.role_consolidator?

    redirect_to containers_path, alert: "No tienes permisos para acceder a esta sección"
  end

  def payment_evidence_params
    params.require(:payment_evidence).permit(:reference, :tracking_key, :receipt_file, invoice_ids: [])
  end

  def selected_invoice_ids
    Array(params[:invoice_ids]).map(&:to_s).map(&:strip).reject(&:blank?).uniq
  end

  def selected_invoice_ids_from_params
    Array(payment_evidence_params[:invoice_ids]).map(&:to_s).map(&:strip).reject(&:blank?).uniq
  end

  def eligible_invoices
    Invoice
      .left_joins(:invoice_payments)
      .where(receiver_entity_id: current_user.entity_id)
      .where(status: %w[issued cancel_pending])
      .group("invoices.id")
      .having("COALESCE(SUM(invoice_payments.amount), 0) < invoices.total")
      .order(created_at: :desc)
      .includes(:receiver_entity, :invoice_payments)
  end
end
