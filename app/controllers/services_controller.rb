class ServicesController < ApplicationController
  DESTINATION_PORT_OPTIONS = {
    "manzanillo" => "Manzanillo",
    "veracruz" => "Veracruz",
    "lazaro_cardenas" => "Lazaro Cardenas",
    "altamira" => "Altamira"
  }.freeze

  BILLING_STATUS_OPTIONS = {
    "proforma" => "Proforma",
    "facturado" => "Facturado"
  }.freeze

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
    @selected_customs_agency_id = params[:customs_agency_id].to_s.presence
    @selected_customs_agency = params[:customs_agency].to_s.strip.presence
    @selected_service_name = params[:service_name].to_s.strip.presence
    @selected_consolidator = params[:consolidator].to_s.strip.presence
    requested_billing_status = params[:billing_status].to_s.strip
    @selected_billing_status = BILLING_STATUS_OPTIONS.key?(requested_billing_status) ? requested_billing_status : nil
    requested_destination_port = params[:destination_port].to_s.strip
    @selected_destination_port = DESTINATION_PORT_OPTIONS.key?(requested_destination_port) ? requested_destination_port : nil

    @service_filter_options = global_service_filter_options
    @consolidator_filter_options = global_consolidator_filter_options
    @destination_port_filter_options = DESTINATION_PORT_OPTIONS.map { |value, label| [ label, value ] }
    @billing_status_filter_options = BILLING_STATUS_OPTIONS.map { |value, label| [ label, value ] }

    @selected_customs_agency_label = if @selected_customs_agency_id.present?
      Entity.customs_agents.where(id: @selected_customs_agency_id).pick(:name)
    end
    @selected_customs_agency_label ||= @selected_customs_agency

    unified_rows = container_service_rows + bl_house_line_service_rows
    unified_rows = apply_unified_filters(unified_rows)
    unified_rows.sort_by! { |row| [ row[:created_at] || Time.at(0), row[:service_id] ] }
    unified_rows.reverse!

    @services = Kaminari.paginate_array(unified_rows).page(params[:page]).per(per_page)
    @applied_filters = build_applied_filters
  end

  def customs_agents_search
    authorize Invoice, :issue_manual?

    query = params[:q].to_s.strip
    min_chars = 2
    limit = 20

    if query.length < min_chars
      return render json: { results: [], meta: { query:, min_chars:, limit:, count: 0 } }
    end

    cache_key = [
      "services",
      "customs_agents_search",
      current_user.id,
      query.downcase,
      limit
    ].join(":")

    results = Rails.cache.fetch(cache_key, expires_in: 60.seconds) do
      Entity
        .customs_agents
        .search_by_name(query)
        .limit(limit)
        .pluck(:id, :name)
        .map do |id, name|
          {
            id:,
            label: name
          }
        end
    end

    render json: { results:, meta: { query:, min_chars:, limit:, count: results.size } }
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
      container = service.container
      weight_total, volume_total = totals_for_container(container)

      {
        token: "ContainerService:#{service.id}",
        type: "ContainerService",
        service_id: service.id,
        container_id: service.container_id,
        invoice_id: latest_invoice_id,
        service_name: service.service_catalog&.name.presence || "-",
        status_label: service.facturado? ? "Facturado" : "Proforma",
        facturado: service.facturado?,
        container_number: container&.number.presence || "-",
        destination_port: container&.destination_port&.display_name.presence || "-",
        bl_master: container&.bl_master.presence || "-",
        peso: weight_total,
        volumen: volume_total,
        consolidator_name: container&.consolidator_entity&.name.presence || "-",
        blhouse: "-",
        agency_name: agency_name_for_container_service(service),
        customs_agent_patent: customs_agent_patent_for_container_service(service),
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
      container = bl_house_line&.container
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
        destination_port: container&.destination_port&.display_name.presence || "-",
        bl_master: container&.bl_master.presence || "-",
        peso: bl_house_line&.peso,
        volumen: bl_house_line&.volumen,
        consolidator_name: container&.consolidator_entity&.name.presence || "-",
        blhouse: bl_house_line&.blhouse.presence || "-",
        agency_name: bl_house_line&.customs_agent&.name.presence || "-",
        customs_agent_patent: customs_agent_patent_for_bl_house_line(bl_house_line),
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
    return ContainerService.none if @selected_customs_agency_id.present? || @selected_customs_agency.present?

    scope = ContainerService
      .includes(
        :billed_to_entity,
        :service_catalog,
        container: [
          { voyage: :destination_port },
          :consolidator_entity,
          { bl_house_lines: %i[client customs_agent customs_broker] }
        ]
      )

    if @selected_container_number.present?
      scope = scope.joins(:container).where("containers.number ILIKE ?", "%#{@selected_container_number}%")
    end

    scope = scope.where(created_at: @filter_start_date.beginning_of_day..@filter_end_date.end_of_day)

    scope.distinct
  end

  def bl_house_line_services_scope
    scope = BlHouseLineService
      .includes(
        :billed_to_entity,
        :service_catalog,
        bl_house_line: [
          :customs_agent,
          :customs_broker,
          :client,
          { container: [ { voyage: :destination_port }, :consolidator_entity ] }
        ]
      )

    if @selected_container_number.present?
      scope = scope.joins(bl_house_line: :container).where("containers.number ILIKE ?", "%#{@selected_container_number}%")
    end

    if @selected_blhouse.present?
      scope = scope.joins(:bl_house_line).where("bl_house_lines.blhouse ILIKE ?", "%#{@selected_blhouse}%")
    end

    if @selected_customs_agency_id.present?
      scope = scope.joins(:bl_house_line).where(bl_house_lines: { customs_agent_id: @selected_customs_agency_id })
    elsif @selected_customs_agency.present?
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
    agency_names = service.container
      &.bl_house_lines
      &.filter_map { |bl_house_line| bl_house_line.customs_agent&.name.to_s.strip.presence }
      &.uniq || []

    return "-" if agency_names.empty?
    return agency_names.first if agency_names.one?

    "Múltiples"
  end

  def customs_agent_patent_for_container_service(service)
    labels = service.container
      &.bl_house_lines
      &.filter_map { |bl_house_line| customs_agent_patent_for_bl_house_line(bl_house_line) }
      &.reject { |label| label == "-" }
      &.uniq || []

    return "-" if labels.empty?
    return labels.first if labels.one?

    "Múltiples"
  end

  def customs_agent_patent_for_bl_house_line(bl_house_line)
    return "-" if bl_house_line.blank?

    broker_name = bl_house_line.customs_broker&.name.to_s.strip.presence
    patent = bl_house_line.customs_broker&.patent_number.to_s.strip.presence

    if broker_name.present? && patent.present?
      "#{broker_name} - Patente #{patent}"
    elsif broker_name.present?
      broker_name
    elsif patent.present?
      "Patente #{patent}"
    else
      "-"
    end
  end

  def totals_for_container(container)
    return [ nil, nil ] if container.blank?

    bl_house_lines = container.bl_house_lines.to_a
    return [ nil, nil ] if bl_house_lines.empty?

    total_weight = bl_house_lines.sum { |bl_house_line| bl_house_line.peso.to_d }
    total_volume = bl_house_lines.sum { |bl_house_line| bl_house_line.volumen.to_d }
    [ total_weight, total_volume ]
  end

  def apply_unified_filters(rows)
    filtered = rows

    if @selected_service_name.present?
      filtered = filtered.select do |row|
        normalized_text(row[:service_name]) == normalized_text(@selected_service_name)
      end
    end

    if @selected_consolidator.present?
      filtered = filtered.select do |row|
        normalized_text(row[:consolidator_name]) == normalized_text(@selected_consolidator)
      end
    end

    if @selected_destination_port.present?
      selected_port_label = DESTINATION_PORT_OPTIONS[@selected_destination_port]
      filtered = filtered.select do |row|
        normalized_text(row[:destination_port]).include?(normalized_text(selected_port_label))
      end
    end

    if @selected_billing_status.present?
      wants_facturado = @selected_billing_status == "facturado"
      filtered = filtered.select { |row| row[:facturado] == wants_facturado }
    end

    filtered
  end

  def normalized_text(value)
    I18n.transliterate(value.to_s).downcase
  end

  def global_service_filter_options
    ServiceCatalog
      .order(:name)
      .pluck(:name)
      .filter_map { |name| name.to_s.strip.presence }
      .uniq
  end

  def global_consolidator_filter_options
    Entity
      .consolidators
      .order(:name)
      .pluck(:name)
      .filter_map { |name| name.to_s.strip.presence }
      .uniq
  end

  def build_applied_filters
    filters = []

    filters << [ "Rango", "#{I18n.l(@filter_start_date, format: :short)} - #{I18n.l(@filter_end_date, format: :short)}" ]
    filters << [ "Contenedor", @selected_container_number ] if @selected_container_number.present?
    filters << [ "BL House", @selected_blhouse ] if @selected_blhouse.present?
    filters << [ "Agencia", @selected_customs_agency_label ] if @selected_customs_agency_label.present?
    filters << [ "Servicio", @selected_service_name ] if @selected_service_name.present?
    filters << [ "Consolidador", @selected_consolidator ] if @selected_consolidator.present?
    filters << [ "Puerto", DESTINATION_PORT_OPTIONS[@selected_destination_port] ] if @selected_destination_port.present?
    filters << [ "Estatus", BILLING_STATUS_OPTIONS[@selected_billing_status] ] if @selected_billing_status.present?

    filters
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
