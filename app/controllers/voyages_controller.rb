class VoyagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_voyage, only: %i[show edit update destroy]
  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  def index
    voyages = policy_scope(Voyage)

    if params[:vessel_id].present?
      voyages = voyages.where(vessel_id: params[:vessel_id])
    end

    @voyages = voyages.includes(:vessel, :origin_port, :destination_port).order(:viaje)
    authorize Voyage

    respond_to do |format|
      format.html
      format.json do
        render json: @voyages.map { |voyage|
          {
            id: voyage.id,
            viaje: voyage.viaje,
            voyage_type: voyage.voyage_type,
            destination_port_id: voyage.destination_port_id,
            destination_port_name: voyage.destination_port&.name,
            destination_port_display: voyage.destination_port&.display_name,
            origin_port_id: voyage.origin_port_id,
            origin_port_name: voyage.origin_port&.name,
            origin_port_display: voyage.origin_port&.display_name,
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
      :origin_port_id,
      :destination_port_id,
      :vessel_id
    )
  end
end
