class ServiceCatalogsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_service_catalog, only: %i[ show edit update destroy ]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    @service_catalogs = policy_scope(ServiceCatalog).order(:applies_to, :name)

    if params[:applies_to].present? && ServiceCatalog::APPLIES_TO.include?(params[:applies_to])
      @service_catalogs = @service_catalogs.where(applies_to: params[:applies_to])
    end

    if params[:active].present?
      case params[:active]
      when "true"
        @service_catalogs = @service_catalogs.where(active: true)
      when "false"
        @service_catalogs = @service_catalogs.where(active: false)
      end
    end

    if params[:search].present?
      term = "%#{params[:search]}%"
      @service_catalogs = @service_catalogs.where("name ILIKE ? OR code ILIKE ?", term, term)
    end

    @service_catalogs = @service_catalogs.page(params[:page]).per(params[:per]&.to_i&.clamp(10, 100) || 25)
  end

  def show
    authorize @service_catalog
  end

  def new
    @service_catalog = ServiceCatalog.new
    authorize @service_catalog
  end

  def edit
    authorize @service_catalog
  end

  def create
    @service_catalog = ServiceCatalog.new(service_catalog_params)
    authorize @service_catalog

    if @service_catalog.save
      redirect_to @service_catalog, notice: "Servicio creado correctamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @service_catalog

    if @service_catalog.update(service_catalog_params)
      redirect_to @service_catalog, notice: "Servicio actualizado correctamente.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @service_catalog

    if @service_catalog.destroy
      redirect_to service_catalogs_path, notice: "Servicio eliminado correctamente.", status: :see_other
    else
      redirect_to service_catalogs_path, alert: "No se pudo eliminar el servicio.", status: :see_other
    end
  end

  private

  def set_service_catalog
    @service_catalog = ServiceCatalog.find(params[:id])
  end

  def service_catalog_params
    params.require(:service_catalog).permit(:name, :code, :applies_to, :amount, :currency, :active)
  end
end
