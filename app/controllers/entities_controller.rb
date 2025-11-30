class EntitiesController < ApplicationController
  before_action :set_entity, only: [ :show, :edit, :update, :destroy ]

  def index
    @entities = Entity.includes(:addresses, :fiscal_profile, :customs_agent_patents)
                      .order(:name)
                      .page(params[:page])
  end

  def show
  end

  def new
    @entity = Entity.new
    @entity.build_fiscal_profile
    @entity.addresses.build
  end

  def edit
  end

  def create
    @entity = Entity.new(entity_params)

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
    @entity = Entity.find(params.expect(:id))
  end

  def entity_params
    params.expect(entity: [
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
    ])
  end
end
