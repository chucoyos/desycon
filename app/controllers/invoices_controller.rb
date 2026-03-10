class InvoicesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_invoice, only: %i[show retry_issue cancel sync_documents register_payment send_email]
  before_action :load_manual_invoice_options, only: %i[new create]
  after_action :verify_authorized

  def index
    authorize Invoice

    @selected_start_date = resolved_start_date
    @selected_end_date = resolved_end_date
    @selected_status = params[:status].to_s.presence
    @selected_client_id = params[:client_id].to_s.presence
    @selected_customs_agent_id = params[:customs_agent_id].to_s.presence
    @selected_consolidator_id = params[:consolidator_id].to_s.presence
    @selected_uuid = params[:uuid].to_s.strip.presence

    start_date = [ @selected_start_date, @selected_end_date ].min
    end_date = [ @selected_start_date, @selected_end_date ].max

    @invoices = policy_scope(Invoice)
                .includes(:receiver_entity)
                .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
                .order(created_at: :desc)

    @invoices = @invoices.where(status: @selected_status) if @selected_status.present? && Invoice::STATUSES.include?(@selected_status)
    @invoices = @invoices.where(receiver_entity_id: @selected_client_id) if @selected_client_id.present?
    if @selected_customs_agent_id.present?
      @invoices = @invoices.joins(:receiver_entity).where(entities: { customs_agent_id: @selected_customs_agent_id })
    end
    if @selected_consolidator_id.present?
      @invoices = @invoices.where(
        <<~SQL,
          (
            invoices.invoiceable_type = 'ContainerService' AND EXISTS (
              SELECT 1
              FROM container_services
              INNER JOIN containers ON containers.id = container_services.container_id
              WHERE container_services.id = invoices.invoiceable_id
                AND containers.consolidator_entity_id = :consolidator_id
            )
          )
          OR
          (
            invoices.invoiceable_type = 'BlHouseLineService' AND EXISTS (
              SELECT 1
              FROM bl_house_line_services
              INNER JOIN bl_house_lines ON bl_house_lines.id = bl_house_line_services.bl_house_line_id
              INNER JOIN containers ON containers.id = bl_house_lines.container_id
              WHERE bl_house_line_services.id = invoices.invoiceable_id
                AND containers.consolidator_entity_id = :consolidator_id
            )
          )
        SQL
        consolidator_id: @selected_consolidator_id
      )
    end
    @invoices = @invoices.where("sat_uuid ILIKE ?", "%#{@selected_uuid}%") if @selected_uuid.present?

    @invoices = @invoices.page(params[:page]).per(params[:per] || 25)

    @invoice_statuses = Invoice::STATUSES
    @clients = Entity.clients.order(:name)
    @customs_agents = Entity.customs_agents.order(:name)
    @consolidators = Entity.consolidators.order(:name)
  end

  def show
    authorize @invoice

    @invoice_events = @invoice.invoice_events.order(created_at: :desc).limit(30)
    @invoice_payments = @invoice.invoice_payments.includes(:complement_invoice).order(paid_at: :desc)
  end

  def new
    authorize Invoice, :new?

    @selected_receiver_kind = params[:receiver_kind].to_s.presence || "client"
    @manual_form_values = {
      "receiver_kind" => @selected_receiver_kind,
      "customs_agent_id" => "",
      "receiver_entity_id" => ""
    }
    @manual_line_items_prefill = []
  end

  def create
    authorize Invoice, :create?

    result = Facturador::CreateManualInvoiceService.call(
      actor: current_user,
      receiver_entity_id: manual_invoice_params[:receiver_entity_id],
      customs_agent_id: manual_invoice_params[:customs_agent_id],
      line_items_params: manual_line_items_params
    )

    if result.success?
      redirect_to invoice_path(result.invoice, from_manual_create: 1), notice: "CFDI manual creado y en proceso de emisión."
    else
      @selected_receiver_kind = manual_invoice_params[:receiver_kind].to_s.presence || "client"
      @manual_form_values = manual_invoice_params.to_h
      @manual_line_items_prefill = manual_line_items_params.map(&:to_h)
      flash.now[:alert] = result.error_message
      render :new, status: :unprocessable_content
    end
  end

  def issue_manual
    authorize Invoice, :issue_manual?

    invoiceable = find_invoiceable
    unless invoiceable
      return redirect_back fallback_location: containers_path, alert: "Servicio no encontrado."
    end

    invoice = Facturador::ManualIssueService.call(invoiceable: invoiceable, actor: current_user)

    if invoice.present?
      redirect_back fallback_location: containers_path, notice: "Emisión manual encolada/ejecutada correctamente."
    else
      redirect_back fallback_location: containers_path, alert: "No fue posible encolar la emisión manual. Revisa configuración y perfiles fiscales."
    end
  rescue Facturador::Error => e
    redirect_back fallback_location: containers_path, alert: "Error al emitir CFDI: #{e.message}"
  end

  def retry_issue
    authorize @invoice, :retry_issue?

    unless @invoice.failed? && @invoice.last_error_code.to_s.start_with?("FACTURADOR_ISSUE_")
      return redirect_back fallback_location: invoice_path(@invoice), alert: "La factura no está en un estado reintentable de emisión."
    end

    enqueued = @invoice.queue_issue!(actor: current_user)

    if enqueued
      redirect_back fallback_location: invoice_path(@invoice), notice: "Reintento de emisión CFDI encolado correctamente."
    else
      redirect_back fallback_location: invoice_path(@invoice), alert: "No fue posible encolar el reintento de emisión CFDI."
    end
  rescue Facturador::Error => e
    redirect_back fallback_location: invoice_path(@invoice), alert: "Error al reintentar emisión CFDI: #{e.message}"
  end

  def cancel
    authorize @invoice, :cancel?

    motive = "02"
    replacement_uuid = nil

    Facturador::CancelInvoiceService.validate_cancel_request!(
      invoice: @invoice,
      motive: motive,
      replacement_uuid: replacement_uuid
    )

    Facturador::CancelInvoiceJob.perform_later(
      invoice_id: @invoice.id,
      motive: motive,
      replacement_uuid: replacement_uuid,
      actor_id: current_user.id
    )

    redirect_back fallback_location: containers_path,
      notice: "Cancelación de CFDI en proceso. Te notificaremos cuando PAC/SAT confirme el resultado."
  rescue Facturador::Error => e
    redirect_back fallback_location: containers_path, alert: cancel_error_alert(e.message, exception_flow: true)
  end

  def sync_documents
    authorize @invoice, :sync_documents?

    if @invoice.issued?
      Facturador::ReconcileInvoicesService.call_for_invoice(invoice: @invoice, actor: current_user)
      @invoice.reload
    end

    Facturador::SyncInvoiceDocumentsService.call(invoice: @invoice, actor: current_user)
    notice_message = if @invoice.status == "cancelled"
      "XML/PDF sincronizados (factura cancelada)."
    else
      "XML y PDF sincronizados correctamente."
    end

    redirect_back fallback_location: containers_path, notice: notice_message
  rescue Facturador::Error => e
    redirect_back fallback_location: containers_path, alert: "Error al sincronizar documentos: #{e.message}"
  end

  def register_payment
    authorize @invoice, :register_payment?

    payment = Facturador::RegisterInvoicePaymentService.call(
      invoice: @invoice,
      amount: payment_params[:amount],
      paid_at: payment_params[:paid_at],
      payment_method: payment_params[:payment_method],
      reference: payment_params[:reference],
      notes: payment_params[:notes],
      actor: current_user
    )

    if payment.complement_invoice_id.present?
      redirect_back fallback_location: containers_path, notice: "Pago registrado y complemento de pago encolado."
    else
      redirect_back fallback_location: containers_path, notice: "Pago registrado correctamente."
    end
  rescue Facturador::Error, ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: containers_path, alert: payment_registration_error_alert(e)
  end

  def send_email
    authorize @invoice, :send_email?

    Facturador::SendInvoiceEmailService.call(invoice: @invoice, actor: current_user, trigger: "manual")
    redirect_back fallback_location: invoice_path(@invoice), notice: "CFDI enviado por correo exitosamente."
  rescue Facturador::Error => e
    message = if pac_temporarily_unavailable_message?(e.message.to_s)
      "No fue posible enviar el correo porque PAC no está disponible temporalmente. Reintenta en unos minutos."
    elsif email_feature_disabled_message?(e.message.to_s)
      "El envio de correo CFDI por PAC esta deshabilitado en la configuracion actual."
    else
      "Error al enviar CFDI por correo: #{e.message}"
    end
    redirect_back fallback_location: invoice_path(@invoice), alert: message
  end

  private

  def set_invoice
    @invoice = Invoice.find(params[:id])
  end

  def find_invoiceable
    type = params[:invoiceable_type].to_s
    id = params[:invoiceable_id]

    return nil if id.blank?

    case type
    when "ContainerService"
      ContainerService.find_by(id: id)
    when "BlHouseLineService"
      BlHouseLineService.find_by(id: id)
    else
      nil
    end
  end

  def payment_params
    params.require(:payment).permit(:amount, :paid_at, :payment_method, :reference, :notes)
  end

  def manual_invoice_params
    params.require(:manual_invoice).permit(:receiver_kind, :receiver_entity_id, :customs_agent_id)
  end

  def manual_line_items_params
    raw_line_items = params.dig(:manual_invoice, :line_items)

    normalized_items = case raw_line_items
    when ActionController::Parameters
      raw_line_items.values
    when Array
      raw_line_items
    else
      []
    end

    normalized_items.filter_map do |line|
      if line.is_a?(ActionController::Parameters)
        line_params = line
      elsif line.respond_to?(:to_h)
        line_params = ActionController::Parameters.new(line.to_h)
      else
        next
      end

      permitted = line_params.permit(:service_catalog_id, :description, :quantity, :unit_price)
      next if permitted.values.all?(&:blank?)

      permitted
    end
  end

  def load_manual_invoice_options
    @receiver_clients = Entity.clients.order(:name)
    @receiver_consolidators = Entity.consolidators.order(:name)
    @customs_agents_for_manual = Entity.customs_agents.order(:name)
    @service_catalogs_for_manual = ServiceCatalog.active.order(:name)
  end

  def resolved_start_date
    parse_filter_date(params[:start_date]) || default_start_date
  end

  def resolved_end_date
    parse_filter_date(params[:end_date]) || default_end_date
  end

  def parse_filter_date(value)
    return nil if value.blank?

    Date.iso8601(value)
  rescue ArgumentError
    nil
  end

  def default_start_date
    Date.current - 60.days
  end

  def default_end_date
    Date.current
  end

  def cancel_error_alert(message, exception_flow:)
    normalized = message.to_s.strip

    if pac_temporarily_unavailable_message?(normalized)
      return "No fue posible cancelar el CFDI porque PAC no está disponible temporalmente. Reintenta en unos minutos."
    end

    if exception_flow
      "Error al cancelar CFDI: #{normalized}"
    else
      "No se pudo cancelar el CFDI en este intento: #{normalized}"
    end
  end

  def payment_registration_error_alert(error)
    message = error.message.to_s

    return "No se puede registrar pago porque el CFDI no es elegible para REP." if message.match?(/Invoice is not eligible for payment registration/i)
    return "No se puede registrar pago: la factura fue emitida con metodo PUE; REP solo aplica para PPD." if message.match?(/REP solo aplica para PPD/i)
    return "No se puede registrar pago: la factura no tiene saldo pendiente." if message.match?(/no tiene saldo pendiente/i)
    return "No se puede registrar pago: no se permiten pagos sobre CFDI de tipo pago." if message.match?(/tipo pago/i)

    "Error al registrar pago: #{message}"
  end

  def pac_temporarily_unavailable_message?(message)
    message.match?(/HttpRequestException|An error occurred while sending the request|500:\s*An error has occurred/i)
  end

  def email_feature_disabled_message?(message)
    message.match?(/email sending via pac is disabled/i)
  end
end
