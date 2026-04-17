class ServicesController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized

  def index
    authorize Invoice, :issue_manual?

    @selected_start_date = resolved_start_date
    @selected_end_date = resolved_end_date
    @filter_start_date = [ @selected_start_date, @selected_end_date ].min
    @filter_end_date = [ @selected_start_date, @selected_end_date ].max

    @selected_container_number = params[:container_number].to_s.strip.first(11).presence
    @selected_blhouse = params[:blhouse].to_s.strip.presence
    @selected_customs_agency = params[:customs_agency].to_s.strip.presence

    unified_rows = container_service_rows + bl_house_line_service_rows
    unified_rows.sort_by! { |row| [ row[:created_at] || Time.at(0), row[:service_id] ] }
    unified_rows.reverse!

    @services = Kaminari.paginate_array(unified_rows).page(params[:page]).per(per_page)
  end

  def issue_batch
    authorize Invoice, :issue_manual?

    serviceables = find_serviceables_from_tokens
    if serviceables.blank?
      return redirect_back fallback_location: services_path, alert: "Selecciona al menos un servicio válido."
    end

    result = Facturador::IssueGroupedServicesService.call(serviceables: serviceables, actor: current_user)

    if result.success?
      if result.invoice.present?
        redirect_to invoice_path(result.invoice), notice: "Emisión agrupada encolada/ejecutada correctamente."
      else
        redirect_back fallback_location: services_path, notice: "Emisión agrupada encolada/ejecutada correctamente."
      end
    else
      redirect_back fallback_location: services_path, alert: "No fue posible emitir CFDI agrupado: #{result.error_message}"
    end
  rescue Facturador::Error => e
    redirect_back fallback_location: services_path, alert: "Error al emitir CFDI agrupado: #{e.message}"
  end

  private

  def per_page
    requested = params[:per].to_i
    return 20 if requested <= 0

    [ requested, 100 ].min
  end

  def container_service_rows
    container_services_scope.map do |service|
      latest_invoice_id = service.latest_invoice&.id

      {
        token: "ContainerService:#{service.id}",
        type: "ContainerService",
        service_id: service.id,
        container_id: service.container_id,
        invoice_id: latest_invoice_id,
        service_name: service.service_catalog&.name.presence || "-",
        status_label: service.facturado? ? "Facturado" : "Proforma",
        facturado: service.facturado?,
        container_number: service.container&.number.presence || "-",
        blhouse: "-",
        agency_name: agency_name_for_container_service(service),
        client_name: client_name_for_container_service(service),
        amount: service.amount,
        currency: service.currency || "MXN",
        created_at: service.created_at
      }
    end
  end

  def bl_house_line_service_rows
    services = bl_house_line_services_scope.to_a
    service_ids = services.map(&:id)
    container_numbers_by_service_id = if service_ids.empty?
      {}
    else
      BlHouseLineService
        .joins(bl_house_line: :container)
        .where(id: service_ids)
        .pluck("bl_house_line_services.id", "containers.number")
        .to_h
    end

    services.map do |service|
      bl_house_line = service.bl_house_line
      client_name = bl_house_line&.client&.name
      billed_to_name = service.billed_to_entity&.name
      latest_invoice_id = service.latest_invoice&.id

      {
        token: "BlHouseLineService:#{service.id}",
        type: "BlHouseLineService",
        service_id: service.id,
        bl_house_line_id: service.bl_house_line_id,
        invoice_id: latest_invoice_id,
        service_name: service.service_catalog&.name.presence || "-",
        status_label: service.facturado? ? "Facturado" : "Proforma",
        facturado: service.facturado?,
        container_number: container_numbers_by_service_id[service.id].presence || "-",
        blhouse: bl_house_line&.blhouse.presence || "-",
        agency_name: bl_house_line&.customs_agent&.name.presence || "-",
        client_name: client_name.presence || billed_to_name.presence || "-",
        amount: service.amount,
        currency: service.currency || "MXN",
        created_at: service.created_at
      }
    end
  end

  def container_services_scope
    # If the user filters by BL House, only BL-partida services should be listed.
    return ContainerService.none if @selected_blhouse.present?
    # Container services do not belong to a customs agency in this listing.
    return ContainerService.none if @selected_customs_agency.present?

    scope = ContainerService
      .includes(:billed_to_entity, :service_catalog, container: { bl_house_lines: [ :client ] })

    if @selected_container_number.present?
      scope = scope.joins(:container).where("containers.number ILIKE ?", "%#{@selected_container_number}%")
    end

    scope = scope.where(created_at: @filter_start_date.beginning_of_day..@filter_end_date.end_of_day)

    scope.distinct
  end

  def bl_house_line_services_scope
    scope = BlHouseLineService
      .includes(:billed_to_entity, :service_catalog, bl_house_line: [ :customs_agent, :client ])

    if @selected_container_number.present?
      scope = scope.joins(bl_house_line: :container).where("containers.number ILIKE ?", "%#{@selected_container_number}%")
    end

    if @selected_blhouse.present?
      scope = scope.joins(:bl_house_line).where("bl_house_lines.blhouse ILIKE ?", "%#{@selected_blhouse}%")
    end

    if @selected_customs_agency.present?
      scope = scope.joins(:bl_house_line).where(bl_house_lines: { customs_agent_id: customs_agent_ids_for_filter })
    end

    scope = scope.where(created_at: @filter_start_date.beginning_of_day..@filter_end_date.end_of_day)

    scope.distinct
  end

  def resolved_start_date
    parse_filter_date(params[:start_date]) || default_start_date
  end

  def resolved_end_date
    parse_filter_date(params[:end_date]) || default_end_date
  end

  def parse_filter_date(value)
    return nil if value.blank?

    Date.parse(value)
  rescue ArgumentError
    nil
  end

  def default_start_date
    1.month.ago.to_date
  end

  def default_end_date
    Date.current
  end

  def customs_agent_ids_for_filter
    @customs_agent_ids_for_filter ||= begin
      query = "%#{@selected_customs_agency}%"
      Entity.customs_agents.where("name ILIKE ?", query).select(:id)
    end
  end

  def agency_name_for_container_service(service)
    "-"
  end

  def client_name_for_container_service(service)
    billed_to_name = service.billed_to_entity&.name

    client_names = service.container
      &.bl_house_lines
      &.filter_map { |bl| bl.client&.name }
      &.uniq || []

    return billed_to_name if billed_to_name.present?

    return "-" if client_names.empty?
    return client_names.first if client_names.one?

    "Múltiples"
  end

  def find_serviceables_from_tokens
    tokens = Array(params[:service_tokens]).map(&:to_s).reject(&:blank?).uniq
    return [] if tokens.empty?

    grouped_ids = Hash.new { |hash, key| hash[key] = [] }

    tokens.each do |token|
      type, id = token.split(":", 2)
      next unless type.in?([ "ContainerService", "BlHouseLineService" ])
      next if id.blank?

      grouped_ids[type] << id
    end

    return [] if grouped_ids.empty?

    serviceables = []

    grouped_ids.each do |type, ids|
      model = type == "ContainerService" ? ContainerService : BlHouseLineService
      records = model.where(id: ids.uniq).to_a
      return [] unless records.size == ids.uniq.size

      serviceables.concat(records)
    end

    serviceables
  end
end
