class PortsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_port, only: %i[ show edit update destroy ]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  # GET /ports or /ports.json
  def index
    per = params[:per].to_i
    allowed = [ 10, 25, 50, 100 ]
    per = 10 unless allowed.include?(per)
    @per_page = per
    ports = policy_scope(Port)
    ports = ports.where("name ILIKE ? OR code ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    @ports = ports.alphabetical.page(params[:page]).per(per)
  end

  # GET /ports/1 or /ports/1.json
  def show
    authorize @port
  end

  # GET /ports/new
  def new
    @port = Port.new
    authorize @port
  end

  # GET /ports/1/edit
  def edit
    authorize @port
  end

  # POST /ports or /ports.json
  def create
    @port = Port.new(port_params)
    authorize @port

    respond_to do |format|
      if @port.save
        format.html { redirect_to @port, notice: "Se creó el puerto." }
        format.json { render :show, status: :created, location: @port }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @port.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /ports/1 or /ports/1.json
  def update
    authorize @port

    respond_to do |format|
      if @port.update(port_params)
        format.html { redirect_to @port, notice: "Se actualizó el puerto.", status: :see_other }
        format.json { render :show, status: :ok, location: @port }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @port.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /ports/1 or /ports/1.json
  def destroy
    authorize @port
    @port.destroy!

    respond_to do |format|
      format.html { redirect_to ports_path, notice: "Se eliminó el puerto.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_port
      @port = Port.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def port_params
      params.require(:port).permit(:name, :code, :country_code)
    end
end
