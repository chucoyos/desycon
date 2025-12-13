class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Set current user for Current attributes
  before_action :set_current_user

  # Redirect based on user role after sign in
  def after_sign_in_path_for(resource)
    if resource.customs_broker? && resource.entity&.is_customs_agent?
      customs_agents_dashboard_path
    else
      containers_path
    end
  end

  # Pundit: catch authorization errors
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def set_current_user
    Current.user = current_user
  end

  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore
    flash[:alert] = t "pundit.#{policy_name}.#{exception.query}", default: :default
    redirect_back(fallback_location: root_path)
  end
end
