class VesselsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_vessel, only: %i[ show edit update destroy ]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  # GET /vessels or /vessels.json
  def index
    per = params[:per].to_i
    allowed = [ 10, 25, 50, 100 ]
    per = 10 unless allowed.include?(per)
    @per_page = per
    vessels = policy_scope(Vessel)
    vessels = vessels.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    @vessels = vessels.alphabetical.page(params[:page]).per(per)
  end

  # GET /vessels/1 or /vessels/1.json
  def show
    authorize @vessel
  end

  # GET /vessels/new
  def new
    @vessel = Vessel.new
    authorize @vessel
  end

  # GET /vessels/1/edit
  def edit
    authorize @vessel
  end

  # POST /vessels or /vessels.json
  def create
    @vessel = Vessel.new(vessel_params)
    authorize @vessel

    respond_to do |format|
      if @vessel.save
        format.html { redirect_to @vessel, notice: "Se creó el buque." }
        format.json { render :show, status: :created, location: @vessel }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @vessel.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /vessels/1 or /vessels/1.json
  def update
    authorize @vessel

    respond_to do |format|
      if @vessel.update(vessel_params)
        format.html { redirect_to @vessel, notice: "Se actualizó el buque.", status: :see_other }
        format.json { render :show, status: :ok, location: @vessel }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @vessel.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /vessels/1 or /vessels/1.json
  def destroy
    authorize @vessel

    respond_to do |format|
      if @vessel.destroy
        format.html { redirect_to vessels_path, notice: "Se eliminó el buque.", status: :see_other }
        format.json { head :no_content }
      else
        format.html { redirect_to vessels_path, alert: "No se puede eliminar el buque porque tiene contenedores asociados." }
        format.json { render json: @vessel.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_vessel
      @vessel = Vessel.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def vessel_params
      params.require(:vessel).permit(:name)
    end
end
