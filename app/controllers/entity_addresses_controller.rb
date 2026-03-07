class EntityAddressesController < ApplicationController
  before_action :set_entity
  before_action :authorize_entity_management

  def create
    @address = @entity.addresses.build(address_params)
    @address.tipo = "matriz" if @address.tipo.blank? && @entity.addresses.matriz.none?

    if @address.save
      flash[:notice] = "Dirección agregada exitosamente."
      @entity.reload # Reload to ensure addresses association is fresh
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to edit_entity_path(@entity), notice: "Dirección agregada exitosamente." }
      end
    else
      respond_to do |format|
        format.turbo_stream
        format.html { render :new, status: :unprocessable_content }
      end
    end
  end

  def update
    @address = @entity.addresses.find(params[:id])

    if @address.update(address_params)
      flash.now[:notice] = "Dirección actualizada exitosamente."
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @entity, notice: "Dirección actualizada exitosamente." }
      end
    else
      respond_to do |format|
        format.turbo_stream
        format.html { render :edit, status: :unprocessable_content }
      end
    end
  end

  def edit
    @address = @entity.addresses.find(params[:id])
    respond_to do |format|
      format.html { render :edit }
    end
  end

  def destroy
    @address = @entity.addresses.find(params[:id])

    if prevent_fiscal_address_removal?(@address)
      error_message = "No se puede eliminar el único domicilio fiscal de la entidad."

      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = error_message
          render :destroy, status: :unprocessable_entity
        end
        format.html { redirect_to @entity, alert: error_message }
      end
      return
    end

    @address.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to edit_entity_path(@entity), notice: "Dirección eliminada exitosamente." }
    end
  end

  private

  def authorize_entity_management
    authorize @entity, :update?
  end

  def set_entity
    @entity = Entity.find(params[:entity_id])
  end

  def address_params
    params.require(:address).permit(
      :calle, :numero_exterior, :numero_interior, :colonia, :municipio,
      :localidad, :estado, :codigo_postal, :pais, :email, :tipo
    )
  end

  def prevent_fiscal_address_removal?(address)
    return false unless address.tipo == "matriz"
    return false unless @entity.fiscal_profile.present?

    @entity.addresses.where(tipo: "matriz").where.not(id: address.id).none?
  end
end
