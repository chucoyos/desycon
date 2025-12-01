class ContainersController < ApplicationController
  before_action :set_container, only: %i[edit update destroy]
  before_action :set_container_for_show, only: %i[show]

  def index
    @containers = policy_scope(Container)
                    .with_associations
                    .recent
                    .page(params[:page])
                    .per(per)

    # Filtros opcionales
    @containers = @containers.by_status(params[:status]) if params[:status].present?
    @containers = @containers.by_tipo_maniobra(params[:tipo_maniobra]) if params[:tipo_maniobra].present?
    @containers = @containers.by_consolidator(params[:consolidator_id]) if params[:consolidator_id].present?
    @containers = @containers.by_shipping_line(params[:shipping_line_id]) if params[:shipping_line_id].present?

    # Búsqueda por número
    if params[:search].present?
      @containers = @containers.where("number ILIKE ?", "%#{params[:search]}%")
    end

    authorize Container
  end

  def show
    authorize @container
  end

  def new
    @container = Container.new
    authorize @container
    load_form_data
  end

  def edit
    authorize @container
    load_form_data
  end

  def create
    @container = Container.new(container_params)
    authorize @container

    if @container.save
      redirect_to @container, notice: "Contenedor creado exitosamente."
    else
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @container

    if @container.update(container_params)
      redirect_to @container, notice: "Contenedor actualizado exitosamente."
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @container
    @container.destroy!
    redirect_to containers_url, notice: "Contenedor eliminado exitosamente."
  end

  private

  def set_container
    @container = Container.find(params[:id])
  end

  def set_container_for_show
    @container = Container.includes(
      :consolidator_entity,
      :shipping_line,
      :vessel,
      :port,
      :container_services,
      container_status_histories: :user
    ).find(params[:id])
  end

  def container_params
    params.require(:container).permit(
      :number,
      :status,
      :tipo_maniobra,
      :consolidator_entity_id,
      :shipping_line_id,
      :vessel_id,
      :port_id,
      :bl_master,
      :fecha_arribo,
      :viaje,
      :recinto,
      :archivo_nr,
      :sello,
      :cont_key,
      :bl_master_documento,
      :tarja_documento,
      container_services_attributes: [
        :id, :cliente, :cantidad, :servicio, :fecha_programada,
        :observaciones, :referencia, :factura, :_destroy
      ]
    )
  end

  def load_form_data
    @consolidators = Entity.where(is_consolidator: true).order(:name)
    @shipping_lines = ShippingLine.alphabetical
    @vessels = Vessel.alphabetical
    @ports = Port.alphabetical
    @vessels_json = Vessel.all.select(:id, :name, :shipping_line_id).map { |v| { id: v.id, name: v.name, shipping_line_id: v.shipping_line_id } }.to_json
  end

  def per
    params[:per]&.to_i&.clamp(10, 100) || 25
  end
end
