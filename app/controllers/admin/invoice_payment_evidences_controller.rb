module Admin
  class InvoicePaymentEvidencesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_evidence, only: [ :show, :reject, :register_payment ]
    after_action :verify_authorized

    def index
      authorize InvoicePaymentEvidence

      @status_filter = params[:status].to_s.presence
      @start_date, @end_date = resolve_date_filters
      @invoice_payment_evidences = policy_scope(InvoicePaymentEvidence)
        .includes(:customs_agent, :invoice)
        .where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
        .order(created_at: :desc)
      @invoice_payment_evidences = @invoice_payment_evidences.where(status: @status_filter) if @status_filter.in?(InvoicePaymentEvidence::STATUSES)
      @invoice_payment_evidences = @invoice_payment_evidences.page(params[:page]).per(params[:per] || 10)
    end

    def show
      authorize @evidence

      @evidence_invoices = @evidence.invoices_for_review
      preload_evidence_invoices_associations!(@evidence_invoices)
      @invoice = selected_invoice_for_registration
      @invoice_payments = @invoice.present? ? @invoice.invoice_payments.recent_first : InvoicePayment.none
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

      grouped_amounts = register_payment_params[:invoice_amounts].to_h
      if grouped_amounts.values.any? { |value| value.to_d.positive? }
        grouped_invoice_count = grouped_amounts.values.count { |value| value.to_d.positive? }
        grouped_result = Facturador::RegisterGroupedInvoicePaymentsService.call(
          evidence: @evidence,
          invoice_amounts: grouped_amounts,
          paid_at: register_payment_params[:paid_at],
          payment_method: register_payment_params[:payment_method],
          reference: register_payment_params[:reference].presence || @evidence.reference,
          tracking_key: register_payment_params[:tracking_key].presence || @evidence.tracking_key,
          notes: register_payment_params[:notes],
          actor: current_user
        )

        review_note = [
          register_payment_params[:review_comment].presence,
          "Pagos registrados desde evidencia ##{@evidence.id} para #{grouped_invoice_count} facturas."
        ].compact.join(" ")

        @evidence.update!(
          invoice_payment: grouped_result.payments.first,
          status: "linked",
          review_comment: review_note.presence
        )

        redirect_to admin_invoice_payment_evidence_path(@evidence), notice: "Pagos registrados y REP agrupado en proceso de emisión."
        return
      end

      target_invoice = selected_invoice_for_registration_from_params
      unless target_invoice
        redirect_to admin_invoice_payment_evidence_path(@evidence), alert: "Selecciona una factura válida para registrar el pago." and return
      end

      payment = Facturador::RegisterInvoicePaymentService.call(
        invoice: target_invoice,
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
        "Pago registrado desde evidencia ##{@evidence.id} para factura ##{target_invoice.id}."
      ].compact.join(" ")

      @evidence.update!(
        invoice_payment: payment,
        status: "linked",
        review_comment: review_note.presence
      )

      redirect_to invoice_invoice_payment_path(target_invoice, payment), notice: "Pago registrado y evidencia vinculada correctamente."
    rescue Facturador::Error, ActiveRecord::RecordInvalid => e
      redirect_to admin_invoice_payment_evidence_path(@evidence), alert: "No fue posible registrar el pago desde la evidencia: #{e.message}"
    end

    private

    def set_evidence
      evidence_scope = InvoicePaymentEvidence.includes(:invoices)

      if action_name == "show" && params[:invoice_id].present?
        evidence_scope = evidence_scope.includes(invoices: :receiver_entity)
      end

      @evidence = evidence_scope.find(params[:id])
    end

    def register_payment_params
      params.require(:register_payment).permit(:invoice_id, :amount, :paid_at, :payment_method, :reference, :tracking_key, :notes, :review_comment, invoice_amounts: {})
    end

    def selected_invoice_for_registration
      @evidence.invoice_for_admin_registration(params[:invoice_id])
    end

    def selected_invoice_for_registration_from_params
      @evidence.invoice_for_admin_registration(register_payment_params[:invoice_id])
    end

    def resolve_date_filters
      today = Time.zone.today
      default_start = today - 1.week

      start_date = parse_date_param(params[:start_date]) || default_start
      end_date = parse_date_param(params[:end_date]) || today

      if start_date > end_date
        start_date, end_date = end_date, start_date
      end

      [ start_date, end_date ]
    end

    def parse_date_param(value)
      return nil if value.blank?

      Date.iso8601(value)
    rescue ArgumentError
      nil
    end

    def notify_customs_agency_of_rejection(evidence, comment)
      recipients = User.joins(:role)
        .where(entity_id: evidence.customs_agent_id)
        .where(roles: { name: [ Role::CUSTOMS_BROKER, Role::CONSOLIDATOR ] })

      evidence_invoice_ids = evidence.invoices_for_review.map(&:id)
      rejected_invoices_text = if evidence_invoice_ids.size <= 1
        "la factura ##{evidence_invoice_ids.first || evidence.invoice_id}"
      else
        "las facturas ##{evidence_invoice_ids.join(', #')}"
      end

      action_text = [
        "rechazo evidencia de pago de #{rejected_invoices_text}",
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

    def preload_evidence_invoices_associations!(invoices)
      return if invoices.blank?

      ActiveRecord::Associations::Preloader.new(records: invoices, associations: :receiver_entity).call

      # RFC from receiver_entity.fiscal_profile is rendered only in grouped PPD mode.
      grouped_ppd_mode = invoices.many? && invoices.all? { |invoice| invoice.payment_method_code == FiscalProfile::METODO_PAGO_PPD }
      return unless grouped_ppd_mode

      receiver_entities = invoices.map(&:receiver_entity).compact
      return if receiver_entities.empty?

      ActiveRecord::Associations::Preloader.new(records: receiver_entities, associations: :fiscal_profile).call
    end
  end
end
