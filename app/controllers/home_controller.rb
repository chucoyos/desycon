class HomeController < ApplicationController
  def index
    redirect_to default_signed_in_path if user_signed_in?
  end
end
