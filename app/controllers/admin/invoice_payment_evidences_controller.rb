module Admin
  class InvoicePaymentEvidencesController < ApplicationController
    require "caxlsx"

    DATE_FILTER_TYPES = %w[created_at paid_at].freeze

    before_action :authenticate_user!
    before_action :set_evidence, only: [ :show, :reject, :register_payment ]
    after_action :verify_authorized

    def index
      authorize InvoicePaymentEvidence

      @status_filter = params[:status].to_s.presence
      @start_date, @end_date = resolve_date_filters
      @date_filter_type = resolve_date_filter_type

      evidences_scope = policy_scope(InvoicePaymentEvidence)
        .includes(:customs_agent, :invoice)

      @invoice_payment_evidences = apply_date_filter(
        scope: evidences_scope,
        start_date: @start_date,
        end_date: @end_date,
        date_filter_type: @date_filter_type
      )
      @invoice_payment_evidences = @invoice_payment_evidences.where(status: @status_filter) if @status_filter.in?(InvoicePaymentEvidence::STATUSES)
      @invoice_payment_evidences = @invoice_payment_evidences.order(created_at: :desc)

      if params[:format].to_s == "xlsx" || request.format.xlsx?
        timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
        preload_payments_application_report_associations!(@invoice_payment_evidences)
        rows = build_payments_application_report_rows(@invoice_payment_evidences)

        send_data(
          build_payments_application_report_xlsx(rows),
          filename: "reporte_aplicacion_pagos_#{timestamp}.xlsx",
          type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
          disposition: "attachment"
        )
        return
      end

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

    def resolve_date_filter_type
      date_filter_type = params[:date_filter_type].to_s
      return date_filter_type if DATE_FILTER_TYPES.include?(date_filter_type)

      "created_at"
    end

    def apply_date_filter(scope:, start_date:, end_date:, date_filter_type:)
      range = start_date.beginning_of_day..end_date.end_of_day

      case date_filter_type
      when "paid_at"
        scope.joins(:invoice_payment).where(invoice_payments: { paid_at: range })
      else
        scope.where(created_at: range)
      end
    end

    def build_payments_application_report_rows(evidences)
      evidences.map do |evidence|
        linked_invoices = evidence.invoices_for_review
        receiver_names = linked_invoices.map { |invoice| invoice.receiver_entity&.name.to_s.strip.presence }.compact.uniq

        {
          invoice_label: linked_invoices.map { |invoice| invoice_label_for_report(invoice) }.uniq.join(" | ").presence || "-",
          paid_at: evidence.invoice_payment&.paid_at,
          amount: evidence.invoice_payment&.amount,
          tracking_key: evidence.invoice_payment&.tracking_key.to_s.strip.presence || evidence.tracking_key,
          customs_agent_name: evidence.customs_agent&.name.to_s.strip.presence || "-",
          receiver_name: receiver_names.join(" | ").presence || "-"
        }
      end
    end

    def preload_payments_application_report_associations!(evidences)
      evidence_records = evidences.is_a?(ActiveRecord::Relation) ? evidences.to_a : Array(evidences)
      return if evidence_records.empty?

      ActiveRecord::Associations::Preloader.new(records: evidence_records, associations: :invoice_payment).call
      ActiveRecord::Associations::Preloader.new(records: evidence_records, associations: :invoices).call

      linked_invoices = evidence_records.flat_map(&:invoices_for_review).compact.uniq
      return if linked_invoices.empty?

      ActiveRecord::Associations::Preloader.new(records: linked_invoices, associations: :receiver_entity).call
    end

    def invoice_label_for_report(invoice)
      return "-" unless invoice

      serie = invoice.provider_response.to_h["serie"].presence || invoice.payload_snapshot.to_h["serie"].presence
      folio = invoice.provider_response.to_h["folio"].presence ||
              invoice.provider_response.to_h["noComprobante"].presence ||
              invoice.provider_response.to_h["numeroComprobante"].presence ||
              invoice.facturador_comprobante_id&.to_s

      return "#{serie} #{folio}" if serie.present? && folio.present?
      return folio.to_s if folio.present?
      return serie.to_s if serie.present?

      "-"
    end

    def build_payments_application_report_xlsx(rows)
      package = Axlsx::Package.new
      workbook = package.workbook
      styles = workbook.styles
      header_style = styles.add_style(b: true, bg_color: "F59E0B", fg_color: "FFFFFF", alignment: { horizontal: :center })
      date_style = styles.add_style(format_code: "yyyy-mm-dd")
      amount_style = styles.add_style(format_code: "#,##0.00")

      workbook.add_worksheet(name: "Aplicacion de pagos") do |sheet|
        sheet.add_row(
          [ "Factura", "Fecha de Pago", "Monto", "Clave Rastreo", "Agencia Aduanal", "Receptor" ],
          style: header_style
        )

        rows.each do |row|
          sheet.add_row(
            [
              row[:invoice_label],
              row[:paid_at]&.to_date,
              row[:amount]&.to_d&.to_f,
              row[:tracking_key].to_s,
              row[:customs_agent_name],
              row[:receiver_name]
            ],
            style: [ nil, date_style, amount_style, nil, nil, nil ],
            types: [ :string, :date, :float, :string, :string, :string ]
          )
        end
      end

      package.to_stream.read
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
