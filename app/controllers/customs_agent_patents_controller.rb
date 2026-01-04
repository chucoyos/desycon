class CustomsAgentPatentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_entity
  before_action :set_patent, only: [ :edit, :update, :destroy ]

  def index
    @patents = @entity.customs_agent_patents.order(:patent_number)
    authorize @entity, :manage_patents?
  end

  def new
    @patent = @entity.customs_agent_patents.build
    authorize @entity, :manage_patents?
  end

  def create
    @patent = @entity.customs_agent_patents.build(patent_params)
    authorize @entity, :manage_patents?

    if @patent.save
      flash.now[:notice] = "Patente agregada exitosamente."
      respond_to do |format|
        format.turbo_stream
        format.html do
          if current_user.admin?
            redirect_to entity_path(@entity), notice: "Patente agregada exitosamente."
          else
            redirect_to entity_customs_agent_patents_path(@entity), notice: "Patente agregada exitosamente."
          end
        end
      end
    else
      respond_to do |format|
        format.turbo_stream
        format.html { render :new, status: :unprocessable_content }
      end
    end
  end

  def edit
    authorize @entity, :manage_patents?
    if request.xhr?
      render partial: "edit_form", locals: { entity: @entity, patent: @patent }
    end
  end

  def update
    authorize @entity, :manage_patents?

    if @patent.update(patent_params)
      flash.now[:notice] = "Patente actualizada exitosamente."
      respond_to do |format|
        format.turbo_stream
        format.html do
          if current_user.admin?
            redirect_to entity_path(@entity), notice: "Patente actualizada exitosamente."
          else
            redirect_to entity_customs_agent_patents_path(@entity), notice: "Patente actualizada exitosamente."
          end
        end
      end
    else
      respond_to do |format|
        format.turbo_stream
        format.html { render :edit, status: :unprocessable_content }
      end
    end
  end

  def destroy
    authorize @entity, :manage_patents?
    @patent.destroy

    respond_to do |format|
      format.html { redirect_back fallback_location: entity_customs_agent_patents_path(@entity), notice: "Patente eliminada exitosamente." }
    end
  end

  private

  def set_entity
    @entity = Entity.find(params[:entity_id])
  end

  def set_patent
    @patent = @entity.customs_agent_patents.find(params[:id])
  end

  def patent_params
    params.require(:customs_agent_patent).permit(:patent_number)
  end
end
