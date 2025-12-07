class CustomsAgentPatentsController < ApplicationController
  before_action :set_entity

  def create
    @patent = @entity.customs_agent_patents.build(patent_params)

    if @patent.save
      flash.now[:notice] = "Patente agregada exitosamente."
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to edit_entity_path(@entity), notice: "Patente agregada exitosamente." }
      end
    else
      respond_to do |format|
        format.turbo_stream
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    @patent = @entity.customs_agent_patents.find(params[:id])

    if @patent.update(patent_params)
      flash.now[:notice] = "Patente actualizada exitosamente."
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to edit_entity_path(@entity), notice: "Patente actualizada exitosamente." }
      end
    else
      respond_to do |format|
        format.turbo_stream
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @patent = @entity.customs_agent_patents.find(params[:id])
    @patent.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to edit_entity_path(@entity), notice: "Patente eliminada exitosamente." }
    end
  end

  private

  def set_entity
    @entity = Entity.find(params[:entity_id])
  end

  def patent_params
    params.require(:customs_agent_patent).permit(:patent_number)
  end
end
