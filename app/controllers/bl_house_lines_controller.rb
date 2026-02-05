class BlHouseLinesController < ApplicationController
  IMPORT_ROW_LIMIT = 500
  IMPORT_SIZE_LIMIT = 2.megabytes

  before_action :authenticate_user!
  before_action :set_bl_house_line, only: %i[show edit update destroy revalidation_approval approve_revalidation documents reassign perform_reassign reassign_patents]
  after_action :verify_authorized, except: :index

  # GET /bl_house_lines
  def index
    scope = policy_scope(BlHouseLine)
      .includes(
        :client,
        :bl_house_line_status_histories,
        :bl_endosado_documento_attachment,
        :liberacion_documento_attachment,
        :encomienda_documento_attachment,
        :pago_documento_attachment
      )

    @status_filter_options = customs_agent_user? ? customs_agent_statuses : BlHouseLine.statuses.keys

    # Filters
    if params[:blhouse].present?
      scope = scope.where("bl_house_lines.blhouse ILIKE ?", "%#{params[:blhouse]}%")
    end

    if params[:container_number].present?
      scope = scope.joins(:container).where("containers.number ILIKE ?", "%#{params[:container_number]}%")
    end

    if params[:client_id].present?
      scope = scope.where(client_id: params[:client_id])
    end

    if params[:customs_agent_id].present?
      scope = scope.where(customs_agent_id: params[:customs_agent_id])
    end

    if params[:status].present? && @status_filter_options.include?(params[:status])
      scope = scope.where(status: params[:status])
    end

    if params[:hidden].present? && !customs_agent_user?
      case params[:hidden]
      when "hidden"
        scope = scope.where(hidden_from_customs_agent: true)
      when "visible"
        scope = scope.where(hidden_from_customs_agent: false)
      end
    end

    @bl_house_lines = scope.page(params[:page]).per(params[:per] || 20)

    # Data for filters
    load_clients
    @customs_agents = available_customs_agents
  end

  # GET /bl_house_lines/1
  def show
    authorize @bl_house_line
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

    assign_container_from_params

    if @bl_house_line.update(bl_house_line_params)
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

  # DELETE /bl_house_lines/1
  def destroy
    authorize @bl_house_line

    @bl_house_line.destroy
    redirect_to bl_house_lines_url, notice: "Partida eliminada correctamente."
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
            turno_label = case tentative_turno.to_s.downcase
            when "manana", "mañana" then "MAÑANA"
            when "tarde" then "TARDE"
            else tentative_turno.to_s.upcase.presence || "MAÑANA"
            end

            full_observation = "FECHA TENTATIVA PARA EL INICIO DE REVALIDACION EL DIA #{tentative_date} POR LA #{turno_label}."
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
      new_customs_agent_patent_id: reassign_params[:new_customs_agent_patent_id],
      new_client_id: reassign_params[:new_client_id],
      hide_original: reassign_params[:hide_original],
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

  # GET /bl_house_lines/1/reassign_patents
  def reassign_patents
    authorize @bl_house_line, :reassign?
    load_reassign_collections

    render turbo_stream: [
      turbo_stream.replace(
        "patent_select",
        view_context.turbo_frame_tag("patent_select") do
          view_context.render(
            partial: "bl_house_lines/patent_select",
            locals: {
              patents: @customs_agent_patents,
              selected_patent_id: params[:selected_patent_id]
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

    if current_user.customs_broker? && current_user.entity&.is_customs_agent?
      Entity.where(id: current_user.entity_id)
    else
      Entity.customs_agents
    end
  end

  def customs_agent_user?
    current_user&.customs_broker? && current_user.entity&.is_customs_agent?
  end

  def customs_agent_statuses
    %w[activo documentos_rechazados documentos_ok revalidado despachado]
  end

  def set_bl_house_line
    if action_name == "show"
      includes_associations = [
        { bl_house_line_status_histories: :user },
        { bl_house_line_services: [ :service_catalog, :billed_to_entity ] }
      ]


      @bl_house_line = BlHouseLine.includes(includes_associations).find(params[:id])
    else
      @bl_house_line = BlHouseLine.find(params[:id])
    end
  end

  def bl_house_line_params
    params.require(:bl_house_line).permit(
      :blhouse, :partida, :cantidad, :contiene, :marcas, :peso, :volumen,
      :customs_agent_id, :client_id, :container_id, :packaging_id, :status, :fecha_despacho,
      :clase_imo,
      :tipo_imo,
      :hidden_from_customs_agent,
      :bl_endosado_documento, :liberacion_documento, :bl_revalidado_documento, :encomienda_documento, :pago_documento,
      bl_house_line_services_attributes: [
        :id,
        :service_catalog_id,
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

  def reassign_params
    raw = params.require(:reassign).permit(
      :new_customs_agent_id,
      :new_customs_agent_patent_id,
      :new_client_id,
      :hide_original
    )

    raw[:new_client_id] = raw[:new_client_id].presence || (raise ActionController::ParameterMissing, :new_client_id)

    raw[:hide_original] = ActiveModel::Type::Boolean.new.cast(raw.fetch(:hide_original, true))
    raw
  end

  def revalidation_params
    if params[:bl_house_line].present?
      params.require(:bl_house_line).permit(
        :customs_agent_patent_id,
        :customs_agent_id,
        :bl_endosado_documento_validated,
        :liberacion_documento_validated,
        :encomienda_documento_validated,
        :pago_documento_validated
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
    BlHouseLine::DOCUMENT_FIELDS.all? do |doc|
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

  def requesting_customs_agent
    return @bl_house_line.customs_agent if @bl_house_line.customs_agent.present?

    revalidation_history = @bl_house_line
      .bl_house_line_status_histories
      .where(status: "validar_documentos")
      .order(created_at: :desc)
      .first

    candidate = revalidation_history&.user&.entity
    candidate if candidate&.is_customs_agent?
  end

  def load_reassign_collections
    @customs_agents = Entity.customs_agents.where.not(id: @bl_house_line.customs_agent_id).order(:name)
    selected_agent_id = params[:agent_id] || params.dig(:reassign, :new_customs_agent_id)

    @clients = if selected_agent_id.present?
      Entity.clients.where(customs_agent_id: selected_agent_id).order(:name)
    else
      Entity.none
    end

    @customs_agent_patents = if selected_agent_id.present?
      CustomsAgentPatent.where(entity_id: selected_agent_id).order(:patent_number)
    else
      CustomsAgentPatent.none
    end
  end
end
