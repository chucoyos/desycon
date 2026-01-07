class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @notifications = current_user.notifications.includes(:notifiable, actor: :entity).recent
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
end
