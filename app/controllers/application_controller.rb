class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Set current user for Current attributes
  before_action :set_current_user
  before_action :redirect_disabled_user

  # Redirect based on user role after sign in
  def after_sign_in_path_for(resource)
    default_signed_in_path(resource)
  end

  # Pundit: catch authorization errors
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Catch-all 404 handler for unmatched routes
  def not_found
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

  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore
    flash[:alert] = t "pundit.#{policy_name}.#{exception.query}", default: :default
    redirect_back(fallback_location: default_signed_in_path)
  end

  def default_signed_in_path(user = current_user)
    return root_path unless user

    if user.customs_broker? && user.entity&.is_customs_agent?
      customs_agents_dashboard_path
    else
      containers_path
    end
  end
end
