class EntitiesController < ApplicationController
  before_action :set_entity, only: [ :show, :edit, :update, :destroy ]
  before_action :load_patents, only: [ :show ]

  def index
    @entities = Entity.includes(:fiscal_profile)
                      .preload(:customs_agent_patents)
                      .order(:name)
                      .page(params[:page])
  end

  def show
  end

  def new
    @entity = Entity.new
    # Build associated objects for the form
    @entity.build_fiscal_profile
    @entity.addresses.build
    @entity.customs_agent_patents.build
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
      # Rebuild associated objects for form display when validation fails
      @entity.build_fiscal_profile unless @entity.fiscal_profile
      @entity.addresses.build if @entity.addresses.empty?
      @entity.customs_agent_patents.build if @entity.customs_agent_patents.empty? && @entity.is_customs_agent?
      render :new, status: :unprocessable_entity
    end
  end

  def update
    respond_to do |format|
      if @entity.update(entity_params)
        @entity.reload # Reload to ensure associations are fresh
        flash.now[:notice] = "Entidad actualizada exitosamente."
        format.turbo_stream do
          case params[:modal]
          when "address"
            render turbo_stream: [
              turbo_stream.replace("addresses_container", partial: "entities/addresses_section", locals: { entity: @entity }),
              turbo_stream.replace("flash_messages", partial: "shared/flash_messages", locals: { flash: flash }),
              turbo_stream.remove("address-modal")
            ]
          when "patent"
            render turbo_stream: [
              turbo_stream.replace("patents_container", partial: "entities/patents_section", locals: { entity: @entity }),
              turbo_stream.replace("flash_messages", partial: "shared/flash_messages", locals: { flash: flash }),
              turbo_stream.remove("patent-modal")
            ]
          when "fiscal"
            render turbo_stream: [
              turbo_stream.replace("fiscal_profile_container", partial: "entities/fiscal_profile_section", locals: { entity: @entity }),
              turbo_stream.replace("flash_messages", partial: "shared/flash_messages", locals: { flash: flash }),
              turbo_stream.replace("fiscal-modal", partial: "entities/fiscal_modal", locals: { entity: @entity })
            ]
          when "name"
            render turbo_stream: [
              turbo_stream.replace("entity_header", partial: "entities/header", locals: { entity: @entity }),
              turbo_stream.replace("flash_messages", partial: "shared/flash_messages", locals: { flash: flash }),
              turbo_stream.replace("name-modal", partial: "entities/name_modal", locals: { entity: @entity })
            ]
          else
            render turbo_stream: [
              turbo_stream.replace("entity_show", partial: "entities/show", locals: { entity: @entity }),
              turbo_stream.remove("#{params[:modal]}-modal")
            ]
          end
        end
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("#{params[:modal]}_form", partial: "entities/modal_form", locals: { entity: @entity, modal: params[:modal] })
        end
      end
    end
  end

  def destroy
    @entity.destroy
    redirect_to entities_path, notice: "Entidad eliminada exitosamente."
  end

  private

  def set_entity
    @entity = Entity.includes(:addresses, :fiscal_profile).find(params.expect(:id))
  end

  def load_patents
    # Patents are loaded conditionally in set_entity for customs agents only
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
