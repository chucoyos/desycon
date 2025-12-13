class BlHouseLinesController < ApplicationController
  before_action :set_bl_house_line, only: %i[show edit update destroy]
  after_action :verify_authorized, except: :index

  # GET /bl_house_lines
  def index
    @bl_house_lines = policy_scope(BlHouseLine)
    authorize BlHouseLine
  end

  # GET /bl_house_lines/1
  def show
    authorize @bl_house_line
  end

  # GET /bl_house_lines/new
  def new
    @bl_house_line = BlHouseLine.new
    @bl_house_line.container_id = params[:container_id] if params[:container_id].present?
    authorize @bl_house_line
  end

  # GET /bl_house_lines/1/edit
  def edit
    authorize @bl_house_line
  end

  # POST /bl_house_lines
  def create
    @bl_house_line = BlHouseLine.new(bl_house_line_params)
    authorize @bl_house_line

    if @bl_house_line.save
      redirect_to @bl_house_line, notice: "Bl house line was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /bl_house_lines/1
  def update
    authorize @bl_house_line

    if @bl_house_line.update(bl_house_line_params)
      redirect_to @bl_house_line, notice: "Bl house line was successfully updated."
    else
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
