class CustomsAgentsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_customs_agent

  def dashboard
    if params[:blhouse].present?
      bl_house_line = BlHouseLine.where(customs_agent: current_user.entity)
                                .or(BlHouseLine.where(customs_agent: nil))
                                .where("LOWER(blhouse) = ?", params[:blhouse].strip.downcase)
                                .first
      if bl_house_line
        redirect_to edit_bl_house_line_path(bl_house_line)
        return
      else
        flash[:alert] = "BL House no encontrado."
      end
    end

    @bl_house_lines = BlHouseLine.where(customs_agent: current_user.entity)
                                 .or(BlHouseLine.where(customs_agent: nil))
                                 .includes(:container, :client, :customs_agent, :bl_house_line_status_histories, :bl_endosado_documento_attachment, :liberacion_documento_attachment, :bl_revalidado_documento_attachment, :encomienda_documento_attachment)
                                 .order(created_at: :desc)
  end

  private

  def ensure_customs_agent
    unless current_user.customs_broker? && current_user.entity&.is_customs_agent?
      redirect_to containers_path, alert: "No tienes permisos para acceder a esta sección"
    end
  end
end
