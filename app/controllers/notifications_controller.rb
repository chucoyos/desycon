class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    per = params[:per].to_i
    allowed = [ 10, 25, 50, 100 ]
    per = 10 unless allowed.include?(per)
    @per_page = per

    @notifications = current_user.notifications.includes(:notifiable, actor: :entity)

    # Aplicar filtros de búsqueda
    apply_filters

    @notifications = @notifications.recent.page(params[:page]).per(per)
  end

  def mark_as_read
    @notification = current_user.notifications.find(params[:id])
    @notification.mark_as_read!

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace(@notification, partial: "notifications/notification", locals: { notification: @notification }),
          turbo_stream.replace("notifications_count", partial: "notifications/count", locals: { unread_count: current_user.notifications.unread.count })
        ]
      }
      format.html { redirect_back fallback_location: notifications_path }
    end
  end

  def destroy
    @notification = current_user.notifications.find(params[:id])
    @notification.destroy

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.remove(@notification),
          turbo_stream.replace("notifications_count", partial: "notifications/count", locals: { unread_count: current_user.notifications.unread.count })
        ]
      }
      format.html { redirect_back fallback_location: notifications_path, notice: "Notificación eliminada." }
    end
  end

  private

  def apply_filters
    # Filtro de búsqueda por texto
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @notifications = @notifications.joins("LEFT JOIN bl_house_lines ON bl_house_lines.id = notifications.notifiable_id AND notifications.notifiable_type = 'BlHouseLine'").where(
        "bl_house_lines.blhouse ILIKE ?",
        search_term
      )
    end

    # Filtro por estado de lectura
    case params[:read_status]
    when "read"
      @notifications = @notifications.where.not(read_at: nil)
    when "unread"
      @notifications = @notifications.where(read_at: nil)
    end

    # Filtro por tipo de acción
    if params[:action_type].present?
      @notifications = @notifications.where(action: params[:action_type])
    end

    # Filtro por rango de fechas
    if params[:start_date].present? && params[:end_date].present?
      start_date = Date.parse(params[:start_date]) rescue nil
      end_date = Date.parse(params[:end_date]) rescue nil

      if start_date && end_date
        @notifications = @notifications.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
      end
    elsif params[:start_date].present?
      start_date = Date.parse(params[:start_date]) rescue nil
      if start_date
        @notifications = @notifications.where("created_at >= ?", start_date.beginning_of_day)
      end
    elsif params[:end_date].present?
      end_date = Date.parse(params[:end_date]) rescue nil
      if end_date
        @notifications = @notifications.where("created_at <= ?", end_date.end_of_day)
      end
    end
  end
end
