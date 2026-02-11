class CustomDeviseFailure < Devise::FailureApp
  def redirect_url
    Rails.application.routes.url_helpers.root_path
  end

  def respond
    if http_auth?
      http_auth
    else
      redirect
    end
  end
end
