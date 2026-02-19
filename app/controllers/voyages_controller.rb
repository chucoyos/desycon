class VoyagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_voyage, only: %i[show edit update destroy]
  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  def index
    voyages = policy_scope(Voyage)

    voyages = voyages.where(vessel_id: params[:vessel_id]) if params[:vessel_id].present?
    voyages = voyages.where(voyage_type: params[:voyage_type]) if params[:voyage_type].present?
    voyages = voyages.where(destination_port_id: params[:destination_port_id]) if params[:destination_port_id].present?
    if params[:search].present?
      voyages = voyages.where("voyages.viaje ILIKE ?", "%#{params[:search].strip}%")
    end

    per_page = params[:per].to_i.positive? ? params[:per].to_i : 10

    voyages_with_associations = voyages.includes(:vessel, :destination_port)

    if ActiveModel::Type::Boolean.new.cast(params[:latest_only])
      voyages_with_associations = voyages_with_associations.order(created_at: :desc, id: :desc).limit(1)
    else
      voyages_with_associations = voyages_with_associations.order(:viaje)
    end

    @voyages = voyages_with_associations.page(params[:page]).per(per_page)
    @vessels = Vessel.alphabetical
    @ports = Port.alphabetical
    authorize Voyage

    respond_to do |format|
      format.html
      format.json do
        render json: voyages_with_associations.map { |voyage|
          {
            id: voyage.id,
            viaje: voyage.viaje,
            voyage_type: voyage.voyage_type,
            destination_port_id: voyage.destination_port_id,
            destination_port_name: voyage.destination_port&.name,
            destination_port_display: voyage.destination_port&.display_name,
            ata: voyage.ata,
            eta: voyage.eta,
            inicio_operacion: voyage.inicio_operacion,
            fin_operacion: voyage.fin_operacion,
            vessel_id: voyage.vessel_id,
            vessel_name: voyage.vessel&.name
          }
        }
      end
    end
  end

  def show
    authorize @voyage
  end

  def new
    @voyage = Voyage.new
    authorize @voyage
    load_form_data
  end

  def edit
    authorize @voyage
    load_form_data
  end

  def create
    @voyage = Voyage.new(voyage_params)
    authorize @voyage

    if @voyage.save
      redirect_to @voyage, notice: "Viaje creado correctamente."
    else
      load_form_data
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize @voyage

    if @voyage.update(voyage_params)
      redirect_to @voyage, notice: "Viaje actualizado correctamente."
    else
      load_form_data
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @voyage

    if @voyage.destroy
      redirect_to voyages_path, notice: "Viaje eliminado correctamente."
    else
      redirect_to @voyage, alert: "No se puede eliminar el viaje porque tiene contenedores asociados."
    end
  end

  private

  def set_voyage
    @voyage = Voyage.find(params[:id])
  end

  def load_form_data
    @vessels = Vessel.alphabetical
    @ports = Port.alphabetical
  end

  def voyage_params
    params.require(:voyage).permit(
      :viaje,
      :voyage_type,
      :ata,
      :eta,
      :inicio_operacion,
      :fin_operacion,
      :destination_port_id,
      :vessel_id
    )
  end
end
