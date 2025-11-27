class ShippingLinesController < ApplicationController
  before_action :set_shipping_line, only: %i[ show edit update destroy ]

  # GET /shipping_lines or /shipping_lines.json
  def index
    @shipping_lines = ShippingLine.all
  end

  # GET /shipping_lines/1 or /shipping_lines/1.json
  def show
  end

  # GET /shipping_lines/new
  def new
    @shipping_line = ShippingLine.new
  end

  # GET /shipping_lines/1/edit
  def edit
  end

  # POST /shipping_lines or /shipping_lines.json
  def create
    @shipping_line = ShippingLine.new(shipping_line_params)

    respond_to do |format|
      if @shipping_line.save
        format.html { redirect_to @shipping_line, notice: "Shipping line was successfully created." }
        format.json { render :show, status: :created, location: @shipping_line }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @shipping_line.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /shipping_lines/1 or /shipping_lines/1.json
  def update
    respond_to do |format|
      if @shipping_line.update(shipping_line_params)
        format.html { redirect_to @shipping_line, notice: "Shipping line was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @shipping_line }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @shipping_line.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /shipping_lines/1 or /shipping_lines/1.json
  def destroy
    @shipping_line.destroy!

    respond_to do |format|
      format.html { redirect_to shipping_lines_path, notice: "Shipping line was successfully destroyed.", status: :see_other }
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
