class AgencyBrokersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_entity

  def create
    authorize @entity, :manage_brokers?

    if @entity.is_customs_agent?
      broker_id = params[:broker_id]
      if broker_id.present?
        AgencyBroker.find_or_create_by!(agency_id: @entity.id, broker_id: broker_id)
        redirect_to @entity, notice: "Broker vinculado exitosamente."
      else
        redirect_to @entity, alert: "Selecciona un broker para vincular."
      end
    elsif @entity.is_customs_broker?
      agency_id = params[:agency_id]
      if agency_id.present?
        AgencyBroker.find_or_create_by!(agency_id: agency_id, broker_id: @entity.id)
        redirect_to @entity, notice: "Agencia vinculada exitosamente."
      else
        redirect_to @entity, alert: "Selecciona una agencia para vincular."
      end
    else
      redirect_to @entity, alert: "La entidad no tiene el rol correcto para vincular."
    end
  end

  def destroy
    authorize @entity, :manage_brokers?

    link = if @entity.is_customs_agent?
      @entity.agency_broker_links_as_agency.find(params[:id])
    else
      @entity.agency_broker_links_as_broker.find(params[:id])
    end
    link.destroy
    notice = @entity.is_customs_agent? ? "Broker desvinculado exitosamente." : "Agencia desvinculada exitosamente."
    redirect_to @entity, notice: notice
  end

  private

  def set_entity
    @entity = Entity.find(params[:entity_id])
  end
end
