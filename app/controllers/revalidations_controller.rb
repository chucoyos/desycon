class RevalidationsController < ApplicationController
  before_action :authenticate_user!

  def show
    @bl_house_line = BlHouseLine.find(params[:id])

    # Authorize: only the customs agent associated with this BL House Line can view it
    authorize_customs_agent_access

    respond_to do |format|
      format.pdf do
        pdf = RevalidationPdf.new(@bl_house_line).render
        send_data pdf,
                  filename: "revalidacion_#{@bl_house_line.id}.pdf",
                  type: "application/pdf",
                  disposition: "inline"
      end
    end
  end

  private

  def authorize_customs_agent_access
    unless current_user.entity_id == @bl_house_line.customs_agent_id
      redirect_to root_path, alert: "No tienes permisos para acceder a este documento."
    end
  end
end
