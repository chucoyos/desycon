module Admin
  class ManagementDashboardController < ApplicationController
    before_action :authenticate_user!
    after_action :verify_authorized

    def index
      authorize :management_dashboard, :index?

      @selected_year = resolved_year
      @available_years = ((Time.zone.today.year - 4)..Time.zone.today.year).to_a.reverse

      @revenue_metrics = Admin::ManagementDashboard::RevenueMonthlyService.call(year: @selected_year)
      @operations_metrics = Admin::ManagementDashboard::OperationsMonthlyService.call(year: @selected_year)
    end

    private

    def resolved_year
      requested_year = params[:year].to_i
      current_year = Time.zone.today.year
      min_year = current_year - 4

      return current_year if requested_year.zero?
      return min_year if requested_year < min_year
      return current_year if requested_year > current_year

      requested_year
    end
  end
end
