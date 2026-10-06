class CustomsAgentPaymentEvidencesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_customs_agent!

  def new
    @agency_invoices_for_payment_evidence = eligible_invoices.preload(:receiver_entity, :invoice_payments).limit(100)
    @selected_invoice_id = params[:invoice_id].presence
    @payment_evidence = InvoicePaymentEvidence.new(invoice_id: @selected_invoice_id)
    @selected_invoice_ids = selected_invoice_ids

    if @selected_invoice_ids.any?
      @selected_agency_invoices = eligible_invoices.where(id: @selected_invoice_ids).preload(:invoice_payments).limit(500).to_a
      missing_invoice_ids = @selected_invoice_ids.map(&:to_i) - @selected_agency_invoices.map(&:id)
      @payment_evidence.errors.add(:base, "Una o más facturas no son válidas para tu agencia.") if missing_invoice_ids.any?
    end

    return unless turbo_frame_request?

    render partial: "customs_agent_payment_evidences/modal"
  end

  def create
    return create_for_multiple_invoices if payment_evidence_params[:invoice_ids].present?

    invoice = eligible_invoices.find_by(id: payment_evidence_params[:invoice_id])
    unless invoice
      if turbo_frame_request?
        @agency_invoices_for_payment_evidence = eligible_invoices.preload(:receiver_entity, :invoice_payments).limit(100)
        @selected_invoice_id = payment_evidence_params[:invoice_id]
        @payment_evidence = InvoicePaymentEvidence.new(invoice_id: @selected_invoice_id)
        @payment_evidence.errors.add(:invoice_id, "no es valida para tu agencia")
        return render partial: "customs_agent_payment_evidences/modal", status: :unprocessable_content
      end

      redirect_to new_customs_agents_payment_evidence_path, alert: "Factura no valida para tu agencia." and return
    end

    @payment_evidence = InvoicePaymentEvidence.new(
      invoice: invoice,
      customs_agent: current_user.entity,
      submitted_by: current_user,
      reference: payment_evidence_params[:reference],
      tracking_key: payment_evidence_params[:tracking_key]
    )

    @payment_evidence.receipt_file.attach(payment_evidence_params[:receipt_file]) if payment_evidence_params[:receipt_file].present?

    if @payment_evidence.save
      if turbo_frame_request?
        return render partial: "customs_agent_payment_evidences/success"
      end

      redirect_to new_customs_agents_payment_evidence_path, notice: "Tu comprobante de pago ha sido enviado y sera revisado para su validacion."
    else
      if turbo_frame_request?
        @agency_invoices_for_payment_evidence = eligible_invoices.preload(:receiver_entity, :invoice_payments).limit(100)
        @selected_invoice_id = payment_evidence_params[:invoice_id]
        return render partial: "customs_agent_payment_evidences/modal", status: :unprocessable_content
      end

      redirect_to new_customs_agents_payment_evidence_path, alert: @payment_evidence.errors.full_messages.to_sentence
    end
  end

  private

  def ensure_customs_agent!
    return if current_user.customs_broker? && current_user.entity&.role_customs_agent?

    redirect_to containers_path, alert: "No tienes permisos para acceder a esta seccion"
  end

  def payment_evidence_params
    params.require(:payment_evidence).permit(:invoice_id, :reference, :tracking_key, :receipt_file, invoice_ids: [])
  end

  def selected_invoice_ids
    ids = payment_evidence_params[:invoice_ids] if params[:payment_evidence].present?
    ids ||= params[:invoice_ids]
    Array(ids).map(&:to_s).map(&:strip).reject(&:blank?).uniq
  end

  def create_for_multiple_invoices
    result = PaymentEvidences::CreateForCustomsAgentService.call(
      actor: current_user,
      invoice_ids: payment_evidence_params[:invoice_ids],
      reference: payment_evidence_params[:reference],
      tracking_key: payment_evidence_params[:tracking_key],
      receipt_file: payment_evidence_params[:receipt_file]
    )

    if result.success?
      return render partial: "customs_agent_payment_evidences/success" if turbo_frame_request?

      redirect_to invoices_path, notice: "Tu comprobante de pago ha sido enviado y sera revisado para su validacion."
      return
    end

    @selected_invoice_ids = selected_invoice_ids
    @selected_agency_invoices = eligible_invoices.where(id: @selected_invoice_ids).preload(:invoice_payments).limit(500).to_a
    @payment_evidence = InvoicePaymentEvidence.new(reference: payment_evidence_params[:reference], tracking_key: payment_evidence_params[:tracking_key])
    @payment_evidence.errors.add(:base, result.error_message)

    if turbo_frame_request?
      render partial: "customs_agent_payment_evidences/modal", status: :unprocessable_content
    else
      redirect_to invoices_path, alert: result.error_message
    end
  end

  def eligible_invoices
    Invoice.joins(:receiver_entity)
      .left_joins(:invoice_payments)
      .where(entities: { customs_agent_id: current_user.entity_id })
      .where(kind: "ingreso")
      .where(status: %w[issued cancel_pending])
      .group("invoices.id")
      .having("COALESCE(SUM(invoice_payments.amount), 0) < invoices.total")
      .order(created_at: :desc)
  end
end
