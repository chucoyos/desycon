require "caxlsx"
require "prawn"
require "prawn/table"

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
    @selected_service_catalog_id = params[:service_catalog_id].to_s.presence
    @selected_service_query = params[:service].to_s.strip.presence
    @selected_service = resolved_selected_service_label
    @selected_uuid = params[:uuid].to_s.strip.presence
    @applied_filters = build_applied_filters(admin_or_executive: admin_or_executive)

    start_date = [ @selected_start_date, @selected_end_date ].min
    end_date = [ @selected_start_date, @selected_end_date ].max
    paid_total_sql = "COALESCE((SELECT SUM(invoice_payments.amount) FROM invoice_payments WHERE invoice_payments.invoice_id = invoices.id), 0)"
    last_email_event_type_sql = <<~SQL.squish
      (
        SELECT invoice_events.event_type
        FROM invoice_events
        WHERE invoice_events.invoice_id = invoices.id
          AND invoice_events.event_type IN ('email_requested', 'email_sent', 'email_failed')
        ORDER BY invoice_events.created_at DESC, invoice_events.id DESC
        LIMIT 1
      )
    SQL
    last_email_event_at_sql = <<~SQL.squish
      (
        SELECT invoice_events.created_at
        FROM invoice_events
        WHERE invoice_events.invoice_id = invoices.id
          AND invoice_events.event_type IN ('email_requested', 'email_sent', 'email_failed')
        ORDER BY invoice_events.created_at DESC, invoice_events.id DESC
        LIMIT 1
      )
    SQL

    scoped_invoices = policy_scope(Invoice)
            @invoices = scoped_invoices
              .includes(:receiver_entity, :customs_agent)
          .select(
        "invoices.*",
        "#{paid_total_sql} AS paid_total_for_index",
        "#{last_email_event_type_sql} AS last_email_event_type_for_index",
        "#{last_email_event_at_sql} AS last_email_event_at_for_index"
          )
                .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
                .order(created_at: :desc)

    @invoices = @invoices.where(status: @selected_status) if @selected_status.present? && Invoice::STATUSES.include?(@selected_status)
    @invoices = @invoices.where(kind: @selected_kind) if @selected_kind.present? && Invoice::KINDS.include?(@selected_kind)
    valid_payment_filter = Invoice::PAYMENT_STATUSES.include?(@selected_payment_status)
    @invoices = @invoices.with_payment_status(@selected_payment_status) if @selected_payment_status.present? && valid_payment_filter
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
        "LOWER(COALESCE(invoices.provider_response->>'folio', invoices.provider_response->>'noComprobante', invoices.provider_response->>'numeroComprobante', invoices.facturador_comprobante_id::text, '')) = LOWER(?)",
        @selected_folio
      )
    end
    if @selected_service_catalog_id.present?
      @invoices = @invoices.where(
        <<~SQL,
          (
            invoices.invoiceable_type = 'ContainerService' AND EXISTS (
              SELECT 1
              FROM container_services
              WHERE container_services.id = invoices.invoiceable_id
                AND container_services.service_catalog_id = :service_catalog_id
            )
          )
          OR
          (
            invoices.invoiceable_type = 'BlHouseLineService' AND EXISTS (
              SELECT 1
              FROM bl_house_line_services
              WHERE bl_house_line_services.id = invoices.invoiceable_id
                AND bl_house_line_services.service_catalog_id = :service_catalog_id
            )
          )
          OR EXISTS (
            SELECT 1
            FROM invoice_service_links
            INNER JOIN container_services
              ON invoice_service_links.serviceable_type = 'ContainerService'
             AND invoice_service_links.serviceable_id = container_services.id
            WHERE invoice_service_links.invoice_id = invoices.id
              AND container_services.service_catalog_id = :service_catalog_id
          )
          OR EXISTS (
            SELECT 1
            FROM invoice_service_links
            INNER JOIN bl_house_line_services
              ON invoice_service_links.serviceable_type = 'BlHouseLineService'
             AND invoice_service_links.serviceable_id = bl_house_line_services.id
            WHERE invoice_service_links.invoice_id = invoices.id
              AND bl_house_line_services.service_catalog_id = :service_catalog_id
          )
          OR EXISTS (
            SELECT 1
            FROM invoice_line_items
            WHERE invoice_line_items.invoice_id = invoices.id
              AND invoice_line_items.service_catalog_id = :service_catalog_id
          )
        SQL
        service_catalog_id: @selected_service_catalog_id
      )
    elsif @selected_service_query.present?
      @invoices = @invoices.where(
        <<~SQL,
          (
            invoices.invoiceable_type = 'ContainerService' AND EXISTS (
              SELECT 1
              FROM container_services
              INNER JOIN service_catalogs ON service_catalogs.id = container_services.service_catalog_id
              WHERE container_services.id = invoices.invoiceable_id
                AND (
                  service_catalogs.name ILIKE :service_query
                  OR service_catalogs.code ILIKE :service_query
                )
            )
          )
          OR
          (
            invoices.invoiceable_type = 'BlHouseLineService' AND EXISTS (
              SELECT 1
              FROM bl_house_line_services
              INNER JOIN service_catalogs ON service_catalogs.id = bl_house_line_services.service_catalog_id
              WHERE bl_house_line_services.id = invoices.invoiceable_id
                AND (
                  service_catalogs.name ILIKE :service_query
                  OR service_catalogs.code ILIKE :service_query
                )
            )
          )
          OR EXISTS (
            SELECT 1
            FROM invoice_service_links
            INNER JOIN container_services
              ON invoice_service_links.serviceable_type = 'ContainerService'
             AND invoice_service_links.serviceable_id = container_services.id
            INNER JOIN service_catalogs ON service_catalogs.id = container_services.service_catalog_id
            WHERE invoice_service_links.invoice_id = invoices.id
              AND (
                service_catalogs.name ILIKE :service_query
                OR service_catalogs.code ILIKE :service_query
              )
          )
          OR EXISTS (
            SELECT 1
            FROM invoice_service_links
            INNER JOIN bl_house_line_services
              ON invoice_service_links.serviceable_type = 'BlHouseLineService'
             AND invoice_service_links.serviceable_id = bl_house_line_services.id
            INNER JOIN service_catalogs ON service_catalogs.id = bl_house_line_services.service_catalog_id
            WHERE invoice_service_links.invoice_id = invoices.id
              AND (
                service_catalogs.name ILIKE :service_query
                OR service_catalogs.code ILIKE :service_query
              )
          )
          OR EXISTS (
            SELECT 1
            FROM invoice_line_items
            WHERE invoice_line_items.invoice_id = invoices.id
              AND invoice_line_items.description ILIKE :service_query
          )
        SQL
        service_query: "%#{@selected_service_query}%"
      )
    end
    @invoices = @invoices.where("sat_uuid ILIKE ?", "%#{@selected_uuid}%") if @selected_uuid.present?

    @invoices = @invoices.page(params[:page]).per(params[:per] || 10)

    build_invoice_service_context_data(@invoices)
    @collections_report_text = build_collections_report_text(@invoices)

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

  def collections_report
    authorize Invoice, :index?

    invoice_ids = Array(params[:invoice_ids]).map(&:to_i).select(&:positive?).uniq
    if invoice_ids.empty?
      return redirect_to invoices_path, alert: "Selecciona al menos una factura para exportar el reporte."
    end

    invoices = policy_scope(Invoice)
      .where(id: invoice_ids)
      .includes(:receiver_entity, :customs_agent)
      .order(created_at: :desc)

    build_invoice_service_context_data(invoices)
    rows = build_collections_report_rows(invoices)

    timestamp = Time.current.strftime("%Y%m%d_%H%M")
    requested_format = params[:format].to_s.downcase.presence || request.format.symbol.to_s

    if requested_format == "xlsx"
      send_data(
        build_collections_report_xlsx(rows),
        filename: "reporte_cobranza_#{timestamp}.xlsx",
        type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        disposition: "attachment"
      )
      return
    end

    if requested_format == "pdf"
      send_data(
        build_collections_report_pdf(rows),
        filename: "reporte_cobranza_#{timestamp}.pdf",
        type: "application/pdf",
        disposition: "attachment"
      )
      return
    end

    redirect_to invoices_path, alert: "Formato de exportación no soportado."
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

  def manual_receivers_search
    authorize Invoice, :new?

    query = params[:q].to_s.strip
    receiver_kind = params[:receiver_kind].to_s.presence || "client"
    customs_agent_id = params[:customs_agent_id].to_s.presence
    min_chars = 2
    limit = 20

    if query.length < min_chars
      return render json: { results: [], meta: { query:, receiver_kind:, min_chars:, limit:, count: 0 } }
    end

    receivers_scope = if receiver_kind == "consolidator"
      Entity.consolidators
    else
      scope = Entity.clients
      scope = scope.where(customs_agent_id:) if customs_agent_id.present?
      scope
    end

    cache_key = [
      "invoices",
      "manual_receivers_search",
      current_user.id,
      receiver_kind,
      customs_agent_id || "none",
      query.downcase,
      limit
    ].join(":")

    results = Rails.cache.fetch(cache_key, expires_in: 60.seconds) do
      receivers_scope
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

    render json: { results:, meta: { query:, receiver_kind:, min_chars:, limit:, count: results.size } }
  end

  def manual_customs_agents_search
    authorize Invoice, :new?

    query = params[:q].to_s.strip
    min_chars = 2
    limit = 20

    if query.length < min_chars
      return render json: { results: [], meta: { query:, min_chars:, limit:, count: 0 } }
    end

    cache_key = [
      "invoices",
      "manual_customs_agents_search",
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

  def services_search
    authorize Invoice, :index?

    query = params[:q].to_s.strip
    min_chars = 2
    limit = 20

    if query.length < min_chars
      return render json: { results: [], meta: { query:, min_chars:, limit:, count: 0 } }
    end

    cache_key = [
      "invoices",
      "services_search",
      current_user.id,
      query.downcase,
      limit
    ].join(":")

    results = Rails.cache.fetch(cache_key, expires_in: 60.seconds) do
      ServiceCatalog
        .active
        .where("service_catalogs.name ILIKE :query OR service_catalogs.code ILIKE :query", query: "%#{query}%")
        .order(:name)
        .limit(limit)
        .pluck(:id, :name, :code)
        .map do |id, name, code|
          {
            id:,
            label: code.present? ? "#{name} (#{code})" : name,
            subtitle: code.present? ? "Codigo: #{code}" : nil
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
    @invoice_internal_reference_by_id = {}
    @invoice_recinto_by_id = {}

    invoice_ids = invoices.map(&:id)
    return if invoice_ids.empty?

    invoices.each do |invoice|
      @invoice_agency_by_id[invoice.id] = invoice.customs_agent&.name.to_s.strip.presence
    end

    bl_service_ids_by_invoice_id = Hash.new { |hash, key| hash[key] = [] }

    invoices.each do |invoice|
      next unless invoice.invoiceable_type == "BlHouseLineService"

      bl_service_ids_by_invoice_id[invoice.id] << invoice.invoiceable_id
    end

    linked_rows = InvoiceServiceLink
      .where(invoice_id: invoice_ids, serviceable_type: "BlHouseLineService")
      .pluck(:invoice_id, :serviceable_id)

    linked_rows.each do |invoice_id, serviceable_id|
      bl_service_ids_by_invoice_id[invoice_id] << serviceable_id
    end

    bl_service_ids = bl_service_ids_by_invoice_id.values.flatten.uniq
    if bl_service_ids.any?
      bl_service_data = BlHouseLineService
        .includes(bl_house_line: [ :customs_agent, :container ])
        .where(id: bl_service_ids)
        .index_by(&:id)

      bl_service_ids_by_invoice_id.each do |invoice_id, service_ids|
        services = service_ids.uniq.map { |service_id| bl_service_data[service_id] }.compact
        next if services.empty?

        hbl_values = services.map { |service| service.bl_house_line&.blhouse.to_s.strip }.reject(&:blank?).uniq
        agency_values = services.map { |service| service.bl_house_line&.customs_agent&.name.to_s.strip }.reject(&:blank?).uniq
        internal_reference_values = services.map { |service| service.bl_house_line&.internal_reference.to_s.strip }.reject(&:blank?).uniq
        recinto_values = services.map { |service| service.bl_house_line&.container&.recinto.to_s.strip }.reject(&:blank?).uniq

        @invoice_hbl_by_id[invoice_id] = hbl_values.join(", ").presence
        @invoice_agency_by_id[invoice_id] = agency_values.join(", ").presence || @invoice_agency_by_id[invoice_id]
        @invoice_internal_reference_by_id[invoice_id] = internal_reference_values.join(", ").presence
        @invoice_recinto_by_id[invoice_id] = recinto_values.join(", ").presence
      end
    end

    container_service_ids_by_invoice_id = Hash.new { |hash, key| hash[key] = [] }

    invoices.each do |invoice|
      next unless invoice.invoiceable_type == "ContainerService"

      container_service_ids_by_invoice_id[invoice.id] << invoice.invoiceable_id
    end

    linked_container_rows = InvoiceServiceLink
      .where(invoice_id: invoice_ids, serviceable_type: "ContainerService")
      .pluck(:invoice_id, :serviceable_id)

    linked_container_rows.each do |invoice_id, serviceable_id|
      container_service_ids_by_invoice_id[invoice_id] << serviceable_id
    end

    container_service_ids = container_service_ids_by_invoice_id.values.flatten.uniq
    return if container_service_ids.empty?

    container_service_data = ContainerService
      .includes(:container)
      .where(id: container_service_ids)
      .index_by(&:id)

    container_service_ids_by_invoice_id.each do |invoice_id, service_ids|
      next if @invoice_recinto_by_id[invoice_id].present?

      services = service_ids.uniq.map { |service_id| container_service_data[service_id] }.compact
      next if services.empty?

      recinto_values = services.map { |service| service.container&.recinto.to_s.strip }.reject(&:blank?).uniq
      @invoice_recinto_by_id[invoice_id] = recinto_values.join(", ").presence
    end
  end

  def build_collections_report_text(invoices)
    rows = build_collections_report_rows(invoices)
    total_column_index = 8

    text_lines = []
    text_lines << "Reporte de cobranza (pagina actual)"
    text_lines << "Generado: #{I18n.l(Time.current, format: "%Y-%m-%d %H:%M")}"
    text_lines << ""

    if rows.empty?
      text_lines << "Sin facturas para los filtros actuales."
      return text_lines.join("\n")
    end

    rows.each_with_index do |row, index|
      text_lines << "#{index + 1}) Fecha: #{row[0]} | Ser: #{row[1]} | Fol: #{row[2]} | HBL: #{row[3]} | Ref.Int: #{row[4]} | Recinto: #{row[5]} | Agencia: #{row[6]} | Cliente: #{row[7]} | Saldo: $#{format('%.2f', row[total_column_index].to_d)} | M.Pago: #{row[9]} | Estatus Emision: #{row[10]}"
      text_lines << ""
    end

    total_general = rows.sum { |row| row[total_column_index].to_d }
    text_lines << "Total: $#{format('%.2f', total_general)}"

    text_lines.join("\n")
  end

  def build_collections_report_rows(invoices)
    invoices.map do |invoice|
      serie = invoice.provider_response.to_h["serie"].presence || invoice.payload_snapshot.to_h["serie"].presence
      folio = invoice.provider_response.to_h["folio"].presence ||
              invoice.provider_response.to_h["noComprobante"].presence ||
              invoice.provider_response.to_h["numeroComprobante"].presence ||
              invoice.facturador_comprobante_id&.to_s
      effective_status = invoice.effective_status.to_s
      emission_status_label = I18n.t(
        "activerecord.attributes.invoice.statuses.#{effective_status}",
        default: effective_status.humanize
      )

      [
        invoice.issued_at.present? ? I18n.l(invoice.issued_at, format: "%Y-%m-%d") : "-",
        serie,
        folio,
        @invoice_hbl_by_id[invoice.id],
        @invoice_internal_reference_by_id[invoice.id],
        @invoice_recinto_by_id[invoice.id],
        @invoice_agency_by_id[invoice.id],
        invoice.receiver_entity&.name,
        format("%.2f", invoice.outstanding_amount.to_d),
        invoice.payment_method_code,
        emission_status_label
      ].map { |value| report_cell(value) }
    end
  end

  def collections_report_headers
    [
      "Fecha",
      "Serie",
      "Folio",
      "Blhouse",
      "Referencia Interna",
      "Recinto",
      "Agencia Aduanal",
      "Cliente",
      "Saldo",
      "Metodo de Pago",
      "Estatus de Emision"
    ]
  end

  def build_collections_report_xlsx(rows)
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Cobranza") do |sheet|
      styles = sheet.styles

      title_style = styles.add_style(
        b: true,
        sz: 16,
        fg_color: "0F172A",
        bg_color: "E2E8F0",
        alignment: { horizontal: :left, vertical: :center },
        border: {
          style: :thin,
          color: "CBD5E1",
          edges: %i[left right top bottom]
        }
      )
      subtitle_style = styles.add_style(
        sz: 10,
        fg_color: "475569",
        bg_color: "F8FAFC",
        alignment: { horizontal: :left, vertical: :center },
        border: {
          style: :thin,
          color: "E2E8F0",
          edges: %i[left right top bottom]
        }
      )
      header_style = styles.add_style(
        b: true,
        sz: 10,
        fg_color: "FFFFFF",
        bg_color: "0F766E",
        alignment: { horizontal: :center, vertical: :center, wrap_text: true },
        border: {
          style: :thin,
          color: "D1D5DB",
          edges: %i[left right top bottom]
        }
      )
      row_style_even = styles.add_style(
        sz: 10,
        fg_color: "111827",
        bg_color: "FFFFFF",
        alignment: { vertical: :center, wrap_text: true },
        border: {
          style: :thin,
          color: "E5E7EB",
          edges: %i[left right top bottom]
        }
      )
      row_style_odd = styles.add_style(
        sz: 10,
        fg_color: "111827",
        bg_color: "F8FAFC",
        alignment: { vertical: :center, wrap_text: true },
        border: {
          style: :thin,
          color: "E5E7EB",
          edges: %i[left right top bottom]
        }
      )
      total_style_even = styles.add_style(
        sz: 10,
        b: true,
        fg_color: "111827",
        bg_color: "FFFFFF",
        format_code: "$#,##0.00",
        alignment: { horizontal: :right, vertical: :center },
        border: {
          style: :thin,
          color: "E5E7EB",
          edges: %i[left right top bottom]
        }
      )
      total_style_odd = styles.add_style(
        sz: 10,
        b: true,
        fg_color: "111827",
        bg_color: "F8FAFC",
        format_code: "$#,##0.00",
        alignment: { horizontal: :right, vertical: :center },
        border: {
          style: :thin,
          color: "E5E7EB",
          edges: %i[left right top bottom]
        }
      )
      summary_label_style = styles.add_style(
        sz: 10,
        b: true,
        fg_color: "0F172A",
        bg_color: "E2E8F0",
        alignment: { horizontal: :right, vertical: :center },
        border: {
          style: :thin,
          color: "CBD5E1",
          edges: %i[left right top bottom]
        }
      )
      summary_total_style = styles.add_style(
        sz: 10,
        b: true,
        fg_color: "0F172A",
        bg_color: "E2E8F0",
        format_code: "$#,##0.00",
        alignment: { horizontal: :right, vertical: :center },
        border: {
          style: :thin,
          color: "CBD5E1",
          edges: %i[left right top bottom]
        }
      )

      headers = collections_report_headers
      total_column_index = 8
      grand_total = 0.to_d
      sheet.add_row headers, style: Array.new(headers.size, header_style), height: 24

      rows.each_with_index do |row, index|
        base_style = index.even? ? row_style_even : row_style_odd
        total_style = index.even? ? total_style_even : total_style_odd

        row_values = row.dup
        total_value = row_values[total_column_index].to_d
        grand_total += total_value
        row_values[total_column_index] = total_value

        styles_for_row = Array.new(row_values.size, base_style)
        styles_for_row[total_column_index] = total_style
        sheet.add_row row_values, style: styles_for_row, height: 22
      end

      summary_row = Array.new(headers.size, "")
      summary_row[total_column_index - 1] = "Total"
      summary_row[total_column_index] = grand_total
      summary_styles = Array.new(headers.size, row_style_even)
      summary_styles[total_column_index - 1] = summary_label_style
      summary_styles[total_column_index] = summary_total_style
      sheet.add_row summary_row, style: summary_styles, height: 22

      sheet.add_row []

      footer_title_row = [ "Reporte de cobranza" ] + Array.new(10, "")
      footer_subtitle_row = [ "Generado: #{I18n.l(Time.current, format: "%Y-%m-%d %H:%M")}" ] + Array.new(10, "")

      sheet.add_row footer_title_row, style: Array.new(11, title_style), height: 24
      footer_title_row_index = sheet.rows.size
      sheet.add_row footer_subtitle_row, style: Array.new(11, subtitle_style), height: 20
      footer_subtitle_row_index = sheet.rows.size

      sheet.merge_cells("A#{footer_title_row_index}:K#{footer_title_row_index}")
      sheet.merge_cells("A#{footer_subtitle_row_index}:K#{footer_subtitle_row_index}")

      sheet.column_widths 10, 7, 9, 10, 10, 10, 28, 32, 10, 10, 12
      sheet.auto_filter = "A1:K1"
    end

    package.to_stream.read
  end

  def build_collections_report_pdf(rows)
    pdf = Prawn::Document.new(page_layout: :landscape, page_size: "LETTER", margin: 24)
    pdf.fill_color "0F172A"
    pdf.text "Reporte de cobranza", size: 16, style: :bold
    pdf.move_down 2
    pdf.fill_color "475569"
    pdf.text "Generado: #{I18n.l(Time.current, format: "%Y-%m-%d %H:%M")}", size: 9
    pdf.fill_color "000000"
    pdf.move_down 10

    total_column_index = 8
    report_rows = rows.map do |row|
      row_values = row.dup
      row_values[total_column_index] = "$#{format('%.2f', row_values[total_column_index].to_d)}"
      row_values
    end
    total_general = rows.sum { |row| row[total_column_index].to_d }
    summary_row = Array.new(collections_report_headers.size, "")
    summary_row[total_column_index - 1] = "Total"
    summary_row[total_column_index] = "$#{format('%.2f', total_general)}"

    table_data = [ collections_report_headers ] + report_rows + [ summary_row ]

    pdf.table(
      table_data,
      header: true,
      column_widths: [ 56, 42, 54, 68, 60, 88, 60, 88, 100, 52, 62 ],
      cell_style: {
        size: 8,
        padding: [ 4, 5, 4, 5 ],
        border_width: 0.5,
        border_color: "D1D5DB",
        inline_format: true
      }
    ) do
      row(0).font_style = :bold
      row(0).background_color = "0F766E"
      row(0).text_color = "FFFFFF"
      row(0).align = :center

      cells.style do |cell|
        cell.overflow = :shrink_to_fit
      end

      (1...row_length).each do |i|
        row(i).background_color = i.even? ? "FFFFFF" : "F8FAFC"
      end

      summary_row_index = row_length - 1
      row(summary_row_index).background_color = "E2E8F0"
      row(summary_row_index).font_style = :bold

      column(total_column_index).align = :right
      column(total_column_index).font_style = :bold
    end

    pdf.render
  end

  def report_cell(value)
    cleaned = value.to_s.gsub(/[\t\r\n]+/, " ").squish
    cleaned.presence || "-"
  end

  def build_invoice_show_context_data(invoice)
    @invoice_hbl = nil
    @invoice_agency = invoice.customs_agent&.name.to_s.strip.presence

    bl_service_ids = []
    if invoice.invoiceable_type == "BlHouseLineService" && invoice.invoiceable_id.present?
      bl_service_ids << invoice.invoiceable_id
    end

    linked_service_ids = invoice.invoice_service_links
      .where(serviceable_type: "BlHouseLineService")
      .pluck(:serviceable_id)
    bl_service_ids.concat(linked_service_ids)
    bl_service_ids.uniq!
    return if bl_service_ids.empty?

    services = BlHouseLineService
      .includes(bl_house_line: :customs_agent)
      .where(id: bl_service_ids)

    hbl_values = services.map { |service| service.bl_house_line&.blhouse.to_s.strip }.reject(&:blank?).uniq
    agency_values = services.map { |service| service.bl_house_line&.customs_agent&.name.to_s.strip }.reject(&:blank?).uniq

    @invoice_hbl = hbl_values.join(", ").presence
    @invoice_agency = agency_values.join(", ").presence || @invoice_agency
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
    series_for_current_environment.map { |serie| [ serie, serie ] }
  end

  def build_series_filter_options
    [ [ "Todas", "" ] ] + series_for_current_environment.map { |serie| [ serie, serie ] }
  end

  def series_for_current_environment
    if Facturador::Config.environment.to_s.casecmp("sandbox").zero?
      Facturador::PayloadBuilder::IMPORT_DESTINATION_SERIES_BY_PORT_CODE_SANDBOX.values
    else
      Facturador::PayloadBuilder::IMPORT_DESTINATION_SERIES_BY_PORT_CODE_PRODUCTION.values
    end.uniq
  end

  def resolved_start_date
    parse_filter_date(params[:start_date]) || default_start_date
  end

  def resolved_end_date
    parse_filter_date(params[:end_date]) || default_end_date
  end

  def resolved_selected_service_label
    return nil if @selected_service_catalog_id.blank?

    service_catalog = ServiceCatalog.find_by(id: @selected_service_catalog_id)
    return nil if service_catalog.blank?

    service_catalog.display_name
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

  def build_applied_filters(admin_or_executive:)
    filters = []

    if params[:start_date].present?
      filters << { key: "start_date", label: "Desde", value: @selected_start_date.strftime("%d/%m/%Y") }
    end

    if params[:end_date].present?
      filters << { key: "end_date", label: "Hasta", value: @selected_end_date.strftime("%d/%m/%Y") }
    end

    if @selected_status.present? && Invoice::STATUSES.include?(@selected_status)
      filters << {
        key: "status",
        label: "Emision",
        value: I18n.t("activerecord.attributes.invoice.statuses.#{@selected_status}", default: @selected_status.humanize)
      }
    end

    if @selected_kind.present? && Invoice::KINDS.include?(@selected_kind)
      kind_label = @selected_kind == "ingreso" ? "Factura" : "Pago"
      filters << { key: "kind", label: "Tipo comprobante", value: kind_label }
    end

    if @selected_payment_status.present? && Invoice::PAYMENT_STATUSES.include?(@selected_payment_status)
      payment_label = Invoice::PAYMENT_STATUS_LABELS[@selected_payment_status] || @selected_payment_status.humanize
      filters << { key: "payment_status", label: "Pago", value: payment_label }
    end

    if @selected_client_id.present?
      client_name = Entity.where(id: @selected_client_id).pick(:name)
      filters << { key: "client", label: "Receptor", value: client_name.presence || @selected_client_id }
    end

    if admin_or_executive && @selected_customs_agent_id.present?
      agent_name = Entity.where(id: @selected_customs_agent_id).pick(:name)
      filters << { key: "customs_agent", label: "Agencia aduanal", value: agent_name.presence || @selected_customs_agent_id }
    end

    if admin_or_executive && @selected_consolidator_id.present?
      consolidator_name = Entity.where(id: @selected_consolidator_id).pick(:name)
      filters << { key: "consolidator", label: "Consolidador", value: consolidator_name.presence || @selected_consolidator_id }
    end

    filters << { key: "uuid", label: "UUID", value: @selected_uuid } if @selected_uuid.present?
    filters << { key: "container_number", label: "Contenedor", value: @selected_container_number } if @selected_container_number.present?
    filters << { key: "blhouse", label: "BL House", value: @selected_blhouse } if @selected_blhouse.present?
    filters << { key: "serie", label: "Serie", value: @selected_serie } if @selected_serie.present?
    filters << { key: "folio", label: "Folio", value: @selected_folio } if @selected_folio.present?
    if @selected_service_catalog_id.present? && @selected_service.present?
      filters << { key: "service", label: "Servicio", value: @selected_service }
    elsif @selected_service_query.present?
      filters << { key: "service", label: "Servicio", value: @selected_service_query }
    end

    filters
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
