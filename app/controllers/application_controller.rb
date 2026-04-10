class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Set current user for Current attributes
  before_action :set_current_user
  before_action :redirect_disabled_user
  before_action :redirect_restricted_access_user
  before_action :set_restricted_access_notice_context

  helper_method :show_restricted_access_notice?, :restricted_access_notice_invoices,
                :restricted_access_notice_total_count

  # Redirect based on user role after sign in
  def after_sign_in_path_for(resource)
    default_signed_in_path(resource)
  end

  def after_sign_out_path_for(_resource_or_scope)
    root_path
  end

  # Pundit: catch authorization errors
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  # Catch-all 404 handler for unmatched routes
  def not_found
    if turbo_frame_request?
      frame_id = request.headers["Turbo-Frame"].presence || "modal"
      return render(
        partial: "shared/turbo_frame_not_found",
        locals: { frame_id: frame_id, message: "El recurso solicitado ya no existe o fue movido." },
        status: :not_found
      )
    end

    render file: Rails.root.join("public", "404.html"), status: :not_found, layout: false
  end

  private

  def set_current_user
    Current.user = current_user
  end

  def redirect_disabled_user
    return unless current_user
    return if devise_controller?
    return if controller_path == "blocked_users"
    return if current_user.role&.admin?

    if current_user.disabled?
      flash[:alert] = "Tu cuenta está deshabilitada. Contacta al administrador para recuperar el acceso."
      sign_out current_user
      redirect_to blocked_users_path and return
    end
  end

  def redirect_restricted_access_user
    return unless current_user
    return if devise_controller?
    return unless restricted_customs_agency_user?
    return if restricted_access_whitelisted_route?

    flash[:alert] = "Tu acceso está restringido temporalmente por facturas vencidas. Solo puedes adjuntar comprobantes y consultar facturas relacionadas con tu agencia."
    redirect_to new_customs_agents_payment_evidence_path and return
  end

  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore
    flash[:alert] = t("pundit.#{policy_name}.#{exception.query}", default: t("pundit.default"))
    redirect_back(fallback_location: default_signed_in_path)
  end

  def default_signed_in_path(user = current_user)
    return root_path unless user

    if user.customs_broker? && user.entity&.role_customs_agent? && user.entity&.restricted_access_enabled?
      return new_customs_agents_payment_evidence_path
    end

    if user.customs_broker? && user.entity&.role_customs_agent?
      customs_agents_dashboard_path
    else
      containers_path
    end
  end

  def restricted_customs_agency_user?
    return false unless current_user

    !current_user.admin_or_executive? &&
      current_user.entity&.role_customs_agent? &&
      current_user.entity&.restricted_access_enabled?
  end

  def restricted_access_whitelisted_route?
    allowed_routes = {
      "customs_agent_payment_evidences" => %w[new create],
      "invoices" => %w[index show],
      "tutorials" => %w[index]
    }

    actions = allowed_routes[controller_path]
    actions.present? && actions.include?(action_name)
  end

  def set_restricted_access_notice_context
    return unless restricted_customs_agency_user?

    overdue_invoices = overdue_unpaid_invoices_for_restricted_notice
    @restricted_access_notice_total_count = overdue_invoices.size
    @restricted_access_notice_invoices = overdue_invoices.first(5).map do |invoice|
      {
        id: invoice.id,
        label: invoice_label_for_notice(invoice),
        issued_at: invoice.issued_at
      }
    end
  end

  def show_restricted_access_notice?
    restricted_customs_agency_user? && current_user.entity&.restricted_access_for_overdue_rule?
  end

  def restricted_access_notice_invoices
    @restricted_access_notice_invoices || []
  end

  def restricted_access_notice_total_count
    @restricted_access_notice_total_count || 0
  end

  def overdue_unpaid_invoices_for_restricted_notice
    Invoice
      .joins(:receiver_entity)
      .where(
        "invoices.customs_agent_id = :agency_id OR entities.customs_agent_id = :agency_id",
        agency_id: current_user.entity_id
      )
      .where.not(status: "cancelled")
      .where.not(issued_at: nil)
      .distinct
      .sort_by(&:issued_at)
      .select do |invoice|
        overdue_by_business_hours_for_restricted_notice?(invoice) && invoice.payment_status != "paid"
      end
  end

  def overdue_by_business_hours_for_restricted_notice?(invoice)
    deadline = CustomsAgents::BusinessHoursService.add_weekday_hours(
      from_time: invoice.issued_at,
      hours: CustomsAgents::RestrictionEvaluatorService::BUSINESS_HOURS_TO_RESTRICT
    )

    Time.zone.now >= deadline
  end

  def invoice_label_for_notice(invoice)
    serie = invoice.provider_response.to_h["serie"].presence || invoice.payload_snapshot.to_h["serie"].presence
    folio = invoice.provider_response.to_h["folio"].presence ||
            invoice.provider_response.to_h["noComprobante"].presence ||
            invoice.provider_response.to_h["numeroComprobante"].presence ||
            invoice.facturador_comprobante_id&.to_s

    return "Factura #{serie} #{folio}" if serie.present? && folio.present?
    return "Factura #{folio}" if folio.present?
    return "Factura #{serie}" if serie.present?

    "Factura ##{invoice.id}"
  end
end
