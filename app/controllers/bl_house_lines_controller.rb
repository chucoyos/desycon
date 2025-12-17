class BlHouseLinesController < ApplicationController
  before_action :set_bl_house_line, only: %i[show edit update destroy]
  after_action :verify_authorized, except: :index

  # GET /bl_house_lines
  def index
    scope = policy_scope(BlHouseLine).includes(:client)

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
    authorize @bl_house_line
  end

  # GET /bl_house_lines/1/edit
  def edit
    @customs_agents = available_customs_agents
    authorize @bl_house_line
  end

  # POST /bl_house_lines
  def create
    @bl_house_line = BlHouseLine.new(bl_house_line_params)
    authorize @bl_house_line

    if @bl_house_line.save
      redirect_to @bl_house_line, notice: "Bl house line was successfully created."
    else
      @customs_agents = available_customs_agents
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /bl_house_lines/1
  def update
    authorize @bl_house_line

    if @bl_house_line.update(bl_house_line_params)
      redirect_to @bl_house_line, notice: "Bl house line was successfully updated."
    else
      @customs_agents = available_customs_agents
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

  def set_bl_house_line
    if action_name == "show"
      @bl_house_line = BlHouseLine.includes(bl_house_line_status_histories: :user).find(params[:id])
    else
      @bl_house_line = BlHouseLine.find(params[:id])
    end
  end

  def bl_house_line_params
    params.require(:bl_house_line).permit(
      :blhouse, :partida, :cantidad, :contiene, :marcas, :peso, :volumen,
      :customs_agent_id, :client_id, :container_id, :packaging_id, :status,
      :bl_endosado_documento, :liberacion_documento, :bl_revalidado_documento, :encomienda_documento
    )
  end
end
