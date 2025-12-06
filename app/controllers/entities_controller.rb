class EntitiesController < ApplicationController
  before_action :set_entity, only: [ :show, :edit, :update, :destroy ]
  before_action :load_patents, only: [ :show ]

  def index
    @entities = Entity.includes(:fiscal_profile, :customs_agent_patents)
                      .order(:name)
                      .page(params[:page])
  end

  def show
  end

  def new
    @entity = Entity.new
    # Ensure at least one address field is available for new entities
    @entity.addresses.build
  end

  def new_address
    @entity = Entity.new
    respond_to do |format|
      format.turbo_stream
    end
  end

  def edit
    # Ensure at least one address field is available for editing
    @entity.addresses.build if @entity.addresses.empty?
  end

  def create
    @entity = Entity.new(entity_params)

    # Handle duplicate addresses for new entities
    if @entity.new_record? && @entity.addresses.size > 1
      @entity.addresses = [ @entity.addresses.last ]
    end

    if @entity.save
      redirect_to @entity, notice: "Entidad creada exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @entity.update(entity_params)
      redirect_to @entity, notice: "Entidad actualizada exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @entity.destroy
    redirect_to entities_path, notice: "Entidad eliminada exitosamente."
  end

  private

  def set_entity
    @entity = Entity.includes(:addresses, :fiscal_profile, :customs_agent_patents).find(params.expect(:id))
  end

  def load_patents
    # Patents are already loaded via includes in set_entity
    # This callback exists for potential future use
  end

  def entity_params
    params.require(:entity).permit(
      :name,
      :is_consolidator,
      :is_customs_agent,
      :is_forwarder,
      :is_client,
      fiscal_profile_attributes: [
        :id, :rfc, :razon_social, :regimen, :uso_cfdi, :forma_pago, :metodo_pago, :_destroy
      ],
      addresses_attributes: [
        :id, :calle, :numero_exterior, :numero_interior, :colonia, :municipio, :localidad,
        :estado, :codigo_postal, :pais, :email, :tipo, :_destroy
      ],
      customs_agent_patents_attributes: [
        :id, :patent_number, :_destroy
      ]
    )
  end
end
