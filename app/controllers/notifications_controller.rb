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
    preload_notification_relations(@notifications)
    preload_latest_observations(@notifications)
  end

  def mark_as_read
    @notification = current_user.notifications.includes(:notifiable, actor: :entity).find(params[:id])
    preload_notification_relations([ @notification ])
    preload_latest_observations([ @notification ])
    @notification.mark_as_read!

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace(@notification, partial: "notifications/notification", locals: { notification: @notification, viewer: current_user }),
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

  def destroy_all
    removed_count = current_user.notifications.count
    current_user.notifications.destroy_all

    redirect_to notifications_path, notice: if removed_count.positive?
      "Se descartaron #{removed_count} notificaciones."
                                            else
      "No hay notificaciones para descartar."
                                            end
  end

  private

  def preload_notification_relations(notifications)
    records = Array(notifications)
    return if records.empty?

    bl_house_line_notifications = records.select { |notification| notification.notifiable_type == "BlHouseLine" }

    notifications_requiring_container = bl_house_line_notifications.select do |notification|
      notification.action == "Documentación Aprobada"
    end

    if notifications_requiring_container.any?
      bl_house_lines_for_container = notifications_requiring_container.filter_map(&:notifiable)
      ActiveRecord::Associations::Preloader.new(records: bl_house_lines_for_container, associations: :container).call if bl_house_lines_for_container.any?
    end

    evidences = records.filter_map do |notification|
      notification.notifiable if notification.notifiable_type == "InvoicePaymentEvidence"
    end
    return if evidences.empty?

    ActiveRecord::Associations::Preloader.new(records: evidences, associations: :invoices).call

    evidences_without_links = evidences.select do |evidence|
      evidence.association(:invoices).loaded? && evidence.invoices.empty? && evidence.invoice_id.present?
    end
    return if evidences_without_links.empty?

    ActiveRecord::Associations::Preloader.new(records: evidences_without_links, associations: :invoice).call
  end

  def preload_latest_observations(notifications)
    records = Array(notifications)
    @latest_observations_by_bl_house_line_id = {}
    return if records.empty?

    relevant_bl_house_line_ids = records.filter_map do |notification|
      next unless notification.notifiable_type == "BlHouseLine"
      next unless [ "Correcciones Solicitadas", "Documentación Aprobada" ].include?(notification.action)

      notification.notifiable_id
    end.uniq

    return if relevant_bl_house_line_ids.empty?

    latest_rows = BlHouseLineStatusHistory
      .where(bl_house_line_id: relevant_bl_house_line_ids)
      .select(:bl_house_line_id, :observations, :created_at, :id)
      .order(bl_house_line_id: :asc, created_at: :desc, id: :desc)

    latest_rows.each do |row|
      @latest_observations_by_bl_house_line_id[row.bl_house_line_id] ||= row.observations
    end
  end

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
