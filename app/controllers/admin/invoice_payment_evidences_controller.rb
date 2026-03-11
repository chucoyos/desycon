module Admin
  class InvoicePaymentEvidencesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_evidence, only: [ :show, :reject, :register_payment ]
    after_action :verify_authorized

    def index
      authorize InvoicePaymentEvidence

      @status_filter = params[:status].to_s.presence
      @invoice_payment_evidences = policy_scope(InvoicePaymentEvidence)
        .includes(:invoice, :customs_agent)
        .order(created_at: :desc)
      @invoice_payment_evidences = @invoice_payment_evidences.where(status: @status_filter) if @status_filter.in?(InvoicePaymentEvidence::STATUSES)
      @invoice_payment_evidences = @invoice_payment_evidences.page(params[:page]).per(params[:per] || 25)
    end

    def show
      authorize @evidence

      @invoice = @evidence.invoice
      @invoice_payments = @invoice.invoice_payments.recent_first
      @payment_method_options = FiscalProfile::FORMAS_PAGO.map { |code, label| [ "#{code} - #{label}", code ] }
    end

    def reject
      authorize @evidence

      comment = params[:review_comment].to_s.strip
      if comment.blank?
        redirect_to admin_invoice_payment_evidence_path(@evidence), alert: "Debes agregar un comentario de rechazo." and return
      end

      @evidence.update!(status: "rejected", review_comment: comment)
      notify_customs_agency_of_rejection(@evidence, comment)
      redirect_to admin_invoice_payment_evidence_path(@evidence), notice: "Evidencia rechazada."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_invoice_payment_evidence_path(@evidence), alert: e.record.errors.full_messages.to_sentence
    end

    def register_payment
      authorize @evidence

      payment = Facturador::RegisterInvoicePaymentService.call(
        invoice: @evidence.invoice,
        amount: register_payment_params[:amount],
        paid_at: register_payment_params[:paid_at],
        payment_method: register_payment_params[:payment_method],
        reference: register_payment_params[:reference].presence || @evidence.reference,
        tracking_key: register_payment_params[:tracking_key].presence || @evidence.tracking_key,
        notes: register_payment_params[:notes],
        actor: current_user
      )

      review_note = [
        register_payment_params[:review_comment].presence,
        "Pago registrado desde evidencia ##{@evidence.id}."
      ].compact.join(" ")

      @evidence.update!(
        invoice_payment: payment,
        status: "linked",
        review_comment: review_note.presence
      )

      redirect_to invoice_invoice_payment_path(@evidence.invoice, payment), notice: "Pago registrado y evidencia vinculada correctamente."
    rescue Facturador::Error, ActiveRecord::RecordInvalid => e
      redirect_to admin_invoice_payment_evidence_path(@evidence), alert: "No fue posible registrar el pago desde la evidencia: #{e.message}"
    end

    private

    def set_evidence
      @evidence = InvoicePaymentEvidence.find(params[:id])
    end

    def register_payment_params
      params.require(:register_payment).permit(:amount, :paid_at, :payment_method, :reference, :tracking_key, :notes, :review_comment)
    end

    def notify_customs_agency_of_rejection(evidence, comment)
      recipients = User.joins(:role)
        .where(entity_id: evidence.customs_agent_id)
        .where(roles: { name: Role::CUSTOMS_BROKER })

      action_text = [
        "rechazo evidencia de pago de la factura ##{evidence.invoice_id}",
        "Referencia: #{evidence.reference}",
        ("Clave rastreo: #{evidence.tracking_key}" if evidence.tracking_key.present?),
        "Motivo: #{comment}"
      ].compact.join(" | ")

      recipients.find_each do |recipient|
        Notification.create!(
          recipient: recipient,
          actor: current_user,
          action: action_text,
          notifiable: evidence
        )
      end
    end
  end
end
