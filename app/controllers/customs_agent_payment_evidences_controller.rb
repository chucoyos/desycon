class CustomsAgentPaymentEvidencesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_customs_agent!

  def create
    invoice = eligible_invoices.find_by(id: payment_evidence_params[:invoice_id])
    unless invoice
      redirect_to customs_agents_dashboard_path, alert: "Factura no valida para tu agencia." and return
    end

    evidence = InvoicePaymentEvidence.new(
      invoice: invoice,
      customs_agent: current_user.entity,
      submitted_by: current_user,
      reference: payment_evidence_params[:reference],
      tracking_key: payment_evidence_params[:tracking_key]
    )

    evidence.receipt_file.attach(payment_evidence_params[:receipt_file]) if payment_evidence_params[:receipt_file].present?

    if evidence.save
      redirect_to customs_agents_dashboard_path, notice: "Comprobante enviado para revision del ejecutivo."
    else
      redirect_to customs_agents_dashboard_path, alert: evidence.errors.full_messages.to_sentence
    end
  end

  private

  def ensure_customs_agent!
    return if current_user.customs_broker? && current_user.entity&.role_customs_agent?

    redirect_to containers_path, alert: "No tienes permisos para acceder a esta seccion"
  end

  def payment_evidence_params
    params.require(:payment_evidence).permit(:invoice_id, :reference, :tracking_key, :receipt_file)
  end

  def eligible_invoices
    Invoice.joins(:receiver_entity)
      .where(entities: { customs_agent_id: current_user.entity_id })
      .where(status: %w[issued cancel_pending])
      .order(created_at: :desc)
  end
end
