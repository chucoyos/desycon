class PackagingsController < ApplicationController
  before_action :set_packaging, only: %i[ show edit update destroy ]
  after_action :verify_authorized, except: :index

  # GET /packagings or /packagings.json
  def index
    @packagings = policy_scope(Packaging)
    authorize Packaging
  end

  # GET /packagings/1 or /packagings/1.json
  def show
    authorize @packaging
  end

  # GET /packagings/new
  def new
    @packaging = Packaging.new
    authorize @packaging
  end

  # GET /packagings/1/edit
  def edit
    authorize @packaging
  end

  # POST /packagings or /packagings.json
  def create
    @packaging = Packaging.new(packaging_params)
    authorize @packaging

    respond_to do |format|
      if @packaging.save
        format.html { redirect_to @packaging, notice: "Packaging was successfully created." }
        format.json { render :show, status: :created, location: @packaging }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @packaging.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /packagings/1 or /packagings/1.json
  def update
    authorize @packaging

    respond_to do |format|
      if @packaging.update(packaging_params)
        format.html { redirect_to @packaging, notice: "Packaging was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @packaging }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @packaging.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /packagings/1 or /packagings/1.json
  def destroy
    authorize @packaging

    @packaging.destroy!

    respond_to do |format|
      format.html { redirect_to packagings_path, notice: "Packaging was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_packaging
      @packaging = Packaging.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def packaging_params
      params.expect(packaging: [ :nombre ])
    end
end
