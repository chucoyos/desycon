require "caxlsx"

class BlHouseLineServiceRequestsController < ApplicationController
  DATE_FILTERS = %w[requested_date scheduled_date created_at].freeze

  before_action :authenticate_user!
  after_action :verify_authorized

  def index
    authorize BlHouseLineServiceRequest
    @requests = filtered_requests.order(created_at: :desc, id: :desc)
    if params[:format] == "xlsx"
      return send_data export_xlsx(@requests), filename: "solicitudes_lazaro.xlsx",
        type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    end
    @requests = @requests.with_delivery_documents.page(params[:page]).per(25)
    @service_catalogs = ServiceCatalog.for_bl_house_lines.where("UPPER(code) LIKE ?", "%LZC").order(:name).to_a
    @customs_agents = Entity.customs_agents.order(:name).to_a
  rescue Date::Error
    render plain: "El filtro de fecha no es válido.", status: :unprocessable_content
  end

  def new
    @bl_house_line = BlHouseLine.find(params[:bl_house_line_id])
    @service_request = BlHouseLineServiceRequest.new(bl_house_line: @bl_house_line)
    authorize @service_request
    @catalogs = BlHouseLineServiceRequest.requestable_catalogs.order(:name)
  end

  def create
    @bl_house_line = BlHouseLine.find(params.require(:bl_house_line_service_request).require(:bl_house_line_id))
    @service_request = BlHouseLineServiceRequest.new(request_params)
    @service_request.assign_attributes(bl_house_line: @bl_house_line, requester: current_user, customs_agent: current_user.entity)
    authorize @service_request
    if @service_request.save
      redirect_to bl_house_line_path(@bl_house_line), notice: "Solicitud de servicio registrada."
    else
      @catalogs = BlHouseLineServiceRequest.requestable_catalogs.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def approve
    perform_review do |request|
      request.approve!(actor: current_user, date: review_params[:scheduled_date], time: review_params[:scheduled_time], notes: review_params[:notes])
    end
  end

  def reject
    perform_review { |request| request.reject!(actor: current_user, notes: review_params[:notes]) }
  end

  def reschedule
    perform_review do |request|
      request.reschedule!(actor: current_user, date: review_params[:scheduled_date], time: review_params[:scheduled_time], notes: review_params[:notes])
    end
  end

  def execute
    perform_review { |request| request.execute!(actor: current_user) }
  end

  private

  def perform_review
    request_record = BlHouseLineServiceRequest.find(params[:id])
    authorize request_record, :review?
    yield request_record
    redirect_to bl_house_line_service_requests_path, notice: "Solicitud actualizada."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to bl_house_line_service_requests_path, alert: e.record.errors.full_messages.to_sentence
  end

  def request_params
    params.require(:bl_house_line_service_request).permit(:service_catalog_id, :requested_date, :documentos_entrega)
  end

  def review_params
    params.require(:bl_house_line_service_request).permit(:scheduled_date, :scheduled_time, :notes)
  end

  def filtered_requests
    scope = BlHouseLineServiceRequest.includes(:service_catalog, :customs_agent, bl_house_line: :container)
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(service_catalog_id: params[:service_catalog_id]) if params[:service_catalog_id].present?
    scope = scope.where(customs_agent_id: params[:customs_agent_id]) if params[:customs_agent_id].present?
    date_filter = params[:date_type].presence || "requested_date"
    raise Date::Error unless DATE_FILTERS.include?(date_filter)

    start_date = Date.iso8601(params[:start_date]) if params[:start_date].present?
    end_date = Date.iso8601(params[:end_date]) if params[:end_date].present?
    if date_filter == "created_at"
      scope = scope.where("bl_house_line_service_requests.created_at >= ?", start_date.beginning_of_day) if start_date
      scope = scope.where("bl_house_line_service_requests.created_at < ?", (end_date + 1.day).beginning_of_day) if end_date
    else
      scope = scope.where("bl_house_line_service_requests.#{date_filter} >= ?", start_date) if start_date
      scope = scope.where("bl_house_line_service_requests.#{date_filter} <= ?", end_date) if end_date
    end
    if params[:blhouse].present? || params[:container].present?
      scope = scope.joins(bl_house_line: :container)
      scope = scope.where("bl_house_lines.blhouse ILIKE ?", "%#{params[:blhouse]}%") if params[:blhouse].present?
      scope = scope.where("containers.number ILIKE ?", "%#{params[:container]}%") if params[:container].present?
    end
    scope
  end

  def export_xlsx(requests)
    package = Axlsx::Package.new
    workbook = package.workbook
    styles = workbook.styles
    base = { font_name: "Calibri", sz: 11, border: { style: :thin, color: "E2E8F0" }, alignment: { vertical: :center } }
    header = styles.add_style(font_name: "Calibri", sz: 11, b: true, fg_color: "FFFFFF", bg_color: "312E81",
      alignment: { horizontal: :center, vertical: :center, wrap_text: true }, border: { style: :thin, color: "1E1B4B" })
    text = styles.add_style(base.merge(alignment: { vertical: :center, wrap_text: true }))
    centered = styles.add_style(base.merge(alignment: { horizontal: :center, vertical: :center }))
    integer = styles.add_style(base.merge(format_code: "#,##0", alignment: { horizontal: :right, vertical: :center }))
    decimal = styles.add_style(base.merge(format_code: "#,##0.00", alignment: { horizontal: :right, vertical: :center }))
    date = styles.add_style(base.merge(format_code: "yyyy-mm-dd", alignment: { horizontal: :center, vertical: :center }))
    zebra = { text: text, centered: centered, integer: integer, decimal: decimal, date: date }.transform_values do |style_id|
      style = styles.style_index[style_id]
      styles.add_style(style.merge(bg_color: "F8FAFC"))
    end
    status_styles = {
      "pending" => %w[92400E FEF3C7], "approved" => %w[1E40AF DBEAFE],
      "rejected" => %w[991B1B FEE2E2], "executed" => %w[065F46 D1FAE5]
    }.transform_values do |(font, fill)|
      styles.add_style(base.merge(b: true, fg_color: font, bg_color: fill, alignment: { horizontal: :center, vertical: :center }))
    end

    workbook.add_worksheet(name: "Solicitudes", page_setup: { orientation: :landscape, fit_to_width: 1, fit_to_height: 0 }) do |sheet|
      sheet.sheet_view.show_grid_lines = false
      sheet.add_row [ "Solicitud", "BL", "Contenedor", "Almacén", "Agencia", "Servicio", "Cantidad", "Peso (kg)", "Volumen (m³)", "Embalaje", "Estado", "Fecha programada", "Hora" ],
        style: header, height: 30
      widths = [ 11, 20, 16, 24, 30, 46, 11, 13, 14, 20, 14, 18, 9 ]
      row_number = 0
      requests.preload(bl_house_line: :packaging).find_each do |request|
        line = request.bl_house_line
        alt = row_number.odd?
        row_number += 1
        pick = ->(key) { alt ? zebra[key] : { text: text, centered: centered, integer: integer, decimal: decimal, date: date }[key] }
        values = [ request.id, line.blhouse, line.container&.number, line.container&.almacen, request.customs_agent.name, request.service_catalog.display_name,
          line.cantidad, line.peso&.to_f, line.volumen&.to_f, line.packaging&.nombre,
          BlHouseLineServiceRequest::STATUS_LABELS.fetch(request.status), request.scheduled_date, request.scheduled_time&.strftime("%H:%M") ]
        lines = values.zip(widths).map { |value, width| [ (value.to_s.length / (width * 0.9)).ceil, 1 ].max }.max
        sheet.add_row values,
          style: [ pick.(:centered), pick.(:text), pick.(:centered), pick.(:text), pick.(:text), pick.(:text), pick.(:integer), pick.(:decimal),
            pick.(:decimal), pick.(:text), status_styles.fetch(request.status), pick.(:date), pick.(:centered) ],
          height: 12 + (lines * 14)
      end
      sheet.column_widths(*widths)
      sheet.sheet_view.pane do |pane|
        pane.state = :frozen
        pane.y_split = 1
        pane.top_left_cell = "A2"
        pane.active_pane = :bottom_right
      end
      sheet.auto_filter = "A1:M#{row_number + 1}"
    end
    package.to_stream.read
  end
end
