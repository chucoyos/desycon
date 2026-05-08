class ServicesController < ApplicationController
  DESTINATION_PORT_OPTIONS = {
    "manzanillo" => "Manzanillo",
    "veracruz" => "Veracruz",
    "lazaro_cardenas" => "Lazaro Cardenas",
    "altamira" => "Altamira"
  }.freeze

  BILLING_STATUS_OPTIONS = {
    "proforma" => "Proforma",
    "en_proceso" => "En proceso",
    "fallido" => "Fallido",
    "facturado" => "Facturado"
  }.freeze

  SERVICE_TYPE_OPTIONS = {
    "all" => "Todos",
    "container" => "Contenedor",
    "bl_house_line" => "Partida"
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
    requested_service_type = params[:service_type].to_s.strip
    @selected_service_type = SERVICE_TYPE_OPTIONS.key?(requested_service_type) ? requested_service_type : "all"
    @selected_consolidator = params[:consolidator].to_s.strip.presence
    requested_billing_status = if params.key?(:billing_status)
      params[:billing_status].to_s.strip
    else
      "proforma"
    end
    @selected_billing_status = BILLING_STATUS_OPTIONS.key?(requested_billing_status) ? requested_billing_status : nil
    requested_destination_port = params[:destination_port].to_s.strip
    @selected_destination_port = DESTINATION_PORT_OPTIONS.key?(requested_destination_port) ? requested_destination_port : nil

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
      billing_invoice = latest_non_payment_invoice_for(service)
      latest_invoice_id = billing_invoice&.id
      billing_state = billing_state_for_service(service, billing_invoice)
      container = service.container
      weight_total, volume_total = totals_for_container(container)

      {
        token: "ContainerService:#{service.id}",
        type: "ContainerService",
        service_id: service.id,
        container_id: service.container_id,
        invoice_id: latest_invoice_id,
        service_name: service.service_catalog&.name.presence || "-",
        status_label: BILLING_STATUS_OPTIONS[billing_state],
        billing_state: billing_state,
        facturado: service.facturado?,
        issuable: service_issuable_for_issue?(service, billing_invoice),
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
    services = bl_house_line_services_scope.to_a.reject { |service| hidden_by_nipon_exception_rule?(service) }
    service_ids = services.map(&:id)
    container_details_by_service_id = if service_ids.empty?
      {}
    else
      rows = BlHouseLineService
        .left_joins(bl_house_line: { container: { voyage: :destination_port } })
        .where(id: service_ids)
        .pluck(
          "bl_house_line_services.id",
          "containers.id",
          "containers.number",
          "ports.name",
          "ports.code",
          "containers.bl_master",
          "containers.consolidator_entity_id"
        )

      consolidator_ids = rows.map { |_service_id, _container_id, _number, _port_name, _port_code, _bl_master, consolidator_id| consolidator_id }.compact.uniq
      consolidator_names_by_id = Entity.where(id: consolidator_ids).pluck(:id, :name).to_h

      rows.each_with_object({}) do |(service_id, _container_id, number, port_name, port_code, bl_master, consolidator_id), hash|
        destination_port = if port_name.present? && port_code.present?
          "#{port_name} (#{port_code})"
        elsif port_name.present?
          port_name
        elsif port_code.present?
          port_code
        end

        hash[service_id] = {
          number: number.to_s.strip.presence,
          destination_port: destination_port.to_s.strip.presence,
          bl_master: bl_master.to_s.strip.presence,
          consolidator_name: consolidator_names_by_id[consolidator_id].to_s.strip.presence
        }
      end
    end

    services.map do |service|
      bl_house_line = service.bl_house_line
      container_details = container_details_by_service_id[service.id] || {}
      client_name = bl_house_line&.client&.name
      billed_to_name = service.billed_to_entity&.name
      billing_invoice = latest_non_payment_invoice_for(service)
      latest_invoice_id = billing_invoice&.id
      billing_state = billing_state_for_service(service, billing_invoice)

      {
        token: "BlHouseLineService:#{service.id}",
        type: "BlHouseLineService",
        service_id: service.id,
        bl_house_line_id: service.bl_house_line_id,
        invoice_id: latest_invoice_id,
        service_name: service.service_catalog&.name.presence || "-",
        status_label: BILLING_STATUS_OPTIONS[billing_state],
        billing_state: billing_state,
        facturado: service.facturado?,
        issuable: service_issuable_for_issue?(service, billing_invoice),
        container_number: container_details[:number].presence || "-",
        destination_port: container_details[:destination_port].presence || "-",
        bl_master: container_details[:bl_master].presence || "-",
        peso: bl_house_line&.peso,
        volumen: bl_house_line&.volumen,
        consolidator_name: container_details[:consolidator_name].presence || "-",
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
          :client
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

    if @selected_service_type == "container"
      filtered = filtered.select do |row|
        row[:type] == "ContainerService"
      end
    elsif @selected_service_type == "bl_house_line"
      filtered = filtered.select do |row|
        row[:type] == "BlHouseLineService"
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
      filtered = filtered.select { |row| row[:billing_state] == @selected_billing_status }
    end

    filtered
  end

  def normalized_text(value)
    I18n.transliterate(value.to_s).downcase
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
    filters << [ "Tipo", SERVICE_TYPE_OPTIONS[@selected_service_type] ] if @selected_service_type != "all"
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
      return [] if records.any? { |record| hidden_by_nipon_exception_rule?(record) }
      return [] if records.any? { |record| !service_issuable_for_issue?(record) }

      serviceables.concat(records)
    end

    serviceables
  end

  def service_issuable_for_issue?(service, billing_invoice = nil)
    billing_state_for_service(service, billing_invoice) == "proforma"
  end

  def billing_state_for_service(service, billing_invoice = nil)
    return "facturado" if service.factura.present?

    billing_invoice ||= latest_non_payment_invoice_for(service)
    return "proforma" if billing_invoice.blank?

    case billing_invoice.status.to_s
    when "issued", "cancel_pending", "cancelled"
      "facturado"
    when "draft", "queued"
      "en_proceso"
    when "failed"
      "fallido"
    else
      "proforma"
    end
  end

  def latest_non_payment_invoice_for(service)
    direct_invoice = service.invoices.where.not(kind: "pago").recent_first.first
    linked_invoice = Invoice.joins(:invoice_service_links)
      .where(invoice_service_links: { serviceable_type: service.class.name, serviceable_id: service.id })
      .where.not(kind: "pago")
      .recent_first
      .first

    [ direct_invoice, linked_invoice ].compact.max_by(&:created_at)
  end

  def hidden_by_nipon_exception_rule?(service)
    return false unless service.is_a?(BlHouseLineService)
    return false unless Facturador::Config.auto_issue_nipon_exception_enabled?

    target_rfc = Facturador::Config.auto_issue_nipon_rfc
    return false if target_rfc.blank?

    consolidator = service.bl_house_line&.container&.consolidator_entity
    receiver = service.billed_to_entity
    consolidator_rfc = normalized_rfc_for_exception(consolidator)
    receiver_rfc = normalized_rfc_for_exception(receiver)

    consolidator_rfc.present? &&
      receiver_rfc.present? &&
      consolidator_rfc == receiver_rfc &&
      consolidator_rfc == target_rfc
  end

  def normalized_rfc_for_exception(entity)
    entity&.fiscal_profile&.rfc.to_s.upcase.strip.presence
  end
end
