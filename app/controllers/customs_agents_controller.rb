class CustomsAgentsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_customs_agent

  def dashboard
    @bl_house_lines = BlHouseLine.where(customs_agent: current_user.entity)
                                 .includes(:container, :client)
                                 .order(created_at: :desc)
  end

  private

  def ensure_customs_agent
    unless current_user.customs_broker? && current_user.entity&.is_customs_agent?
      redirect_to containers_path, alert: "No tienes permisos para acceder a esta sección"
    end
  end
end
