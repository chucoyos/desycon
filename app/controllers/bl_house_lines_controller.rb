class BlHouseLinesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bl_house_line, only: %i[show edit update destroy]
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
        :bl_revalidado_documento_attachment
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
    @clients = Entity.clients.order(:name)
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
    @clients = Entity.clients.order(:name)
    authorize @bl_house_line
  end

  # GET /bl_house_lines/1/edit
  def edit
    @customs_agents = available_customs_agents
    @service_catalogs = ServiceCatalog.for_bl_house_lines
    @clients = Entity.clients.order(:name)
    authorize @bl_house_line
  end

  # POST /bl_house_lines
  def create
    @bl_house_line = BlHouseLine.new(bl_house_line_params)
    authorize @bl_house_line

    assign_container_from_params

    if @bl_house_line.save
      redirect_to @bl_house_line, notice: "Bl house line was successfully created."
    else
      @customs_agents = available_customs_agents
      @service_catalogs = ServiceCatalog.for_bl_house_lines
      @clients = Entity.clients.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /bl_house_lines/1
  def update
    authorize @bl_house_line

    assign_container_from_params

    if @bl_house_line.update(bl_house_line_params)
      redirect_to @bl_house_line, notice: "Bl house line was successfully updated."
    else
      @customs_agents = available_customs_agents
      @service_catalogs = ServiceCatalog.for_bl_house_lines
      @clients = Entity.clients.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /bl_house_lines/1
  def destroy
    authorize @bl_house_line

    @bl_house_line.destroy
    redirect_to bl_house_lines_url, notice: "Bl house line was successfully destroyed."
  end

  private

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
      @bl_house_line = BlHouseLine.includes(
        { bl_house_line_status_histories: :user },
        { bl_house_line_services: [ :service_catalog, :billed_to_entity ] }
      ).find(params[:id])
    else
      @bl_house_line = BlHouseLine.find(params[:id])
    end
  end

  def bl_house_line_params
    params.require(:bl_house_line).permit(
      :blhouse, :partida, :cantidad, :contiene, :marcas, :peso, :volumen,
      :customs_agent_id, :client_id, :container_id, :packaging_id, :status,
      :bl_endosado_documento, :liberacion_documento, :bl_revalidado_documento, :encomienda_documento,
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
end
