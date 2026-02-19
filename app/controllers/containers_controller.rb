class ContainersController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized, except: :index
  before_action :set_container, only: %i[
    edit
    update
    destroy
    lifecycle_bl_master_modal
    lifecycle_bl_master_update
    lifecycle_descarga_modal
    lifecycle_descarga_update
    lifecycle_transferencia_modal
    lifecycle_transferencia_update
    lifecycle_tentativa_modal
    lifecycle_tentativa_update
    lifecycle_tarja_modal
    lifecycle_tarja_update
  ]
  before_action :set_container_for_show, only: %i[show destroy_all_bl_house_lines]

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
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize @container

    if @container.update(container_params)
      redirect_to @container, notice: "Contenedor actualizado exitosamente."
    else
      load_form_data
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @container

    if @container.destroy
      redirect_to containers_url, notice: "Contenedor eliminado exitosamente."
    else
      redirect_to containers_url, alert: "No se puede eliminar el contenedor porque tiene partidas asociadas."
    end
  end

  def destroy_all_bl_house_lines
    authorize @container

    if @container.any_bl_house_line_with_attachments?
      redirect_to @container, alert: "No se pueden eliminar las partidas porque alguna tiene documentos adjuntos."
    else
      @container.bl_house_lines.destroy_all
      redirect_to @container, notice: "Todas las partidas fueron eliminadas correctamente."
    end
  end

  def lifecycle_bl_master_modal
    authorize @container, :update?
    render_lifecycle_modal("containers/lifecycle/bl_master_modal")
  end

  def lifecycle_bl_master_update
    authorize @container, :update?

    if lifecycle_bl_master_params[:bl_master_documento].blank?
      @container.errors.add(:bl_master_documento, "debe adjuntarse")
      return render_lifecycle_modal("containers/lifecycle/bl_master_modal", :unprocessable_entity)
    end

    @container.assign_attributes(lifecycle_bl_master_params)

    if @container.save
      render_lifecycle_success("BL Master actualizado correctamente.")
    else
      render_lifecycle_modal("containers/lifecycle/bl_master_modal", :unprocessable_entity)
    end
  end

  def lifecycle_descarga_modal
    authorize @container, :update?
    render_lifecycle_modal("containers/lifecycle/descarga_modal")
  end

  def lifecycle_descarga_update
    authorize @container, :update?

    @container.assign_attributes(lifecycle_descarga_params)

    if @container.fecha_descarga.blank?
      @container.errors.add(:fecha_descarga, "no puede estar en blanco")
      return render_lifecycle_modal("containers/lifecycle/descarga_modal", :unprocessable_entity)
    end

    if @container.save
      render_lifecycle_success("Fecha de descarga guardada correctamente.")
    else
      render_lifecycle_modal("containers/lifecycle/descarga_modal", :unprocessable_entity)
    end
  end

  def lifecycle_transferencia_modal
    authorize @container, :update?
    render_lifecycle_modal("containers/lifecycle/transferencia_modal")
  end

  def lifecycle_transferencia_update
    authorize @container, :update?

    @container.assign_attributes(lifecycle_transferencia_params)

    if @container.fecha_transferencia.blank?
      @container.errors.add(:fecha_transferencia, "no puede estar en blanco")
      return render_lifecycle_modal("containers/lifecycle/transferencia_modal", :unprocessable_entity)
    end

    if @container.almacen.blank?
      @container.errors.add(:almacen, "no puede estar en blanco")
      return render_lifecycle_modal("containers/lifecycle/transferencia_modal", :unprocessable_entity)
    end

    if @container.save
      render_lifecycle_success("Cita de transferencia guardada correctamente.")
    else
      render_lifecycle_modal("containers/lifecycle/transferencia_modal", :unprocessable_entity)
    end
  end

  def lifecycle_tentativa_modal
    authorize @container, :update?
    render_lifecycle_modal("containers/lifecycle/tentativa_modal")
  end

  def lifecycle_tentativa_update
    authorize @container, :update?

    @container.assign_attributes(lifecycle_tentativa_params)

    if @container.fecha_tentativa_desconsolidacion.blank?
      @container.errors.add(:fecha_tentativa_desconsolidacion, "no puede estar en blanco")
      return render_lifecycle_modal("containers/lifecycle/tentativa_modal", :unprocessable_entity)
    end

    if @container.tentativa_turno.blank?
      @container.errors.add(:tentativa_turno, "no puede estar en blanco")
      return render_lifecycle_modal("containers/lifecycle/tentativa_modal", :unprocessable_entity)
    end

    if @container.save
      render_lifecycle_success("Fecha tentativa guardada correctamente.")
    else
      render_lifecycle_modal("containers/lifecycle/tentativa_modal", :unprocessable_entity)
    end
  end

  def lifecycle_tarja_modal
    authorize @container, :update?
    render_lifecycle_modal("containers/lifecycle/tarja_modal")
  end

  def lifecycle_tarja_update
    authorize @container, :update?

    if lifecycle_tarja_params[:tarja_documento].blank?
      @container.errors.add(:tarja_documento, "debe adjuntarse")
      return render_lifecycle_modal("containers/lifecycle/tarja_modal", :unprocessable_entity)
    end

    @container.assign_attributes(lifecycle_tarja_params)

    if @container.save
      render_lifecycle_success("Tarja actualizada correctamente.")
    else
      render_lifecycle_modal("containers/lifecycle/tarja_modal", :unprocessable_entity)
    end
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
      :voyage,
      container_services: [ :service_catalog, :billed_to_entity ],
      container_status_histories: :user
    ).find(params[:id])

    bl_ids = @container.bl_house_lines.pluck(:id)
    @bl_house_lines_docs_present = bl_ids.any? && ActiveStorage::Attachment.where(record_type: "BlHouseLine", record_id: bl_ids).exists?
  end

  def container_params
    params.require(:container).permit(
      :number,
      :status,
      :tipo_maniobra,
      :type_size,
      :consolidator_entity_id,
      :shipping_line_id,
      :vessel_id,
      :voyage_id,
      :origin_port_id,
      :bl_master,
      :fecha_descarga,
      :fecha_tentativa_desconsolidacion,
      :fecha_desconsolidacion,
      :fecha_revalidacion_bl_master,
      :fecha_transferencia,
      :tentativa_turno,
      :recinto,
      :almacen,
      :archivo_nr,
      :sello,
      :ejecutivo,
      :bl_master_documento,
      :tarja_documento,
      container_services_attributes: [
        :id,
        :service_catalog_id,
        :billed_to_entity_id,
        :fecha_programada,
        :observaciones,
        :factura,
        :_destroy
      ]
    )
  end

  def load_form_data
    @consolidators = Entity.where(is_consolidator: true).order(:name)
    @clients = Entity.clients.order(:name).to_a
    if @container&.consolidator_entity.present? && @clients.none? { |c| c.id == @container.consolidator_entity_id }
      @clients << @container.consolidator_entity
      @clients.sort_by!(&:name)
    end
    @shipping_lines = ShippingLine.alphabetical
    @vessels = Vessel.alphabetical
    @voyages = if @container&.vessel_id
      Voyage.where(vessel_id: @container.vessel_id).order(created_at: :desc, id: :desc).limit(1)
    else
      Voyage.none
    end
    @ports = Port.alphabetical
    @service_catalogs = ServiceCatalog.for_containers
    @vessels_json = Vessel.all.select(:id, :name).map { |v| { id: v.id, name: v.name } }.to_json
  end

  def per
    params[:per]&.to_i&.clamp(10, 100) || 25
  end

  def lifecycle_bl_master_params
    params.require(:container).permit(:bl_master_documento)
  end

  def lifecycle_descarga_params
    params.require(:container).permit(:fecha_descarga)
  end

  def lifecycle_transferencia_params
    params.require(:container).permit(:fecha_transferencia, :almacen)
  end

  def lifecycle_tentativa_params
    params.require(:container).permit(:fecha_tentativa_desconsolidacion, :tentativa_turno)
  end

  def lifecycle_tarja_params
    params.require(:container).permit(:tarja_documento)
  end

  def render_lifecycle_modal(partial, status = :ok)
    respond_to do |format|
      format.html { render partial:, locals: { container: @container }, status: }
      format.turbo_stream { render partial:, formats: [ :html ], locals: { container: @container }, status: }
    end
  end

  def render_lifecycle_success(message)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "container_lifecycle_modal",
          partial: "containers/lifecycle/modal_success",
          locals: { message: }
        )
      end
      format.html { redirect_to containers_path, notice: message }
    end
  end
end
