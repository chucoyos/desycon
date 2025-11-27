class ShippingLinesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_shipping_line, only: %i[ show edit update destroy ]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  # GET /shipping_lines or /shipping_lines.json
  def index
    @shipping_lines = policy_scope(ShippingLine)
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
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @shipping_line.errors, status: :unprocessable_entity }
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
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @shipping_line.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /shipping_lines/1 or /shipping_lines/1.json
  def destroy
    authorize @shipping_line
    @shipping_line.destroy!

    respond_to do |format|
      format.html { redirect_to shipping_lines_path, notice: "Se eliminó la línea naviera.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_shipping_line
      @shipping_line = ShippingLine.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def shipping_line_params
      params.expect(shipping_line: [ :name ])
    end
end
