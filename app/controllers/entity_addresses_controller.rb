class EntityAddressesController < ApplicationController
  before_action :set_entity

  def create
    @address = @entity.addresses.build(address_params)

    if @address.save
      flash.now[:notice] = "Dirección agregada exitosamente."
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to edit_entity_path(@entity), notice: "Dirección agregada exitosamente." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @address = @entity.addresses.find(params[:id])

    if @address.update(address_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to edit_entity_path(@entity), notice: "Dirección actualizada exitosamente." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @address = @entity.addresses.find(params[:id])
    @address.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to edit_entity_path(@entity), notice: "Dirección eliminada exitosamente." }
    end
  end

  private

  def set_entity
    @entity = Entity.find(params[:entity_id])
  end

  def address_params
    params.require(:address).permit(
      :calle, :numero_exterior, :numero_interior, :colonia, :municipio,
      :localidad, :estado, :codigo_postal, :pais, :email, :tipo
    )
  end
end
