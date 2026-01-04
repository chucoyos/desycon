class CustomsAgentsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_customs_agent

  def dashboard
    # Scope used for the revalidation form: only unassigned or assigned to this agent
    revalidation_scope = revalidation_lookup_scope.includes(:container)

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

    # Listing scope: only BL House Lines assigned to this agent
    base_scope = BlHouseLine.where(customs_agent: current_user.entity)
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

  def revalidation_modal
    search_blhouse = params[:revalidation_blhouse].to_s.strip.downcase.presence || params[:blhouse].to_s.strip.downcase.presence

    unless turbo_frame_request?
      redirect_to customs_agents_dashboard_path(revalidation_blhouse: search_blhouse), alert: "Solicita la revalidación desde el dashboard." and return
    end

    if search_blhouse.blank?
      render partial: "customs_agents/revalidation_not_found", status: :unprocessable_entity and return
    end

    @bl_house_line = revalidation_lookup_scope.includes(:container)
                                               .where("LOWER(blhouse) = ?", search_blhouse)
                                               .first

    if @bl_house_line
      render partial: "customs_agents/revalidation_modal", locals: { bl_house_line: @bl_house_line, customs_agents: revalidation_customs_agents, clients: revalidation_clients }
    else
      render partial: "customs_agents/revalidation_not_found", status: :not_found
    end
  end

  def revalidation_update
    unless turbo_frame_request?
      redirect_to customs_agents_dashboard_path, alert: "No se pudo procesar la solicitud en modal." and return
    end

    @bl_house_line = revalidation_lookup_scope.find_by(id: params[:id])

    unless @bl_house_line
      render partial: "customs_agents/revalidation_not_found", status: :not_found and return
    end

    assign_revalidation_agent(@bl_house_line)

    if @bl_house_line.update(revalidation_params)
      render partial: "customs_agents/revalidation_success", locals: { bl_house_line: @bl_house_line }
    else
      render partial: "customs_agents/revalidation_modal", status: :unprocessable_entity, locals: { bl_house_line: @bl_house_line, customs_agents: revalidation_customs_agents, clients: revalidation_clients }
    end
  end

  private

  def revalidation_lookup_scope
    BlHouseLine.where(customs_agent: [ current_user.entity, nil ])
  end

  def assign_revalidation_agent(bl_house_line)
    return if bl_house_line.customs_agent_id.present?

    bl_house_line.customs_agent = current_user.entity
  end

  def revalidation_params
    permitted = params.require(:bl_house_line).permit(
      :customs_agent_id,
      :client_id,
      :bl_endosado_documento,
      :liberacion_documento,
      :encomienda_documento
    )
    permitted[:customs_agent_id] = sanitize_customs_agent_id(permitted[:customs_agent_id])
    permitted[:client_id] = sanitize_client_id(permitted[:client_id])
    permitted
  rescue ActionController::ParameterMissing
    {}
  end

  def sanitize_customs_agent_id(agent_id)
    allowed_ids = revalidation_customs_agents.pluck(:id)
    candidate = agent_id.presence&.to_i
    return current_user.entity_id if candidate.blank?

    allowed_ids.include?(candidate) ? candidate : current_user.entity_id
  end

  def sanitize_client_id(client_id)
    return nil if client_id.blank?

    allowed_ids = revalidation_clients.pluck(:id)
    candidate = client_id.to_i
    allowed_ids.include?(candidate) ? candidate : nil
  end

  def revalidation_customs_agents
    Entity.where(id: current_user.entity_id)
  end

  def revalidation_clients
    Entity.clients.where(customs_agent_id: current_user.entity_id).order(:name)
  end

  def ensure_customs_agent
    unless current_user.customs_broker? && current_user.entity&.is_customs_agent?
      redirect_to containers_path, alert: "No tienes permisos para acceder a esta sección"
    end
  end
end
