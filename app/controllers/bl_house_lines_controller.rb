class BlHouseLinesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bl_house_line, only: %i[show edit update destroy revalidation_approval approve_revalidation]
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
        :bl_revalidado_documento_attachment,
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

  # DELETE /bl_house_lines/1
  def destroy
    authorize @bl_house_line

    @bl_house_line.destroy
    redirect_to bl_house_lines_url, notice: "Partida eliminada correctamente."
  end

  # GET /bl_house_lines/1/revalidation_approval
  def revalidation_approval
    authorize @bl_house_line, :approve_revalidation?
    @customs_agents = Entity.customs_agents.order(:name)
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
      # If we are assigning, it implies documents are OK.
      @bl_house_line.status = "documentos_ok"

      # Ensure attributes are assigned
      @bl_house_line.assign_attributes(revalidation_params)

      if @bl_house_line.save
        begin
          date_str = params[:tentative_date]
          time_period = params[:time_period]

          if date_str.present?
             full_observation = "FECHA TENTATIVA PARA EL INICIO DE REVALIDACION EL DIA #{date_str} POR LA #{time_period}."
             # Use a safer history lookup or create one if missing
             history = @bl_house_line.bl_house_line_status_histories.order(created_at: :desc).first
             if history
               history.update(observations: full_observation)
             else
               # Fallback: create history if callback somehow failed
               @bl_house_line.bl_house_line_status_histories.create(
                 status: @bl_house_line.status,
                 changed_at: Time.current,
                 user: current_user,
                 observations: full_observation
               )
             end
          end

          notify_customs_agent("Documentación Aprobada")

          respond_to do |format|
             format.turbo_stream { render turbo_stream: turbo_stream.replace("approval_modal", partial: "bl_house_lines/approval/modal_closed") }
             format.html { redirect_to bl_house_lines_path, notice: "Revalidación aprobada y agente asignado." }
          end
        rescue => e
          Rails.logger.error "Error in approve_revalidation (assign): #{e.message}"
          @bl_house_line.errors.add(:base, "Ocurrió un error al procesar la aprobación: #{e.message}")
          render :revalidation_approval, status: :unprocessable_entity
        end
      else
        Rails.logger.warn "Validation errors in approve_revalidation: #{@bl_house_line.errors.full_messages}"
        render :revalidation_approval, status: :unprocessable_entity
      end
    end
  end

  private

  def load_clients
    if customs_agent_user?
      @clients = current_user.entity.clients.order(:name)
    else
      @clients = Entity.clients.order(:name)
    end
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
        { bl_house_line_status_histories: :user }
      ]

      # Only include services for non-customs agents
      unless customs_agent_user?
        includes_associations << { bl_house_line_services: [ :service_catalog, :billed_to_entity ] }
      end

      @bl_house_line = BlHouseLine.includes(includes_associations).find(params[:id])
    else
      @bl_house_line = BlHouseLine.find(params[:id])
    end
  end

  def bl_house_line_params
    params.require(:bl_house_line).permit(
      :blhouse, :partida, :cantidad, :contiene, :marcas, :peso, :volumen,
      :customs_agent_id, :client_id, :container_id, :packaging_id, :status,
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

  def revalidation_params
    if params[:bl_house_line].present?
      params.require(:bl_house_line).permit(:customs_agent_patent_id, :customs_agent_id)
    else
      {}
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
    unless @bl_house_line.customs_agent_id
      Rails.logger.warn "BlHouseLine #{@bl_house_line.id} has no customs_agent_id. Notification '#{action}' not sent."
      return
    end

    # Notify all users belonging to the customs agent entity
    receivers = User.where(entity_id: @bl_house_line.customs_agent_id)

    if receivers.empty?
      Rails.logger.warn "No users found for entity_id: #{@bl_house_line.customs_agent_id}. Notification '#{action}' not sent."
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
end
