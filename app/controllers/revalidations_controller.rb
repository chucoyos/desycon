class RevalidationsController < ApplicationController
  before_action :authenticate_user!

  def show
    @bl_house_line = BlHouseLine.find(params[:id])

    # Authorize: only the customs agent associated with this BL House Line can view it
    authorize_customs_agent_access
    return if performed?

    respond_to do |format|
      format.pdf do
        pdf = RevalidationPdf.new(@bl_house_line).render
        send_data pdf,
                  filename: revalidation_pdf_filename,
                  type: "application/pdf",
                  disposition: "inline"
      end
    end
  end

  private

  def authorize_customs_agent_access
    return if current_user.respond_to?(:admin_or_executive?) && current_user.admin_or_executive?

    unless current_user.entity_id == @bl_house_line.customs_agent_id
      redirect_to root_path, alert: "No tienes permisos para acceder a este documento."
    end
  end

  def revalidation_pdf_filename
    normalized_blhouse = @bl_house_line.blhouse.to_s.strip.parameterize(separator: "_")
    parts = [ "revalidacion" ]
    parts << normalized_blhouse if normalized_blhouse.present?
    parts << @bl_house_line.id
    "#{parts.join("_")}.pdf"
  end
end
