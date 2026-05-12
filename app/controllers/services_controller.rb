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
    @selected_service_type = SERVICE_TYPE_OPTIONS.key?(requested_service_type) ? requested_service_type : "bl_house_line"
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

    paged_rows, total_count = paginated_service_rows
    @services = Kaminari.paginate_array(
      paged_rows,
      total_count: total_count,
      limit: per_page,
      offset: (current_page - 1) * per_page
    )
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

  def current_page
    value = params[:page].to_i
    value.positive? ? value : 1
  end

  def paginated_service_rows
    case @selected_service_type
    when "container"
      paged_rows_for_single_type(type: "ContainerService")
    when "bl_house_line"
      paged_rows_for_single_type(type: "BlHouseLineService")
    else
      paged_rows_for_all_types
    end
  end

  def paged_rows_for_single_type(type:)
    scope = type == "ContainerService" ? container_services_scope : bl_house_line_services_scope
    ordered_scope_sql = scope
      .reselect("#{scope.model.table_name}.id", "#{scope.model.table_name}.created_at")
      .reorder(created_at: :desc, id: :desc)
      .to_sql

    ids = ActiveRecord::Base.connection
      .select_values("SELECT ordered.id FROM (#{ordered_scope_sql}) ordered")
      .map(&:to_i)
    total_count = ids.size
    offset = (current_page - 1) * per_page
    page_ids = ids.slice(offset, per_page) || []

    rows = if type == "ContainerService"
      services = container_service_preload_scope.where(id: page_ids).index_by(&:id)
      container_service_rows(services: page_ids.filter_map { |id| services[id] })
    else
      services = bl_house_line_service_preload_scope.where(id: page_ids).index_by(&:id)
      bl_house_line_service_rows(services: page_ids.filter_map { |id| services[id] })
    end

    [ rows, total_count ]
  end

  def paged_rows_for_all_types
    container_scope_sql = container_services_scope.reorder(nil).select("container_services.id, container_services.created_at").to_sql
    bl_scope_sql = bl_house_line_services_scope.reorder(nil).select("bl_house_line_services.id, bl_house_line_services.created_at").to_sql

    rows_sql = <<~SQL
      SELECT * FROM (
        SELECT 'ContainerService' AS type, id, created_at FROM (#{container_scope_sql}) container_base
        UNION ALL
        SELECT 'BlHouseLineService' AS type, id, created_at FROM (#{bl_scope_sql}) bl_base
      ) unified
      ORDER BY created_at DESC, id DESC
    SQL

    raw_rows = ActiveRecord::Base.connection.exec_query(rows_sql).to_a
    total_count = raw_rows.size
    offset = (current_page - 1) * per_page
    page_rows = raw_rows.slice(offset, per_page) || []

    container_ids = page_rows.select { |row| row["type"] == "ContainerService" }.map { |row| row["id"].to_i }
    bl_ids = page_rows.select { |row| row["type"] == "BlHouseLineService" }.map { |row| row["id"].to_i }

    container_records = container_service_preload_scope.where(id: container_ids).index_by(&:id)
    bl_records = bl_house_line_service_preload_scope.where(id: bl_ids).index_by(&:id)

    container_rows = container_service_rows(services: container_ids.filter_map { |id| container_records[id] })
    bl_rows = bl_house_line_service_rows(services: bl_ids.filter_map { |id| bl_records[id] })

    rows_by_token = (container_rows + bl_rows).index_by { |row| row[:token] }
    ordered_rows = page_rows.filter_map do |row|
      token = "#{row['type']}:#{row['id']}"
      rows_by_token[token]
    end

    [ ordered_rows, total_count ]
  end

  def container_service_preload_scope
    ContainerService.includes(
      :billed_to_entity,
      :service_catalog,
      container: [
        { voyage: :destination_port },
        :consolidator_entity,
        { bl_house_lines: %i[customs_agent customs_broker client] }
      ]
    )
  end

  def bl_house_line_service_preload_scope
    BlHouseLineService.includes(
      :billed_to_entity,
      :service_catalog,
      bl_house_line: [
        :customs_agent,
        :customs_broker,
        :client
      ]
    )
  end

  def bl_house_line_rule_preload_scope
    BlHouseLineService.includes(
      { billed_to_entity: :fiscal_profile },
      {
        bl_house_line: [
          { client: :fiscal_profile },
          { container: { consolidator_entity: :fiscal_profile } }
        ]
      }
    )
  end

  def container_service_rows(services: nil)
    services ||= container_services_scope.to_a
    latest_invoices = latest_non_payment_invoices_for(services)
    services = filter_services_by_billing_status(services, latest_invoices)

    services.map do |service|
      billing_invoice = latest_invoices[service.id]
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

  def bl_house_line_service_rows(services: nil)
    services ||= bl_house_line_services_scope.to_a
    latest_invoices = latest_non_payment_invoices_for(services)
    services = filter_services_by_billing_status(services, latest_invoices)
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
      billing_invoice = latest_invoices[service.id]
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

    if @selected_consolidator.present?
      consolidator_ids = selected_consolidator_ids
      return ContainerService.none if consolidator_ids.empty?

      scope = scope.where(containers: { consolidator_entity_id: consolidator_ids })
    end

    if @selected_destination_port.present?
      selected_port_label = DESTINATION_PORT_OPTIONS[@selected_destination_port]
      scope = scope.joins(container: { voyage: :destination_port }).where("ports.name ILIKE ?", selected_port_label)
    end

    scope = scope.where(created_at: @filter_start_date.beginning_of_day..@filter_end_date.end_of_day)
    scope = apply_billing_status_sql_filter(
      scope,
      service_kind: :container
    )

    scope.distinct
  end

  def bl_house_line_services_scope
    scope = BlHouseLineService
      .includes(
        :service_catalog,
        :billed_to_entity,
        {
          bl_house_line: [
            :customs_agent,
            :customs_broker,
            :client,
            { container: :consolidator_entity }
          ]
        }
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

    if @selected_consolidator.present?
      consolidator_ids = selected_consolidator_ids
      return BlHouseLineService.none if consolidator_ids.empty?

      scope = scope.joins(bl_house_line: :container).where(containers: { consolidator_entity_id: consolidator_ids })
    end

    if @selected_destination_port.present?
      selected_port_label = DESTINATION_PORT_OPTIONS[@selected_destination_port]
      scope = scope.joins(bl_house_line: { container: { voyage: :destination_port } })
        .where("ports.name ILIKE ?", selected_port_label)
    end

    scope = scope.where(created_at: @filter_start_date.beginning_of_day..@filter_end_date.end_of_day)
    scope = apply_bl_house_line_exception_sql_filter(scope)
    scope = apply_billing_status_sql_filter(
      scope,
      service_kind: :bl_house_line
    )

    scope.distinct
  end

  def apply_billing_status_sql_filter(scope, service_kind:)
    return scope if @selected_billing_status.blank?

    scope = scope.joins(latest_billing_invoice_lateral_join_sql(service_kind:))

    if service_kind == :container
      apply_container_billing_status_sql_filter(scope)
    else
      apply_bl_house_line_billing_status_sql_filter(scope)
    end
  end

  def apply_container_billing_status_sql_filter(scope)
    case @selected_billing_status
    when "facturado"
      scope.where(
        "NULLIF(BTRIM(COALESCE(container_services.factura, '')), '') IS NOT NULL OR latest_billing_invoice.status IN (?)",
        %w[issued cancel_pending cancelled]
      )
    when "en_proceso"
      scope.where(
        "NULLIF(BTRIM(COALESCE(container_services.factura, '')), '') IS NULL AND latest_billing_invoice.status IN (?)",
        %w[draft queued]
      )
    when "fallido"
      scope.where(
        "NULLIF(BTRIM(COALESCE(container_services.factura, '')), '') IS NULL AND latest_billing_invoice.status = ?",
        "failed"
      )
    when "proforma"
      scope.where(
        "NULLIF(BTRIM(COALESCE(container_services.factura, '')), '') IS NULL AND (latest_billing_invoice.status IS NULL OR latest_billing_invoice.status NOT IN (?))",
        %w[issued cancel_pending cancelled draft queued failed]
      )
    else
      scope
    end
  end

  def apply_bl_house_line_billing_status_sql_filter(scope)
    case @selected_billing_status
    when "facturado"
      scope.where(
        "NULLIF(BTRIM(COALESCE(bl_house_line_services.factura, '')), '') IS NOT NULL OR latest_billing_invoice.status IN (?)",
        %w[issued cancel_pending cancelled]
      )
    when "en_proceso"
      scope.where(
        "NULLIF(BTRIM(COALESCE(bl_house_line_services.factura, '')), '') IS NULL AND latest_billing_invoice.status IN (?)",
        %w[draft queued]
      )
    when "fallido"
      scope.where(
        "NULLIF(BTRIM(COALESCE(bl_house_line_services.factura, '')), '') IS NULL AND latest_billing_invoice.status = ?",
        "failed"
      )
    when "proforma"
      scope.where(
        "NULLIF(BTRIM(COALESCE(bl_house_line_services.factura, '')), '') IS NULL AND (latest_billing_invoice.status IS NULL OR latest_billing_invoice.status NOT IN (?))",
        %w[issued cancel_pending cancelled draft queued failed]
      )
    else
      scope
    end
  end

  def latest_billing_invoice_lateral_join_sql(service_kind:)
    if service_kind == :container
      <<~SQL.squish
        LEFT JOIN LATERAL (
          SELECT latest.status
          FROM (
            SELECT invoices.status, invoices.created_at, invoices.id
            FROM invoices
            WHERE invoices.kind <> 'pago'
              AND invoices.invoiceable_type = 'ContainerService'
              AND invoices.invoiceable_id = container_services.id
            UNION ALL
            SELECT invoices.status, invoices.created_at, invoices.id
            FROM invoices
            INNER JOIN invoice_service_links ON invoice_service_links.invoice_id = invoices.id
            WHERE invoices.kind <> 'pago'
              AND invoice_service_links.serviceable_type = 'ContainerService'
              AND invoice_service_links.serviceable_id = container_services.id
          ) latest
          ORDER BY latest.created_at DESC, latest.id DESC
          LIMIT 1
        ) latest_billing_invoice ON TRUE
      SQL
    else
      <<~SQL.squish
        LEFT JOIN LATERAL (
          SELECT latest.status
          FROM (
            SELECT invoices.status, invoices.created_at, invoices.id
            FROM invoices
            WHERE invoices.kind <> 'pago'
              AND invoices.invoiceable_type = 'BlHouseLineService'
              AND invoices.invoiceable_id = bl_house_line_services.id
            UNION ALL
            SELECT invoices.status, invoices.created_at, invoices.id
            FROM invoices
            INNER JOIN invoice_service_links ON invoice_service_links.invoice_id = invoices.id
            WHERE invoices.kind <> 'pago'
              AND invoice_service_links.serviceable_type = 'BlHouseLineService'
              AND invoice_service_links.serviceable_id = bl_house_line_services.id
          ) latest
          ORDER BY latest.created_at DESC, latest.id DESC
          LIMIT 1
        ) latest_billing_invoice ON TRUE
      SQL
    end
  end

  def apply_bl_house_line_exception_sql_filter(scope)
    return scope unless Facturador::Config.auto_issue_nipon_exception_enabled?

    exception_rfcs = nipon_exception_rfcs
    return scope if exception_rfcs.empty?

    scope
      .joins("LEFT JOIN bl_house_lines blh_rfc_filter ON blh_rfc_filter.id = bl_house_line_services.bl_house_line_id")
      .joins("LEFT JOIN containers container_rfc_filter ON container_rfc_filter.id = blh_rfc_filter.container_id")
      .joins("LEFT JOIN entities consolidator_entity_rfc_filter ON consolidator_entity_rfc_filter.id = container_rfc_filter.consolidator_entity_id")
      .joins("LEFT JOIN fiscal_profiles consolidator_fp_rfc_filter ON consolidator_fp_rfc_filter.profileable_type = 'Entity' AND consolidator_fp_rfc_filter.profileable_id = consolidator_entity_rfc_filter.id")
      .joins("LEFT JOIN entities billed_to_entity_rfc_filter ON billed_to_entity_rfc_filter.id = bl_house_line_services.billed_to_entity_id")
      .joins("LEFT JOIN fiscal_profiles billed_to_fp_rfc_filter ON billed_to_fp_rfc_filter.profileable_type = 'Entity' AND billed_to_fp_rfc_filter.profileable_id = billed_to_entity_rfc_filter.id")
      .joins("LEFT JOIN entities client_entity_rfc_filter ON client_entity_rfc_filter.id = blh_rfc_filter.client_id")
      .joins("LEFT JOIN fiscal_profiles client_fp_rfc_filter ON client_fp_rfc_filter.profileable_type = 'Entity' AND client_fp_rfc_filter.profileable_id = client_entity_rfc_filter.id")
      .where(
        "NOT (" \
          "UPPER(TRIM(COALESCE(consolidator_fp_rfc_filter.rfc, ''))) <> '' " \
          "AND UPPER(TRIM(COALESCE(consolidator_fp_rfc_filter.rfc, ''))) IN (?) " \
          "AND (" \
            "(UPPER(TRIM(COALESCE(billed_to_fp_rfc_filter.rfc, ''))) <> '' " \
              "AND UPPER(TRIM(COALESCE(consolidator_fp_rfc_filter.rfc, ''))) = UPPER(TRIM(COALESCE(billed_to_fp_rfc_filter.rfc, '')))) " \
            "OR (UPPER(TRIM(COALESCE(billed_to_fp_rfc_filter.rfc, ''))) = '' " \
              "AND UPPER(TRIM(COALESCE(consolidator_fp_rfc_filter.rfc, ''))) = UPPER(TRIM(COALESCE(client_fp_rfc_filter.rfc, ''))))" \
          ")" \
        ")",
        exception_rfcs
      )
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
    2.weeks.ago.to_date
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

  def selected_consolidator_ids
    @selected_consolidator_ids ||= begin
      if @selected_consolidator.blank?
        []
      else
        Entity.consolidators
          .where("LOWER(name) = LOWER(?)", @selected_consolidator)
          .pluck(:id)
      end
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
      records = if type == "ContainerService"
        ContainerService.where(id: ids.uniq).to_a
      else
        BlHouseLineService
          .includes(
            { billed_to_entity: :fiscal_profile },
            {
              bl_house_line: [
                { client: :fiscal_profile },
                { container: { consolidator_entity: :fiscal_profile } }
              ]
            }
          )
          .where(id: ids.uniq)
          .to_a
      end
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

  def latest_non_payment_invoices_for(services)
    return {} if services.blank?

    service_class = services.first.class.name
    service_ids = services.map(&:id)

    direct_pairs = Invoice
      .where(invoiceable_type: service_class, invoiceable_id: service_ids)
      .where.not(kind: "pago")
      .order(created_at: :desc)
      .pluck(:invoiceable_id, :id)

    linked_pairs = Invoice
      .joins(:invoice_service_links)
      .where(invoice_service_links: { serviceable_type: service_class, serviceable_id: service_ids })
      .where.not(kind: "pago")
      .order(created_at: :desc)
      .pluck("invoice_service_links.serviceable_id", "invoices.id")

    latest_invoice_id_by_service_id = {}

    direct_pairs.each do |service_id, invoice_id|
      latest_invoice_id_by_service_id[service_id] ||= invoice_id
    end

    linked_pairs.each do |service_id, invoice_id|
      latest_invoice_id_by_service_id[service_id] ||= invoice_id
    end

    invoice_records = Invoice.where(id: latest_invoice_id_by_service_id.values.uniq).index_by(&:id)

    latest_by_id = {}

    latest_invoice_id_by_service_id.each do |service_id, invoice_id|
      latest_by_id[service_id] = invoice_records[invoice_id]
    end

    latest_by_id
  end

  def filter_services_by_billing_status(services, latest_invoices)
    return services if @selected_billing_status.blank?

    services.select do |service|
      billing_state_for_service(service, latest_invoices[service.id]) == @selected_billing_status
    end
  end

  def hidden_by_nipon_exception_rule?(service)
    return false unless service.is_a?(BlHouseLineService)
    return false unless Facturador::Config.auto_issue_nipon_exception_enabled?

    exception_rfcs = nipon_exception_rfcs
    return false if exception_rfcs.empty?

    consolidator = service.bl_house_line&.container&.consolidator_entity
    consolidator_rfc = normalized_rfc_for_exception(consolidator)
    receiver_rfcs = receiver_rfcs_for_nipon_exception(service)

    consolidator_rfc.present? &&
      receiver_rfcs.include?(consolidator_rfc) &&
      exception_rfcs.include?(consolidator_rfc)
  end

  def nipon_exception_rfcs
    Facturador::Config.auto_issue_exception_rfcs
  end

  def receiver_rfcs_for_nipon_exception(service)
    billed_to_rfc = normalized_rfc_for_exception(service.billed_to_entity)
    return [ billed_to_rfc ] if billed_to_rfc.present?

    client_rfc = normalized_rfc_for_exception(service.bl_house_line&.client)
    client_rfc.present? ? [ client_rfc ] : []
  end

  def normalized_rfc_for_exception(entity)
    entity&.fiscal_profile&.rfc.to_s.upcase.strip.presence
  end
end
