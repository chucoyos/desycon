class ShippingLinesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_shipping_line, only: %i[ show edit update destroy ]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  # GET /shipping_lines or /shipping_lines.json
  def index
    per = params[:per].to_i
    allowed = [ 10, 25, 50, 100 ]
    per = 10 unless allowed.include?(per)
    @per_page = per

    @shipping_lines = policy_scope(ShippingLine).order(:name)

    # Filtro de búsqueda
    if params[:search].present?
      @shipping_lines = @shipping_lines.where("name ILIKE ?", "%#{params[:search]}%")
    end

    @shipping_lines = @shipping_lines.page(params[:page]).per(per)
  end

  # GET /shipping_lines/1 or /shipping_lines/1.json
  def show
    authorize @shipping_line
  end

  # GET /shipping_lines/new
  def new
    @shipping_line = ShippingLine.new
    authorize @shipping_line
  end

  # GET /shipping_lines/1/edit
  def edit
    authorize @shipping_line
  end

  # POST /shipping_lines or /shipping_lines.json
  def create
    @shipping_line = ShippingLine.new(shipping_line_params)
    authorize @shipping_line

    respond_to do |format|
      if @shipping_line.save
        format.html { redirect_to @shipping_line, notice: "Se creó la línea naviera." }
        format.json { render :show, status: :created, location: @shipping_line }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @shipping_line.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /shipping_lines/1 or /shipping_lines/1.json
  def update
    authorize @shipping_line

    respond_to do |format|
      if @shipping_line.update(shipping_line_params)
        format.html { redirect_to @shipping_line, notice: "Se actualizó la línea naviera.", status: :see_other }
        format.json { render :show, status: :ok, location: @shipping_line }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @shipping_line.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /shipping_lines/1 or /shipping_lines/1.json
  def destroy
    authorize @shipping_line

    if @shipping_line.destroy
      respond_to do |format|
        format.html { redirect_to shipping_lines_path, notice: "Se eliminó la línea naviera.", status: :see_other }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to shipping_lines_path, alert: "No se puede eliminar la línea naviera porque tiene buques o contenedores asociados." }
        format.json { render json: @shipping_line.errors, status: :unprocessable_content }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_shipping_line
      @shipping_line = ShippingLine.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def shipping_line_params
      params.require(:shipping_line).permit(:name, :scac_code)
    end
end
