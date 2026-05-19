require "caxlsx"

class BlHouseLinesController < ApplicationController
  IMPORT_ROW_LIMIT = 500
  IMPORT_SIZE_LIMIT = 2.megabytes
  IMPORT_TEMPLATE_HEADERS = %w[blhouse cantidad embalaje contiene marcas peso volumen clase_imo tipo_imo].freeze
  DATE_FILTER_TYPES = %w[created_at fecha_desconsolidacion].freeze
  DELETABLE_DOCUMENTS = %w[bl_endosado_documento liberacion_documento encomienda_documento pago_documento].freeze

  before_action :authenticate_user!
  before_action :set_bl_house_line, only: %i[show edit update destroy destroy_document revalidation_approval approve_revalidation documents reassign perform_reassign reassign_brokers dispatch_date update_dispatch_date service_catalogs_search bill_to_clients_search]
  after_action :verify_authorized, except: :index

  # GET /bl_house_lines
  def index
    if customs_agent_user?
      redirect_to customs_agents_dashboard_path and return
    end

    @status_filter_options = customs_agent_user? ? customs_agent_statuses : BlHouseLine.statuses.keys

    scope = filtered_bl_house_lines_scope(base_bl_house_lines_scope)

    @bl_house_lines = scope.order(created_at: :desc, id: :desc).page(params[:page]).per(params[:per] || 10)

    # Data for filters
    load_clients
    @consolidators = Entity.consolidators.order(:name)
    @destination_ports = destination_port_filter_options
  end

  def revalidations_report
    authorize BlHouseLine, :revalidations_report?

    @status_filter_options = customs_agent_user? ? customs_agent_statuses : BlHouseLine.statuses.keys
    rows = build_revalidations_report_rows(
      filtered_bl_house_lines_scope(base_bl_house_lines_scope)
        .order(created_at: :desc, id: :desc)
    )

    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    send_data(
      build_revalidations_report_xlsx(rows),
      filename: "reporte_revalidaciones_#{timestamp}.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment"
    )
  end

  def inventory_report
    authorize BlHouseLine, :inventory_report?

    rows = build_inventory_report_rows(
      base_bl_house_lines_scope
        .joins(:container)
        .where(containers: { status: "desconsolidado" })
        .where(fecha_despacho: nil)
        .where.not(status: "despachado")
        .includes(:client, :customs_agent, container: [ :consolidator_entity, :origin_port, :voyage ])
        .order(created_at: :desc, id: :desc)
    )

    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    send_data(
      build_inventory_report_xlsx(rows),
      filename: "reporte_inventario_#{timestamp}.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment"
    )
  end

  def clients_search
    authorize BlHouseLine, :index?

    if customs_agent_user?
      return render json: { results: [], meta: { query: params[:q].to_s.strip, min_chars: 2, limit: 20, count: 0 } }, status: :forbidden
    end

    query = params[:q].to_s.strip
    min_chars = 2
    limit = 20

    if query.length < min_chars
      return render json: { results: [], meta: { query:, min_chars:, limit:, count: 0 } }
    end

    cache_key = [ "bl_house_lines", "clients_search", query.downcase, limit ].join(":")
    results = Rails.cache.fetch(cache_key, expires_in: 60.seconds) do
      Entity
        .clients
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
    authorize BlHouseLine, :index?

    if customs_agent_user?
      return render json: { results: [], meta: { query: params[:q].to_s.strip, min_chars: 2, limit: 20, count: 0 } }, status: :forbidden
    end

    query = params[:q].to_s.strip
    min_chars = 2
    limit = 20

    if query.length < min_chars
      return render json: { results: [], meta: { query:, min_chars:, limit:, count: 0 } }
    end

    cache_key = [ "bl_house_lines", "customs_agents_search", query.downcase, limit ].join(":")
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

  def service_catalogs_search
    authorize @bl_house_line, :show?

    query = params[:q].to_s.strip
    min_chars = 2
    limit = 20

    if query.length < min_chars
      return render json: { results: [], meta: { query:, min_chars:, limit:, count: 0 } }
    end

    cache_key = [ "bl_house_lines", "service_catalogs_search", query.downcase, limit ].join(":")
    results = Rails.cache.fetch(cache_key, expires_in: 60.seconds) do
      term = "%#{query}%"
      ServiceCatalog
        .for_bl_house_lines
        .where("name ILIKE ? OR code ILIKE ?", term, term)
        .order(:name)
        .limit(limit)
        .map do |catalog|
          {
            id: catalog.id,
            label: catalog.display_name,
            data: {
              amount: catalog.amount
            }
          }
        end
    end

    render json: { results:, meta: { query:, min_chars:, limit:, count: results.size } }
  end

  def bill_to_clients_search
    authorize @bl_house_line, :show?

    query = params[:q].to_s.strip
    min_chars = 2
    limit = 20

    if query.length < min_chars
      return render json: { results: [], meta: { query:, min_chars:, limit:, count: 0 } }
    end

    cache_key = [
      "bl_house_lines",
      "bill_to_clients_search",
      @bl_house_line.id,
      query.downcase,
      limit,
      @bl_house_line.customs_agent_id,
      @bl_house_line.client_id
    ].join(":")

    results = Rails.cache.fetch(cache_key, expires_in: 60.seconds) do
      term = "%#{query}%"
      clients_scope = if @bl_house_line.customs_agent.present?
        @bl_house_line.customs_agent.clients
      else
        Entity.none
      end

      if @bl_house_line.client_id.present?
        clients_scope = clients_scope.or(Entity.where(id: @bl_house_line.client_id))
      end

      clients_scope
        .where("name ILIKE ?", term)
        .order(:name)
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

  # GET /bl_house_lines/1
  def show
    authorize @bl_house_line
    return if customs_agent_user?

    @service_catalogs = ServiceCatalog.for_bl_house_lines
    load_clients
  end

  # GET /bl_house_lines/new
  def new
    @bl_house_line = BlHouseLine.new
    @bl_house_line.container_id = params[:container_id] if params[:container_id].present?
    @customs_agents = available_customs_agents
    @service_catalogs = ServiceCatalog.for_bl_house_lines
    load_clients
    authorize @bl_house_line
  end

  # GET /bl_house_lines/1/edit
  def edit
    @customs_agents = available_customs_agents
    @service_catalogs = ServiceCatalog.for_bl_house_lines
    load_clients
    authorize @bl_house_line
  end

  # POST /bl_house_lines
  def create
    @bl_house_line = BlHouseLine.new(bl_house_line_params)
    authorize @bl_house_line

    assign_container_from_params

    if @bl_house_line.save
      persist_internal_reference_observation(@bl_house_line, params[:internal_reference])
      redirect_to @bl_house_line, notice: "Partida creada correctamente."
    else
      @customs_agents = available_customs_agents
      @service_catalogs = ServiceCatalog.for_bl_house_lines
      load_clients
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /bl_house_lines/1
  def update
    authorize @bl_house_line

    return handle_services_update_from_show if params[:source] == "show_services"

    assign_container_from_params

    if @bl_house_line.update(bl_house_line_params)
      persist_internal_reference_observation(@bl_house_line, params[:internal_reference])
      redirect_to @bl_house_line, notice: "Partida actualizada correctamente."
    else
      @customs_agents = available_customs_agents
      @service_catalogs = ServiceCatalog.for_bl_house_lines
      load_clients
      render :edit, status: :unprocessable_entity
    end
  end

  # POST /containers/:id/bl_house_lines/import
  def import_from_container
    @container = Container.find(params[:id])
    authorize BlHouseLine

    file = params[:file]
    if file.blank?
      return redirect_to container_path(@container), alert: "Selecciona un archivo XLSX o CSV."
    end

    set_current_user_for_import

    result = BlHouseLines::ImportService.new(
      container: @container,
      file: file,
      current_user: current_user,
      row_limit: IMPORT_ROW_LIMIT,
      size_limit: IMPORT_SIZE_LIMIT
    ).call

    notice = "Importación completada: #{result.created_count} partidas creadas."
    alert = result.errors.any? ? "Errores: #{result.errors.join(' | ')}" : nil

    redirect_to container_path(@container), notice: notice, alert: alert
  rescue BlHouseLines::ImportService::ImportError => e
    redirect_to container_path(@container), alert: e.message
  ensure
    clear_current_user_after_import
  end

  # GET /containers/:id/download_bl_house_lines_template
  def download_template_for_container
    @container = Container.find(params[:id])
    authorize BlHouseLine, :import_from_container?

    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Partidas") do |sheet|
      sheet.add_row IMPORT_TEMPLATE_HEADERS
    end
    xlsx_data = package.to_stream.read
    date_suffix = Time.zone.today.strftime("%Y%m%d")
    template_filename = "formato_importacion_partidas_#{@container.number}_#{date_suffix}.xlsx"

    send_data xlsx_data,
      filename: template_filename,
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  # DELETE /bl_house_lines/1
  def destroy
    authorize @bl_house_line

    @bl_house_line.destroy
    redirect_to bl_house_lines_url, notice: "Partida eliminada correctamente."
  end

  def destroy_document
    authorize @bl_house_line, :destroy_document?

    document_name = params[:document].to_s
    unless DELETABLE_DOCUMENTS.include?(document_name)
      return redirect_to bl_house_line_path(@bl_house_line), alert: "Documento inválido."
    end

    attachment = @bl_house_line.public_send(document_name)
    unless attachment.attached?
      return redirect_to bl_house_line_path(@bl_house_line), alert: "No hay documento adjunto para eliminar."
    end

    attachment.purge
    redirect_to bl_house_line_path(@bl_house_line), notice: "Documento eliminado correctamente."
  end

  # GET /bl_house_lines/1/revalidation_approval
  def revalidation_approval
    authorize @bl_house_line, :approve_revalidation?
    @requesting_agent = requesting_customs_agent
    @customs_agents = Entity.customs_agents.order(:name).to_a
    if @requesting_agent.present?
      @customs_agents.delete(@requesting_agent)
      @customs_agents.unshift(@requesting_agent)
    end
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # GET /bl_house_lines/1/dispatch_date
  def dispatch_date
    authorize @bl_house_line, :update?
    return unless ensure_dispatch_allowed

    respond_to do |format|
      format.html { render partial: "bl_house_lines/dispatch/modal", locals: { bl_house_line: @bl_house_line } }
      format.turbo_stream { render partial: "bl_house_lines/dispatch/modal", locals: { bl_house_line: @bl_house_line } }
    end
  end

  # PATCH /bl_house_lines/1/update_dispatch_date
  def update_dispatch_date
    authorize @bl_house_line, :update?
    return unless ensure_dispatch_allowed

    @bl_house_line.assign_attributes(dispatch_date_params)
    @bl_house_line.status = "despachado"

    if @bl_house_line.fecha_despacho.blank?
      @bl_house_line.errors.add(:fecha_despacho, "no puede estar en blanco")
      return render_dispatch_modal(:unprocessable_entity)
    end

    if @bl_house_line.save
      respond_to do |format|
        format.turbo_stream do
          row_dom_id = view_context.dom_id(@bl_house_line, :row)
          mobile_dom_id = view_context.dom_id(@bl_house_line, :mobile)

          render turbo_stream: [
            turbo_stream.replace("dispatch_modal", partial: "bl_house_lines/dispatch/modal_success", locals: { bl_house_line: @bl_house_line }),
            turbo_stream.replace(row_dom_id, partial: "bl_house_lines/row", locals: { bl_house_line: @bl_house_line }),
            turbo_stream.replace(mobile_dom_id, partial: "bl_house_lines/mobile_card", locals: { bl_house_line: @bl_house_line })
          ]
        end
        format.html { redirect_to bl_house_lines_path, notice: "Fecha de despacho guardada." }
      end
    else
      render_dispatch_modal(:unprocessable_entity)
    end
  end

  # PATCH /bl_house_lines/1/approve_revalidation
  def approve_revalidation
    authorize @bl_house_line, :approve_revalidation?

    decision = params[:decision]
    @bl_house_line.assign_attributes(revalidation_params)
    @bl_house_line.assign_attributes(document_validation_flags)

    if decision == "reject"
      @bl_house_line.status = "instrucciones_pendientes"
      if @bl_house_line.save
        add_history_observation(params[:observations])
        notify_customs_agent("Correcciones Solicitadas")

        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace("approval_modal", partial: "bl_house_lines/approval/modal_closed") }
          format.html { redirect_to bl_house_lines_path, notice: "Instrucciones enviadas." }
        end
      else
        render :revalidation_approval, status: :unprocessable_entity
      end

    elsif decision == "assign"
      tarja_present = @bl_house_line.container&.tarja_documento&.attached?
      @bl_house_line.status = tarja_present ? "revalidado" : "documentos_ok"

      # Ensure attributes are assigned (including validation flags)
      @bl_house_line.assign_attributes(revalidation_params)
      @bl_house_line.assign_attributes(document_validation_flags)

      unless documents_validated?(@bl_house_line)
        @bl_house_line.errors.add(:base, "Debes marcar todos los documentos como validados antes de continuar.")
        return render :revalidation_approval, status: :unprocessable_entity
      end

      container = @bl_house_line.container

      tentative_date = params[:fecha_tentativa_desconsolidacion].presence || params[:tentative_date].presence
      tentative_turno = params[:tentativa_turno].presence || params[:time_period].presence

      unless tarja_present
        if tentative_date.blank?
          @bl_house_line.errors.add(:base, "Debes capturar la fecha tentativa de desconsolidación.")
          return render :revalidation_approval, status: :unprocessable_entity
        end

        if container
          container.assign_attributes(
            fecha_tentativa_desconsolidacion: tentative_date,
            tentativa_turno: tentative_turno.presence
          )
        end
      end

      begin
        ActiveRecord::Base.transaction do
          @bl_house_line.save!
          container.save! if container&.changed?
        end

        unless tarja_present
          if tentative_date.present?
            turno_label = tentative_turno.to_s.tr("_", " ").capitalize
            formatted_date = I18n.l(Date.parse(tentative_date.to_s), format: :long)
            full_observation = "Fecha tentativa para el inicio de revalidacion: el día #{formatted_date} en el #{turno_label.presence || 'Primer turno'}"
            history = @bl_house_line.bl_house_line_status_histories.order(created_at: :desc).first
            if history
              history.update(observations: full_observation)
            else
              @bl_house_line.bl_house_line_status_histories.create(
                status: @bl_house_line.status,
                changed_at: Time.current,
                user: current_user,
                observations: full_observation
              )
            end
          end
        end

        notify_customs_agent("Documentación Aprobada")

        success_message = tarja_present ? "Partida marcada como Revalidada." : "Partida lista con Documentos OK."

        respond_to do |format|
           format.turbo_stream do
             render turbo_stream: turbo_stream.replace(
               "approval_modal",
               partial: "bl_house_lines/approval/modal_success",
               locals: { bl_house_line: @bl_house_line, success_message: success_message }
             )
           end
           format.html { redirect_to bl_house_lines_path, notice: "Revalidación aprobada y agente asignado." }
        end
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn "Validation errors in approve_revalidation: #{e.record.errors.full_messages}"
        if e.record != @bl_house_line
          @bl_house_line.errors.add(:base, e.record.errors.full_messages.to_sentence)
        end
        render :revalidation_approval, status: :unprocessable_entity
      rescue => e
        Rails.logger.error "Error in approve_revalidation (assign): #{e.message}"
        @bl_house_line.errors.add(:base, "Ocurrió un error al procesar la aprobación: #{e.message}")
        render :revalidation_approval, status: :unprocessable_entity
      end
    end
  end

  # GET /bl_house_lines/1/documents
  def documents
    authorize @bl_house_line
    # This logic allows downloading multiple documents related to the revalidation.
  end

  # GET /bl_house_lines/1/reassign
  def reassign
    authorize @bl_house_line, :reassign?
    load_reassign_collections
  end

  # PATCH /bl_house_lines/1/perform_reassign
  def perform_reassign
    authorize @bl_house_line, :perform_reassign?

    service = BlHouseLines::ReassignService.new(
      bl_house_line: @bl_house_line,
      new_customs_agent_id: reassign_params[:new_customs_agent_id],
      new_customs_broker_id: reassign_params[:new_customs_broker_id],
      new_client_id: reassign_params[:new_client_id],
      current_user: current_user
    )

    service.call

    redirect_to bl_house_lines_path, notice: "Partida reasignada correctamente."
  rescue StandardError => e
    Rails.logger.error("Failed to reassign BL House Line ##{@bl_house_line.id}: #{e.message}")
    flash.now[:alert] = "No se pudo reasignar la partida: #{e.message}"
    load_reassign_collections
    render :reassign, status: :unprocessable_entity
  end

  # GET /bl_house_lines/1/reassign_brokers
  def reassign_brokers
    authorize @bl_house_line, :reassign?
    load_reassign_collections

    render turbo_stream: [
      turbo_stream.replace(
        "broker_select",
        view_context.turbo_frame_tag("broker_select") do
          view_context.render(
            partial: "bl_house_lines/broker_select",
            locals: {
              brokers: @customs_brokers,
              selected_broker_id: params[:selected_broker_id]
            }
          )
        end
      ),
      turbo_stream.replace(
        "client_select",
        view_context.turbo_frame_tag("client_select") do
          view_context.render(
            partial: "bl_house_lines/client_select",
            locals: {
              clients: @clients,
              selected_client_id: params[:selected_client_id]
            }
          )
        end
      )
    ]
  end

  private

  def load_clients
    if customs_agent_user?
      @clients = current_user.entity.clients.order(:name)
    else
      @clients = Entity.clients.order(:name)
    end
  end

  def set_current_user_for_import
    return unless defined?(Current) && Current.respond_to?(:user=)

    Current.user = current_user
  end

  def clear_current_user_after_import
    return unless defined?(Current) && Current.respond_to?(:user=)

    Current.user = nil
  end

  def available_customs_agents
    return Entity.customs_agents unless current_user

    if current_user.customs_broker? && current_user.entity&.role_customs_agent?
      Entity.where(id: current_user.entity_id)
    else
      Entity.customs_agents
    end
  end

  def customs_agent_user?
    current_user&.customs_broker? && current_user.entity&.role_customs_agent?
  end

  def customs_agent_statuses
    %w[activo validar_documentos instrucciones_pendientes documentos_ok revalidado despachado]
  end

  def selected_status_filter
    return params[:status].presence if params.key?(:status)
    return unless current_user&.admin_or_executive?
    return unless initial_index_load?

    "validar_documentos"
  end

  def initial_index_load?
    params[:blhouse].blank? &&
      params[:container_number].blank? &&
      params[:client_id].blank? &&
      params[:consolidator_id].blank? &&
      params[:destination_port_id].blank? &&
      params[:start_date].blank? &&
      params[:end_date].blank? &&
      params[:hidden].blank?
  end

  def base_bl_house_lines_scope
    policy_scope(BlHouseLine).includes(
      :customs_broker,
      :customs_agent,
      { container: :consolidator_entity }
    )
  end

  def filtered_bl_house_lines_scope(scope)
    if params[:blhouse].present?
      scope = scope.where("bl_house_lines.blhouse ILIKE ?", "%#{params[:blhouse]}%")
    end

    if params[:container_number].present?
      scope = scope.joins(:container).where("containers.number ILIKE ?", "%#{params[:container_number]}%")
    end

    if current_user&.consolidator?
      if params[:reference].present? || params[:master_bl].present?
        scope = scope.joins(:container)
        scope = scope.where("containers.archivo_nr ILIKE ?", "%#{params[:reference]}%") if params[:reference].present?
        scope = scope.where("containers.bl_master ILIKE ?", "%#{params[:master_bl]}%") if params[:master_bl].present?
      end
    else
      if params[:client_id].present?
        scope = scope.where(client_id: params[:client_id])
      end

      if params[:consolidator_id].present?
        scope = scope.joins(:container).where(containers: { consolidator_entity_id: params[:consolidator_id] })
      end

      if params[:destination_port_id].present?
        scope = scope.joins(container: :voyage).where(voyages: { destination_port_id: params[:destination_port_id] })
      end
    end

    @selected_start_date = resolved_start_date
    @selected_end_date = resolved_end_date
    @selected_date_filter_type = resolved_date_filter_type
    start_date = [ @selected_start_date, @selected_end_date ].min
    end_date = [ @selected_start_date, @selected_end_date ].max

    scope = if @selected_date_filter_type == "fecha_desconsolidacion"
      scope.joins(:container).where(containers: { fecha_desconsolidacion: start_date..end_date })
    else
      scope.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    end

    @selected_status_filter = selected_status_filter
    if @selected_status_filter.present? && @status_filter_options.include?(@selected_status_filter)
      scope = scope.where(status: @selected_status_filter)
    end

    if params[:hidden].present? && !customs_agent_user?
      case params[:hidden]
      when "hidden"
        scope = scope.where(hidden_from_customs_agent: true)
      when "visible"
        scope = scope.where(hidden_from_customs_agent: false)
      end
    end

    scope
  end

  def inventory_filtered_bl_house_lines_scope(scope)
    if params[:blhouse].present?
      scope = scope.where("bl_house_lines.blhouse ILIKE ?", "%#{params[:blhouse]}%")
    end

    if params[:container_number].present?
      scope = scope.joins(:container).where("containers.number ILIKE ?", "%#{params[:container_number]}%")
    end

    if current_user&.consolidator?
      if params[:reference].present? || params[:master_bl].present?
        scope = scope.joins(:container)
        scope = scope.where("containers.archivo_nr ILIKE ?", "%#{params[:reference]}%") if params[:reference].present?
        scope = scope.where("containers.bl_master ILIKE ?", "%#{params[:master_bl]}%") if params[:master_bl].present?
      end
    else
      if params[:client_id].present?
        scope = scope.where(client_id: params[:client_id])
      end

      if params[:consolidator_id].present?
        scope = scope.joins(:container).where(containers: { consolidator_entity_id: params[:consolidator_id] })
      end

      if params[:destination_port_id].present?
        scope = scope.joins(container: :voyage).where(voyages: { destination_port_id: params[:destination_port_id] })
      end
    end

    start_date = parse_filter_date(params[:start_date]) || default_start_date
    end_date = parse_filter_date(params[:end_date]) || default_end_date
    from_date = [ start_date, end_date ].min
    to_date = [ start_date, end_date ].max
    scope = scope.where(created_at: from_date.beginning_of_day..to_date.end_of_day)

    if params[:status].present?
      scope = scope.where(status: params[:status]) if BlHouseLine.statuses.key?(params[:status])
    end

    if params[:hidden].present? && !customs_agent_user?
      case params[:hidden]
      when "hidden"
        scope = scope.where(hidden_from_customs_agent: true)
      when "visible"
        scope = scope.where(hidden_from_customs_agent: false)
      end
    end

    scope
  end

  def build_revalidations_report_rows(scope)
    scope.map do |bl_house_line|
      container = bl_house_line.container
      broker_name = bl_house_line.customs_broker&.name.to_s.strip
      broker_patent = bl_house_line.customs_broker&.patent_number.to_s.strip
      customs_broker_label = if broker_name.present? && broker_patent.present?
        "#{broker_name} [#{broker_patent}]"
      else
        broker_name.presence || "-"
      end

      [
        container&.archivo_nr.to_s.strip.presence || "-",
        container&.ejecutivo.to_s.strip.presence || "-",
        container&.number.to_s.strip.presence || "-",
        container&.bl_master.to_s.strip.presence || "-",
        bl_house_line.blhouse.to_s.strip.presence || "-",
        container&.almacen.to_s.strip.presence || "-",
        bl_house_line.cantidad,
        bl_house_line.peso,
        bl_house_line.volumen,
        customs_broker_label,
        bl_house_line.telex? ? "Si" : "No",
        bl_house_line.revalidated_at || container&.fecha_revalidacion_bl_master,
        bl_house_line.fecha_despacho
      ]
    end
  end

  def build_inventory_report_rows(scope)
    scope.map do |bl_house_line|
      container = bl_house_line.container
      fecha_desconsolidacion = container&.fecha_desconsolidacion
      dias_en_almacen = fecha_desconsolidacion.present? ? (Date.current - fecha_desconsolidacion).to_i : nil

      [
        container&.archivo_nr.to_s.strip.presence || "-",
        container&.consolidator_entity&.name.to_s.strip.presence || "-",
        container&.number.to_s.strip.presence || "-",
        container&.bl_master.to_s.strip.presence || "-",
        bl_house_line.blhouse.to_s.strip.presence || "-",
        bl_house_line.partida,
        bl_house_line.client&.name.to_s.strip.presence || "-",
        container&.ejecutivo.to_s.strip.presence || "-",
        container&.origin_port&.display_name.to_s.strip.presence || container&.origin_port&.name.to_s.strip.presence || "-",
        container&.recinto.to_s.strip.presence || "-",
        container&.almacen.to_s.strip.presence || "-",
        bl_house_line.contiene.to_s.strip.presence || "-",
        bl_house_line.marcas.to_s.strip.presence || "-",
        bl_house_line.cantidad,
        bl_house_line.peso,
        bl_house_line.volumen,
        fecha_desconsolidacion,
        dias_en_almacen,
        bl_house_line.status.to_s.humanize.presence || "-",
        bl_house_line.customs_agent&.name.to_s.strip.presence || "-",
        bl_house_line.created_at
      ]
    end
  end

  def build_revalidations_report_xlsx(rows)
    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: "Revalidaciones") do |sheet|
      header = [
        "Referencia",
        "Ejecutivo",
        "Contenedor",
        "MBL",
        "HBL",
        "Almacen",
        "Bultos",
        "Peso",
        "M3",
        "Agente Aduanal",
        "Telex",
        "Fecha Revalidacion",
        "Fecha Despacho"
      ]

      styles = sheet.styles
      header_style = styles.add_style(b: true, bg_color: "1F2937", fg_color: "FFFFFF", alignment: { horizontal: :center })
      summary_label_style = styles.add_style(b: true, bg_color: "E2E8F0", fg_color: "0F172A")
      datetime_style = styles.add_style(format_code: "yyyy-mm-dd hh:mm")
      date_style = styles.add_style(format_code: "yyyy-mm-dd")
      number_style = styles.add_style(format_code: "0.000")
      integer_style = styles.add_style(format_code: "0")
      alternate_row_style = styles.add_style(bg_color: "F8FAFC")

      total_bultos = rows.sum { |row| row[6].to_i }
      total_peso = rows.sum { |row| row[7].to_d }
      total_m3 = rows.sum { |row| row[8].to_d }

      sheet.add_row([ "Fecha de corte", Time.current ], style: [ summary_label_style, datetime_style ])
      sheet.add_row([ "Total partidas", rows.size ], style: [ summary_label_style, integer_style ])
      sheet.add_row([ "Total bultos", total_bultos ], style: [ summary_label_style, integer_style ])
      sheet.add_row([ "Peso total", total_peso ], style: [ summary_label_style, number_style ])
      sheet.add_row([ "M3 total", total_m3 ], style: [ summary_label_style, number_style ])
      sheet.add_row([])

      sheet.add_row(header, style: header_style)

      base_row_style = [
        nil, nil, nil, nil, nil, nil,
        integer_style,
        number_style,
        number_style,
        nil,
        nil,
        datetime_style,
        date_style
      ]
      alternate_row_styles = base_row_style.map { |style| style || alternate_row_style }

      rows.each_with_index do |row, index|
        style = index.even? ? base_row_style : alternate_row_styles
        sheet.add_row(row, style: style)
      end

      header_row_index = 7
      last_row_index = [ header_row_index + rows.size, header_row_index ].max
      sheet.auto_filter = "A#{header_row_index}:M#{last_row_index}"
      sheet.sheet_view.pane do |pane|
        pane.top_left_cell = "A#{header_row_index + 1}"
        pane.state = :frozen_split
        pane.y_split = header_row_index
        pane.active_pane = :bottom_left
      end

      sheet.column_widths 20, 20, 18, 18, 18, 18, 10, 12, 10, 28, 18, 20, 18
    end

    package.to_stream.read
  end

  def build_inventory_report_xlsx(rows)
    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: "Inventario") do |sheet|
      header = [
        "Referencia",
        "Consolidador",
        "Contenedor",
        "MBL",
        "HBL",
        "Partida",
        "Cliente",
        "Ejecutivo",
        "Puerto Origen",
        "Terminal",
        "Almacen",
        "Mercancia",
        "Marcas",
        "Bultos",
        "Peso",
        "Volumen",
        "Fecha Desconsolidacion",
        "Dias en Almacen",
        "Estatus Partida",
        "Agencia Aduanal",
        "Fecha Alta"
      ]

      styles = sheet.styles
      header_style = styles.add_style(b: true, bg_color: "1F2937", fg_color: "FFFFFF", alignment: { horizontal: :center })
      summary_label_style = styles.add_style(b: true, bg_color: "E2E8F0", fg_color: "0F172A")
      date_style = styles.add_style(format_code: "yyyy-mm-dd")
      datetime_style = styles.add_style(format_code: "yyyy-mm-dd hh:mm")
      integer_style = styles.add_style(format_code: "0")
      decimal_style = styles.add_style(format_code: "0.000")
      alternate_row_style = styles.add_style(bg_color: "F8FAFC")

      total_bultos = rows.sum { |row| row[13].to_i }
      total_peso = rows.sum { |row| row[14].to_d }

      sheet.add_row([ "Fecha de corte", Time.current ], style: [ summary_label_style, datetime_style ])
      sheet.add_row([ "Total partidas", rows.size ], style: [ summary_label_style, integer_style ])
      sheet.add_row([ "Total bultos", total_bultos ], style: [ summary_label_style, integer_style ])
      sheet.add_row([ "Peso total", total_peso ], style: [ summary_label_style, decimal_style ])
      sheet.add_row([])

      sheet.add_row(header, style: header_style)

      base_row_style = Array.new(header.length)
      base_row_style[16] = date_style
      base_row_style[20] = datetime_style
      [ 5, 13, 17 ].each { |index| base_row_style[index] = integer_style }
      base_row_style[14] = decimal_style
      base_row_style[15] = decimal_style

      alternate_row_styles = base_row_style.map { |style| style || alternate_row_style }

      rows.each_with_index do |row, index|
        style = index.even? ? base_row_style : alternate_row_styles
        sheet.add_row(row, style: style)
      end

      header_row_index = 6
      last_row_index = [ header_row_index + rows.size, header_row_index ].max
      sheet.auto_filter = "A#{header_row_index}:U#{last_row_index}"
      sheet.sheet_view.pane do |pane|
        pane.top_left_cell = "A#{header_row_index + 1}"
        pane.state = :frozen_split
        pane.y_split = header_row_index
        pane.active_pane = :bottom_left
      end

      sheet.column_widths 16, 24, 16, 16, 16, 10, 24, 16, 20, 16, 16, 26, 20, 10, 12, 12, 20, 16, 18, 24, 20
    end

    package.to_stream.read
  end

  def destination_port_filter_options
    Port.where(code: %w[MXATM MXLZC MXZLO MXVER]).order(:name)
  end

  def resolved_start_date
    parse_filter_date(params[:start_date]) || default_start_date
  end

  def resolved_end_date
    parse_filter_date(params[:end_date]) || default_end_date
  end

  def resolved_date_filter_type
    requested = params[:date_filter_type].to_s
    DATE_FILTER_TYPES.include?(requested) ? requested : "created_at"
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

  def set_bl_house_line
    if action_name == "show" && !current_user&.tramitador?
      includes_associations = [
        { bl_house_line_status_histories: :user }
      ]

      includes_associations << { bl_house_line_services: [ :service_catalog, :billed_to_entity ] } unless current_user&.consolidator?

      @bl_house_line = BlHouseLine.includes(includes_associations).find(params[:id])
    elsif action_name == "edit"
      @bl_house_line = BlHouseLine.includes(bl_house_line_services: :billed_to_entity).find(params[:id])
    else
      @bl_house_line = BlHouseLine.find(params[:id])
    end
  end


  def bl_house_line_params
    params.require(:bl_house_line).permit(
      :blhouse, :partida, :cantidad, :contiene, :marcas, :peso, :volumen,
      :customs_agent_id, :customs_broker_id, :client_id, :container_id, :packaging_id, :status, :fecha_despacho,
      :clase_imo,
      :tipo_imo,
      :telex,
      :observations,
      :hidden_from_customs_agent,
      :bl_endosado_documento, :liberacion_documento, :bl_revalidado_documento, :encomienda_documento, :pago_documento,
      bl_house_line_services_attributes: [
        :id,
        :service_catalog_id,
        :quantity,
        :amount,
        :billed_to_entity_id,
        :fecha_programada,
        :observaciones,
        :factura,
        :_destroy
      ]
    )
  end

  def assign_container_from_params
    return if params[:container_number].blank?

    container = Container.find_by(number: params[:container_number])
    return unless container

    @bl_house_line.container = container
    if params[:bl_master].present? && container.bl_master.blank?
      container.update(bl_master: params[:bl_master])
    end
  end

  def handle_services_update_from_show
    attrs = show_service_attributes
    if attrs.blank?
      return redirect_to bl_house_line_path(@bl_house_line, anchor: "servicios"), alert: "No se recibieron datos del servicio."
    end

    case params[:service_action].to_s
    when "destroy"
      destroy_service_from_show(attrs)
    when "update"
      update_service_from_show(attrs)
    else
      if ActiveModel::Type::Boolean.new.cast(attrs[:_destroy])
        destroy_service_from_show(attrs)
      else
        create_service_from_show(attrs)
      end
    end
  end

  def create_service_from_show(attrs)
    service = @bl_house_line.bl_house_line_services.new(attrs.except(:id, :_destroy))

    if service.save
      redirect_to bl_house_line_path(@bl_house_line, anchor: "servicios"), notice: "Servicio agregado correctamente."
    else
      redirect_to bl_house_line_path(@bl_house_line, anchor: "servicios"), alert: service.errors.full_messages.to_sentence
    end
  end

  def destroy_service_from_show(attrs)
    service = @bl_house_line.bl_house_line_services.find_by(id: attrs[:id])
    return redirect_to(bl_house_line_path(@bl_house_line, anchor: "servicios"), alert: "Servicio no encontrado.") if service.blank?

    if service.facturado?
      redirect_to bl_house_line_path(@bl_house_line, anchor: "servicios"), alert: "No se puede eliminar un servicio facturado."
    elsif service.destroy
      redirect_to bl_house_line_path(@bl_house_line, anchor: "servicios"), notice: "Servicio eliminado correctamente."
    else
      redirect_to bl_house_line_path(@bl_house_line, anchor: "servicios"), alert: service.errors.full_messages.to_sentence
    end
  end

  def update_service_from_show(attrs)
    service = @bl_house_line.bl_house_line_services.find_by(id: attrs[:id])
    return redirect_to(bl_house_line_path(@bl_house_line, anchor: "servicios"), alert: "Servicio no encontrado.") if service.blank?

    if service.facturado?
      redirect_to bl_house_line_path(@bl_house_line, anchor: "servicios"), alert: "No se puede editar un servicio facturado."
    elsif service.update(attrs.except(:id, :_destroy))
      redirect_to bl_house_line_path(@bl_house_line, anchor: "servicios"), notice: "Servicio actualizado correctamente."
    else
      redirect_to bl_house_line_path(@bl_house_line, anchor: "servicios"), alert: service.errors.full_messages.to_sentence
    end
  end

  def show_service_attributes
    service_fields = [ :id, :service_catalog_id, :quantity, :amount, :billed_to_entity_id, :fecha_programada, :observaciones, :factura, :_destroy ]

    services_attrs = if params[:bl_house_line].is_a?(ActionController::Parameters)
      params[:bl_house_line][:bl_house_line_services_attributes]
    else
      params[:bl_house_line_services_attributes]
    end

    return {} if services_attrs.blank?

    attrs_hash = services_attrs.respond_to?(:to_unsafe_h) ? services_attrs.to_unsafe_h : services_attrs.to_h
    return {} if attrs_hash.blank?

    first_value = attrs_hash.values.first
    first_entry = first_value.is_a?(Hash) || first_value.is_a?(ActionController::Parameters) ? first_value : attrs_hash

    ActionController::Parameters.new(first_entry).permit(*service_fields).to_h.symbolize_keys
  rescue StandardError
    {}
  end

  def dispatch_date_params
    params.require(:bl_house_line).permit(:fecha_despacho)
  end

  def render_dispatch_modal(status)
    respond_to do |format|
      format.turbo_stream { render partial: "bl_house_lines/dispatch/modal", locals: { bl_house_line: @bl_house_line }, status: status }
      format.html { render partial: "bl_house_lines/dispatch/modal", locals: { bl_house_line: @bl_house_line }, status: status }
    end
  end

  def ensure_dispatch_allowed
    return true if @bl_house_line.revalidado?

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("dispatch_modal", partial: "bl_house_lines/dispatch/modal_closed")
      end
      format.html { redirect_to bl_house_lines_path, alert: "Solo puedes registrar fecha de despacho para partidas revalidadas." }
    end

    false
  end

  def reassign_params
    raw = params.require(:reassign).permit(
      :new_customs_agent_id,
      :new_customs_broker_id,
      :new_client_id
    )

    raw[:new_customs_broker_id] = raw[:new_customs_broker_id].presence || (raise ActionController::ParameterMissing, :new_customs_broker_id)
    raw[:new_client_id] = raw[:new_client_id].presence || (raise ActionController::ParameterMissing, :new_client_id)
    raw
  end

  def revalidation_params
    if params[:bl_house_line].present?
      params.require(:bl_house_line).permit(
        :customs_broker_id,
        :customs_agent_id,
        :bl_endosado_documento_validated,
        :liberacion_documento_validated,
        :encomienda_documento_validated,
        :pago_documento_validated,
        :telex
      )
    else
      {}
    end
  end


  def document_validation_flags
    return {} unless params[:bl_house_line].present?
    flags = {}
    boolean_caster = ActiveModel::Type::Boolean.new

    BlHouseLine::DOCUMENT_FIELDS.each do |doc|
      param_key = "#{doc}_validated"
      next unless params[:bl_house_line].key?(param_key)

      flags[param_key] = boolean_caster.cast(params[:bl_house_line][param_key])
    end

    flags
  end

  def documents_validated?(record)
    record.required_revalidation_documents.all? do |doc|
      record.respond_to?("#{doc}_validated") && record.public_send("#{doc}_validated")
    end
  end

  def add_history_observation(observation)
    return if observation.blank?
    history = @bl_house_line.bl_house_line_status_histories.order(created_at: :desc).first
    if history
      history.update(observations: observation)
    end
  end

  def notify_customs_agent(action)
    if @bl_house_line.customs_agent_id
      # Notify all users belonging to the customs agent entity
      receivers = User.where(entity_id: @bl_house_line.customs_agent_id)
    elsif action == "Correcciones Solicitadas"
      # For corrections, notify the user who requested the revalidation
      revalidation_history = @bl_house_line.bl_house_line_status_histories.where(status: "validar_documentos").order(created_at: :asc).first
      if revalidation_history && revalidation_history.user
        receivers = [ revalidation_history.user ]
      else
        Rails.logger.warn "BlHouseLine #{@bl_house_line.id} has no revalidation history. Notification '#{action}' not sent."
        return
      end
    else
      Rails.logger.warn "BlHouseLine #{@bl_house_line.id} has no customs_agent_id and action is not 'Correcciones Solicitadas'. Notification '#{action}' not sent."
      return
    end

    if receivers.empty?
      Rails.logger.warn "No receivers found for notification '#{action}' on BlHouseLine #{@bl_house_line.id}."
      return
    end

    receivers.each do |receiver|
      Notification.create!(
        recipient: receiver,
        actor: current_user,
        notifiable: @bl_house_line,
        action: action
      )
    end
  end

  def persist_internal_reference_observation(bl_house_line, raw_reference)
    reference = raw_reference.to_s.strip
    return if reference.blank?

    history = bl_house_line.bl_house_line_status_histories.order(changed_at: :desc, created_at: :desc, id: :desc).first
    return if history.blank?

    line = "#{BlHouseLine::INTERNAL_REFERENCE_PREFIX} #{reference}"
    lines = history.observations.to_s.split(/\r?\n/).map(&:strip).reject(&:blank?)
    lines.reject! { |entry| entry.match?(/\A#{Regexp.escape(BlHouseLine::INTERNAL_REFERENCE_PREFIX)}/i) }
    lines << line

    history.update!(observations: lines.join("\n"))
  end

  def requesting_customs_agent
    return @bl_house_line.customs_agent if @bl_house_line.customs_agent.present?

    revalidation_history = @bl_house_line
      .bl_house_line_status_histories
      .where(status: "validar_documentos")
      .order(created_at: :desc)
      .first

    candidate = revalidation_history&.user&.entity
    candidate if candidate&.role_customs_agent?
  end

  def load_reassign_collections
    selected_agent_id = params[:agent_id] || params.dig(:reassign, :new_customs_agent_id) || @bl_house_line.customs_agent_id

    @customs_agents = Entity.customs_agents.order(:name).to_a
    if @bl_house_line.customs_agent.present? && !@customs_agents.any? { |agent| agent.id == @bl_house_line.customs_agent_id }
      @customs_agents.unshift(@bl_house_line.customs_agent)
    end

    @clients = if selected_agent_id.present?
      Entity.clients.where(customs_agent_id: selected_agent_id).order(:name)
    else
      Entity.none
    end

    @customs_brokers = if selected_agent_id.present?
      AgencyBroker.includes(:broker).where(agency_id: selected_agent_id).map(&:broker).sort_by { |broker| broker.name.to_s }
    else
      []
    end
  end
end
