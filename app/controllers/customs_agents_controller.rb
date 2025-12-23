class CustomsAgentsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_customs_agent

  def dashboard
    # Scope used for the revalidation form: only unassigned or assigned to this agent
    revalidation_scope = BlHouseLine.where(customs_agent: [current_user.entity, nil])
                                     .includes(:container, :client)

    search_blhouse = params[:revalidation_blhouse].presence || params[:blhouse].presence

    if search_blhouse
      bl_house_line = revalidation_scope.where("LOWER(blhouse) = ?", search_blhouse.strip.downcase).first
      if bl_house_line
        redirect_to edit_bl_house_line_path(bl_house_line)
        return
      else
        flash[:alert] = "BL House no encontrado."
      end
    end

    # Listing scope: assignments for this agent or unassigned
    base_scope = BlHouseLine.where(customs_agent: [current_user.entity, nil])
                             .includes(
                               :container,
                               :client,
                               :bl_house_line_status_histories,
                               :bl_endosado_documento_attachment,
                               :liberacion_documento_attachment,
                               :bl_revalidado_documento_attachment,
                               :encomienda_documento_attachment
                             )
                             .order(created_at: :desc)

    filtered_scope = base_scope

    if params[:filter_blhouse].present?
      filtered_scope = filtered_scope.where("bl_house_lines.blhouse ILIKE ?", "%#{params[:filter_blhouse]}%")
    end

    if params[:filter_container_number].present?
      filtered_scope = filtered_scope.joins(:container).where("containers.number ILIKE ?", "%#{params[:filter_container_number]}%")
    end

    if params[:status].present?
      allowed_statuses = %w[activo documentos_rechazados documentos_ok revalidado]
      if allowed_statuses.include?(params[:status])
        filtered_scope = filtered_scope.where(status: params[:status])
      end
    end

    @bl_house_lines = filtered_scope.page(params[:page]).per(params[:per] || 20)

    # Stats (use unfiltered scope)
    @total_assignments = base_scope.count
    @pending_assignments = base_scope.where.not(status: [ :finalizado, :revalidado ]).count
    @completed_assignments = base_scope.where(status: [ :finalizado, :revalidado ]).count
    @problem_assignments = base_scope.where(status: [ :instrucciones_pendientes, :pendiente_pagos_locales ]).count
  end

  private

  def ensure_customs_agent
    unless current_user.customs_broker? && current_user.entity&.is_customs_agent?
      redirect_to containers_path, alert: "No tienes permisos para acceder a esta sección"
    end
  end
end
