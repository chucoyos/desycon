class InvoicesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_invoice, only: %i[show retry_issue cancel sync_documents sync_files register_payment send_email destroy]
  before_action :load_manual_invoice_options, only: %i[new create]
  after_action :verify_authorized

  def index
    authorize Invoice

    admin_or_executive = current_user.admin_or_executive?

    @selected_start_date = resolved_start_date
    @selected_end_date = resolved_end_date
    @selected_status = params[:status].to_s.presence
    @selected_kind = params[:kind].to_s.presence
    @selected_payment_status = params[:payment_status].to_s.presence
    @selected_client_id = params[:client_id].to_s.presence
    @selected_customs_agent_id = admin_or_executive ? params[:customs_agent_id].to_s.presence : nil
    @selected_consolidator_id = admin_or_executive ? params[:consolidator_id].to_s.presence : nil
    @selected_container_number = params[:container_number].to_s.strip.first(11).presence
    @selected_blhouse = params[:blhouse].to_s.strip.presence
    @selected_serie = params[:serie].to_s.strip.presence
    @selected_folio = params[:folio].to_s.strip.presence
    @selected_uuid = params[:uuid].to_s.strip.presence

    start_date = [ @selected_start_date, @selected_end_date ].min
    end_date = [ @selected_start_date, @selected_end_date ].max
    paid_total_sql = "COALESCE((SELECT SUM(invoice_payments.amount) FROM invoice_payments WHERE invoice_payments.invoice_id = invoices.id), 0)"

    scoped_invoices = policy_scope(Invoice)
    @invoices = scoped_invoices
          .includes(:receiver_entity)
          .select("invoices.*", "#{paid_total_sql} AS paid_total_for_index")
                .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
                .order(created_at: :desc)

    @invoices = @invoices.where(status: @selected_status) if @selected_status.present? && Invoice::STATUSES.include?(@selected_status)
    @invoices = @invoices.where(kind: @selected_kind) if @selected_kind.present? && Invoice::KINDS.include?(@selected_kind)
    @invoices = @invoices.with_payment_status(@selected_payment_status) if @selected_payment_status.present? && Invoice::PAYMENT_STATUSES.include?(@selected_payment_status)
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
    if @selected_container_number.present?
      @invoices = @invoices.where(
        <<~SQL,
          (
            invoices.invoiceable_type = 'ContainerService' AND EXISTS (
              SELECT 1
              FROM container_services
              INNER JOIN containers ON containers.id = container_services.container_id
              WHERE container_services.id = invoices.invoiceable_id
                AND containers.number ILIKE :container_number
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
                AND containers.number ILIKE :container_number
            )
          )
        SQL
        container_number: "%#{@selected_container_number}%"
      )
    end
    if @selected_blhouse.present?
      @invoices = @invoices.where(
        <<~SQL,
          invoices.invoiceable_type = 'BlHouseLineService' AND EXISTS (
            SELECT 1
            FROM bl_house_line_services
            INNER JOIN bl_house_lines ON bl_house_lines.id = bl_house_line_services.bl_house_line_id
            WHERE bl_house_line_services.id = invoices.invoiceable_id
              AND bl_house_lines.blhouse ILIKE :blhouse
          )
        SQL
        blhouse: "%#{@selected_blhouse}%"
      )
    end
    if @selected_serie.present?
      @invoices = @invoices.where(
        "COALESCE(invoices.provider_response->>'serie', invoices.payload_snapshot->>'serie', invoices.payload_snapshot->>'serie_override', '') ILIKE ?",
        "%#{@selected_serie}%"
      )
    end
    if @selected_folio.present?
      @invoices = @invoices.where(
        "COALESCE(invoices.provider_response->>'folio', invoices.provider_response->>'noComprobante', invoices.provider_response->>'numeroComprobante', invoices.facturador_comprobante_id::text, '') ILIKE ?",
        "%#{@selected_folio}%"
      )
    end
    @invoices = @invoices.where("sat_uuid ILIKE ?", "%#{@selected_uuid}%") if @selected_uuid.present?

    @invoices = @invoices.page(params[:page]).per(params[:per] || 10)

    build_invoice_service_context_data(@invoices)

    @invoice_statuses = Invoice::STATUSES
    @payment_statuses = Invoice::PAYMENT_STATUSES
    related_client_ids = scoped_invoices.select(:receiver_entity_id)
    @clients = Entity.clients.where(id: related_client_ids).order(:name)
    @customs_agents = admin_or_executive ? Entity.customs_agents.order(:name) : Entity.customs_agents.where(id: current_user.entity_id)
    @consolidators = admin_or_executive ? Entity.consolidators.order(:name) : Entity.none
    @admin_or_executive = admin_or_executive
    @consolidator_portal_user = current_user.consolidator? && current_user.entity&.role_consolidator?
    @series_filter_options = build_series_filter_options
  end

  def receivers_search
    authorize Invoice, :index?

    query = params[:q].to_s.strip
    min_chars = 2
    limit = 20

    if query.length < min_chars
      return render json: { results: [], meta: { query:, min_chars:, limit:, count: 0 } }
    end

    scoped_invoice_receivers = policy_scope(Invoice).select(:receiver_entity_id)
    scoped_clients = Entity.clients.where(id: scoped_invoice_receivers)

    cache_key = [
      "invoices",
      "receivers_search",
      current_user.id,
      current_user.entity_id,
      query.downcase,
      limit
    ].join(":")

    results = Rails.cache.fetch(cache_key, expires_in: 60.seconds) do
      scoped_clients
        .search_by_name(query)
        .limit(limit)
        .pluck(:id, :name)
        .map do |id, name|
          {
            id:,
            label: name
          }
        end
    end

    render json: { results:, meta: { query:, min_chars:, limit:, count: results.size } }
  end

  def customs_agents_search
    authorize Invoice, :index?

    unless current_user.admin_or_executive?
      return render json: { results: [], meta: { query: params[:q].to_s.strip, min_chars: 2, limit: 20, count: 0 } }, status: :forbidden
    end

    query = params[:q].to_s.strip
    min_chars = 2
    limit = 20

    if query.length < min_chars
      return render json: { results: [], meta: { query:, min_chars:, limit:, count: 0 } }
    end

    cache_key = [
      "invoices",
      "customs_agents_search",
      current_user.id,
      query.downcase,
      limit
    ].join(":")

    results = Rails.cache.fetch(cache_key, expires_in: 60.seconds) do
      Entity
        .customs_agents
        .search_by_name(query)
        .limit(limit)
        .pluck(:id, :name)
        .map do |id, name|
          {
            id:,
            label: name
          }
        end
    end

    render json: { results:, meta: { query:, min_chars:, limit:, count: results.size } }
  end

  def consolidators_search
    authorize Invoice, :index?

    unless current_user.admin_or_executive?
      return render json: { results: [], meta: { query: params[:q].to_s.strip, min_chars: 2, limit: 20, count: 0 } }, status: :forbidden
    end

    query = params[:q].to_s.strip
    min_chars = 2
    limit = 20

    if query.length < min_chars
      return render json: { results: [], meta: { query:, min_chars:, limit:, count: 0 } }
    end

    cache_key = [
      "invoices",
      "consolidators_search",
      current_user.id,
      query.downcase,
      limit
    ].join(":")

    results = Rails.cache.fetch(cache_key, expires_in: 60.seconds) do
      Entity
        .consolidators
        .search_by_name(query)
        .limit(limit)
        .pluck(:id, :name)
        .map do |id, name|
          {
            id:,
            label: name
          }
        end
    end

    render json: { results:, meta: { query:, min_chars:, limit:, count: results.size } }
  end

  def show
    authorize @invoice

    @invoice_events = @invoice.invoice_events.includes(:created_by).order(created_at: :desc).limit(30)
    @invoice_payments = @invoice.invoice_payments.includes(complement_invoice: [ :xml_file_attachment, :pdf_file_attachment ]).order(paid_at: :desc)
    build_invoice_show_context_data(@invoice)
  end

  def new
    authorize Invoice, :new?

    @selected_receiver_kind = params[:receiver_kind].to_s.presence || "client"
    @manual_form_values = {
      "receiver_kind" => @selected_receiver_kind,
      "customs_agent_id" => "",
      "receiver_entity_id" => "",
      "serie" => ""
    }
    @manual_line_items_prefill = []
  end

  def create
    authorize Invoice, :create?

    result = Facturador::CreateManualInvoiceService.call(
      actor: current_user,
      receiver_entity_id: manual_invoice_params[:receiver_entity_id],
      customs_agent_id: manual_invoice_params[:customs_agent_id],
      serie: manual_invoice_params[:serie],
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
      redirect_to invoice_path(invoice), notice: "Emisión manual encolada/ejecutada correctamente."
    else
      redirect_back fallback_location: containers_path, alert: "No fue posible encolar la emisión manual. Revisa configuración y perfiles fiscales."
    end
  rescue Facturador::Error => e
    redirect_back fallback_location: containers_path, alert: "Error al emitir CFDI: #{e.message}"
  end

  def issue_manual_batch
    authorize Invoice, :issue_manual?

    serviceables = find_invoiceables_batch
    if serviceables.blank?
      return redirect_back fallback_location: containers_path, alert: "Selecciona al menos un servicio válido."
    end

    result = Facturador::IssueGroupedServicesService.call(serviceables: serviceables, actor: current_user)

    if result.success?
      if result.invoice.present?
        redirect_to invoice_path(result.invoice), notice: "Emisión agrupada encolada/ejecutada correctamente."
      else
        redirect_back fallback_location: containers_path, notice: "Emisión agrupada encolada/ejecutada correctamente."
      end
    else
      redirect_back fallback_location: containers_path, alert: "No fue posible emitir CFDI agrupado: #{result.error_message}"
    end
  rescue Facturador::Error => e
    redirect_back fallback_location: containers_path, alert: "Error al emitir CFDI agrupado: #{e.message}"
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

    if @invoice.status.in?([ "issued", "cancel_pending" ])
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

  def sync_files
    authorize @invoice, :sync_files?

    Facturador::SyncInvoiceDocumentsService.call(invoice: @invoice, actor: current_user)
    redirect_back fallback_location: invoice_path(@invoice), notice: "XML y PDF sincronizados correctamente."
  rescue Facturador::Error => e
    redirect_back fallback_location: invoice_path(@invoice), alert: "Error al sincronizar documentos: #{e.message}"
  end

  def register_payment
    authorize @invoice, :register_payment?

    payment = Facturador::RegisterInvoicePaymentService.call(
      invoice: @invoice,
      amount: payment_params[:amount],
      paid_at: payment_params[:paid_at],
      payment_method: payment_params[:payment_method],
      reference: payment_params[:reference],
      tracking_key: payment_params[:tracking_key],
      notes: payment_params[:notes],
      receipt_file: payment_params[:receipt_file],
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

  def destroy
    authorize @invoice, :destroy?

    own_payments_count = @invoice.invoice_payments.count
    linked_rep_payments_count = @invoice.kind == "pago" ? @invoice.payment_complements.count : 0

    if @invoice.kind == "pago"
      @invoice.payment_complements.update_all(complement_invoice_id: nil, status: "registered", updated_at: Time.current)
    end

    @invoice.destroy!

    notice = "Factura no timbrada eliminada correctamente"
    notice += " (#{own_payments_count} pago(s) relacionado(s) eliminado(s))" if own_payments_count.positive?
    if linked_rep_payments_count.positive?
      notice += " y #{linked_rep_payments_count} pago(s) quedaron listos para regenerar REP"
    end

    redirect_to destroy_return_location, notice: "#{notice}."
  rescue ActiveRecord::RecordNotDestroyed => e
    redirect_back fallback_location: invoices_path, alert: "No fue posible eliminar la factura: #{e.message}"
  end

  private

  def build_invoice_service_context_data(invoices)
    @invoice_hbl_by_id = {}
    @invoice_agency_by_id = {}

    rows = invoices.map { |invoice| [ invoice.id, invoice.invoiceable_type, invoice.invoiceable_id ] }
    bl_service_invoice_rows = rows.select { |_invoice_id, invoiceable_type, _invoiceable_id| invoiceable_type == "BlHouseLineService" }
    return if bl_service_invoice_rows.empty?

    bl_service_ids = bl_service_invoice_rows.map { |_invoice_id, _invoiceable_type, invoiceable_id| invoiceable_id }

    bl_service_data = BlHouseLineService
      .includes(bl_house_line: :customs_agent)
      .where(id: bl_service_ids)
      .index_by(&:id)

    bl_service_invoice_rows.each do |invoice_id, _invoiceable_type, invoiceable_id|
      service = bl_service_data[invoiceable_id]
      next unless service

      @invoice_hbl_by_id[invoice_id] = service.bl_house_line&.blhouse.presence || "-"
      @invoice_agency_by_id[invoice_id] = service.bl_house_line&.customs_agent&.name.presence || "-"
    end
  end

  def build_invoice_show_context_data(invoice)
    @invoice_hbl = nil
    @invoice_agency = invoice.customs_agent&.name.to_s.strip.presence

    return unless invoice.invoiceable_type == "BlHouseLineService"

    service = BlHouseLineService
      .includes(bl_house_line: :customs_agent)
      .find_by(id: invoice.invoiceable_id)

    return unless service

    @invoice_hbl = service.bl_house_line&.blhouse.to_s.strip.presence
    @invoice_agency = service.bl_house_line&.customs_agent&.name.to_s.strip.presence || @invoice_agency
  end

  def set_invoice
    @invoice = Invoice.includes(:xml_file_attachment, :pdf_file_attachment).find(params[:id])
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

  def find_invoiceables_batch
    type = params[:invoiceable_type].to_s
    ids = Array(params[:invoiceable_ids]).map(&:to_s).reject(&:blank?)
    return [] if type.blank? || ids.empty?

    model = case type
    when "ContainerService"
      ContainerService
    when "BlHouseLineService"
      BlHouseLineService
    else
      nil
    end
    return [] if model.nil?

    services = model.where(id: ids).to_a
    return [] unless services.size == ids.uniq.size

    services
  end

  def payment_params
    params.require(:payment).permit(:amount, :paid_at, :payment_method, :reference, :tracking_key, :notes, :receipt_file)
  end

  def manual_invoice_params
    params.require(:manual_invoice).permit(:receiver_kind, :receiver_entity_id, :customs_agent_id, :serie)
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
    @manual_series_options = build_manual_series_options
  end

  def build_manual_series_options
    [ [ "Automática", "" ] ] + series_for_current_environment.map { |serie| [ serie, serie ] }
  end

  def build_series_filter_options
    [ [ "Todas", "" ] ] + series_for_current_environment.map { |serie| [ serie, serie ] }
  end

  def series_for_current_environment
    environment = Facturador::Config.environment.to_s.downcase
    mapped_series = if environment == "sandbox"
      [ "MZ", "A", "B", "C" ]
    else
      [ "GMZO", "GLZC", "GVRZ", "GATM" ]
    end

    global_serie = Facturador::Config.serie.to_s.strip
    series = mapped_series.dup
    series << global_serie if global_serie.present?

    series.uniq
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
    Date.current - 1.week
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

  def destroy_return_location
    return_to = params[:return_to].to_s
    return invoices_path unless return_to.start_with?("/")

    return_to
  end
end
