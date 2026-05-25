require "digest"

module Facturador
  class ImportExternalInvoicesService
    DEFAULT_SOURCE = "nightly"
    MAX_SAFE_PAGES = 1000

    Summary = Struct.new(
      :window_start,
      :window_end,
      :read_count,
      :created_count,
      :updated_count,
      :duplicate_count,
      :pending_assignment_count,
      :skipped_non_importable_count,
      :error_count,
      :page_count,
      :dry_run,
      keyword_init: true
    )

    class << self
      def call(window_start:, window_end:, take: nil, max_pages: nil, dry_run: false, actor: nil, source: DEFAULT_SOURCE)
        new(
          window_start: window_start,
          window_end: window_end,
          take: take,
          max_pages: max_pages,
          dry_run: dry_run,
          actor: actor,
          source: source
        ).call
      end
    end

    def initialize(window_start:, window_end:, take: nil, max_pages: nil, dry_run: false, actor: nil, source: DEFAULT_SOURCE)
      @window_start = window_start
      @window_end = window_end
      @take = normalized_take(take)
      @max_pages = normalized_max_pages(max_pages)
      @dry_run = ActiveModel::Type::Boolean.new.cast(dry_run)
      @actor = actor
      @source = source
      @synced_at = Time.current
    end

    def call
      summary = build_summary
      return summary unless Config.external_invoices_runtime_enabled?

      access_token = AccessTokenService.fetch!
      emisor_id = EmisorService.emisor_id!(access_token: access_token)
      client = Client.new(access_token: access_token)
      issuer_entity = Config.issuer_entity
      raise ConfigurationError, "Facturador issuer entity is missing" if issuer_entity.blank?

      current_skip = 0

      loop do
        break if max_pages.present? && summary.page_count >= max_pages

        response = client.buscar_comprobantes(
          emisor_id: emisor_id,
          finicial: window_start.to_i,
          ffinal: window_end.to_i,
          skip: current_skip,
          take: take
        )

        items = extract_provider_items(response)
        break if items.empty?

        summary.page_count += 1

        items.each do |item|
          process_item(item: item, issuer_entity: issuer_entity, summary: summary)
        end

        break if items.size < take

        current_skip += take
      end

      summary
    end

    private

    attr_reader :window_start, :window_end, :take, :max_pages, :dry_run, :actor, :source, :synced_at

    def build_summary
      Summary.new(
        window_start: window_start,
        window_end: window_end,
        read_count: 0,
        created_count: 0,
        updated_count: 0,
        duplicate_count: 0,
        pending_assignment_count: 0,
        skipped_non_importable_count: 0,
        error_count: 0,
        page_count: 0,
        dry_run: dry_run
      )
    end

    def process_item(item:, issuer_entity:, summary:)
      summary.read_count += 1

      payload = item.to_h.deep_stringify_keys
      uuid = normalized_uuid(payload["uuid"])

      unless importable?(payload: payload, uuid: uuid)
        summary.skipped_non_importable_count += 1
        return
      end

      external_fingerprint = external_fingerprint(payload)
      existing = find_existing_invoice(uuid: uuid, payload: payload, external_fingerprint: external_fingerprint)
      receiver_entity, visibility_state = resolve_receiver_entity(payload: payload, issuer_entity: issuer_entity)
      customs_agent = resolve_customs_agent(receiver_entity: receiver_entity, visibility_state: visibility_state)
      attributes = build_invoice_attributes(
        payload: payload,
        issuer_entity: issuer_entity,
        receiver_entity: receiver_entity,
        customs_agent: customs_agent,
        visibility_state: visibility_state,
        external_fingerprint: external_fingerprint
      )

      if existing.present?
        sync_existing_invoice(existing: existing, attributes: attributes, payload: payload, summary: summary)
      else
        create_external_invoice(attributes: attributes, payload: payload, summary: summary)
      end
    rescue StandardError => e
      summary.error_count += 1
      create_failed_event(invoice: existing, payload: payload, error: e)
      Rails.logger.warn("Facturador external import item failed uuid=#{payload&.dig('uuid')} message=#{e.message}")
    end

    def importable?(payload:, uuid:)
      return false if uuid.blank?

      status_text = [ payload["estatus"], payload["subestatus"], payload["descripcion"] ].compact.join(" ").downcase
      return true if status_text.include?("cancelado")

      true
    end

    def find_existing_invoice(uuid:, payload:, external_fingerprint:)
      by_uuid = Invoice.where("UPPER(sat_uuid) = ?", uuid).first
      return by_uuid if by_uuid.present?

      comprobante_id = normalized_comprobante_id(payload["idComprobante"])
      if comprobante_id.present?
        by_comprobante_id = Invoice.find_by(facturador_comprobante_id: comprobante_id)
        return by_comprobante_id if by_comprobante_id.present?
      end

      return nil if external_fingerprint.blank?

      Invoice.find_by(source_origin: "facturador_external", external_dedup_fingerprint: external_fingerprint)
    end

    def resolve_receiver_entity(payload:, issuer_entity:)
      rfc = normalized_rfc(payload["receptorRfc"])
      return [ issuer_entity, "pending_assignment" ] if rfc.blank?

      candidates = Entity
        .joins(:fiscal_profile)
        .where("UPPER(fiscal_profiles.rfc) = ?", rfc)
        .to_a

      receiver_entity = candidates.min_by { |entity| role_priority(entity.role_kind) }
      return [ issuer_entity, "pending_assignment" ] if receiver_entity.blank?

      [ receiver_entity, "mapped" ]
    end

    def role_priority(role_kind)
      {
        "client" => 0,
        "consolidator" => 1,
        "customs_agent" => 2,
        "customs_broker" => 3,
        "forwarder" => 4
      }[role_kind.to_s] || 99
    end

    def resolve_customs_agent(receiver_entity:, visibility_state:)
      return nil if visibility_state == "pending_assignment"
      return receiver_entity if receiver_entity&.role_customs_agent?
      return receiver_entity.customs_agent if receiver_entity&.role_client?

      nil
    end

    def build_invoice_attributes(payload:, issuer_entity:, receiver_entity:, customs_agent:, visibility_state:, external_fingerprint:)
      kind = external_kind(payload)

      {
        issuer_entity: issuer_entity,
        receiver_entity: receiver_entity,
        customs_agent: customs_agent,
        kind: kind,
        status: external_status(payload),
        currency: payload["moneda"].to_s.presence || "MXN",
        subtotal: decimal_value(payload["subtotal"]),
        tax_total: decimal_value(payload["impuestos"]),
        total: decimal_value(payload["total"]),
        sat_uuid: normalized_uuid(payload["uuid"]),
        facturador_comprobante_id: normalized_comprobante_id(payload["idComprobante"]),
        issued_at: parse_provider_datetime(payload["fecha"]) || synced_at,
        payload_snapshot: build_payload_snapshot(
          payload: payload,
          issuer_entity: issuer_entity,
          receiver_entity: receiver_entity,
          kind: kind
        ),
        provider_response: payload,
        source_origin: "facturador_external",
        external_visibility_state: visibility_state,
        imported_from_facturador_at: synced_at,
        last_external_sync_at: synced_at,
        external_raw_snapshot: payload,
        external_dedup_fingerprint: external_fingerprint
      }
    end

    def sync_existing_invoice(existing:, attributes:, payload:, summary:)
      event_payload = {
        source: source,
        uuid: payload["uuid"],
        idComprobante: payload["idComprobante"]
      }

      update_attrs = if existing.source_origin == "local"
        {
          sat_uuid: existing.sat_uuid.presence || attributes[:sat_uuid],
          facturador_comprobante_id: existing.facturador_comprobante_id.presence || attributes[:facturador_comprobante_id],
          provider_response: existing.provider_response.to_h.deep_stringify_keys.merge(payload),
          imported_from_facturador_at: existing.imported_from_facturador_at || synced_at,
          last_external_sync_at: synced_at,
          external_raw_snapshot: payload,
          external_dedup_fingerprint: attributes[:external_dedup_fingerprint]
        }
      else
        attributes.merge(
          payload_snapshot: merge_payload_snapshot(existing: existing, imported_payload_snapshot: attributes[:payload_snapshot]),
          provider_response: existing.provider_response.to_h.deep_stringify_keys.merge(payload),
          last_external_sync_at: synced_at,
          external_raw_snapshot: payload
        )
      end

      if attrs_changed?(existing: existing, update_attrs: update_attrs)
        summary.updated_count += 1

        unless dry_run
          existing.update!(update_attrs)
          event_type = existing.external_visibility_state == "pending_assignment" ? "external_import_pending_assignment" : "external_import_updated"
          existing.invoice_events.create!(
            event_type: event_type,
            created_by: actor,
            request_payload: event_payload,
            response_payload: payload
          )
        end
      else
        summary.duplicate_count += 1

        unless dry_run
          existing.invoice_events.create!(
            event_type: "external_import_skipped_duplicate",
            created_by: actor,
            request_payload: event_payload,
            response_payload: payload
          )
        end
      end

      summary.pending_assignment_count += 1 if update_attrs[:external_visibility_state] == "pending_assignment"
    end

    def create_external_invoice(attributes:, payload:, summary:)
      summary.created_count += 1
      summary.pending_assignment_count += 1 if attributes[:external_visibility_state] == "pending_assignment"
      return if dry_run

      invoice = Invoice.create!(attributes)
      event_type = attributes[:external_visibility_state] == "pending_assignment" ? "external_import_pending_assignment" : "external_import_created"

      invoice.invoice_events.create!(
        event_type: event_type,
        created_by: actor,
        request_payload: {
          source: source,
          uuid: payload["uuid"],
          idComprobante: payload["idComprobante"]
        },
        response_payload: payload
      )
    end

    def create_failed_event(invoice:, payload:, error:)
      return if dry_run
      return if invoice.blank?

      invoice.invoice_events.create!(
        event_type: "external_import_failed",
        created_by: actor,
        request_payload: {
          source: source,
          uuid: payload&.dig("uuid"),
          idComprobante: payload&.dig("idComprobante")
        },
        response_payload: {
          error: error.message
        }
      )
    rescue StandardError
      nil
    end

    def attrs_changed?(existing:, update_attrs:)
      update_attrs.compact.any? do |key, value|
        existing.public_send(key) != value
      end
    end

    def extract_provider_items(response)
      if response.is_a?(Hash)
        Array(response["resumenComprobante"])
      else
        Array(response)
      end
    end

    def normalized_uuid(value)
      uuid = value.to_s.strip
      return nil if uuid.blank? || uuid.casecmp("null").zero?

      uuid.upcase
    end

    def normalized_rfc(value)
      rfc = value.to_s.strip.upcase
      return nil if rfc.blank?
      return nil if %w[UNDEFINED NULL].include?(rfc)

      rfc
    end

    def normalized_comprobante_id(value)
      raw = value.to_s.strip
      return nil if raw.blank?

      parsed = raw.to_i
      parsed.positive? ? parsed : nil
    end

    def parse_provider_datetime(value)
      return nil if value.blank?

      parsed = Time.zone.parse(value.to_s)
      return nil if parsed&.year.to_i <= 1

      parsed
    rescue ArgumentError, TypeError
      nil
    end

    def external_kind(payload)
      kind_text = [ payload["satTipoDeComprobante"], payload["tipoComprobante"], payload["tipoComprobanteId"] ]
        .compact
        .join(" ")
        .downcase

      return "pago" if kind_text.include?("pago") || kind_text.match?(/\bP\b/i)
      return "egreso" if kind_text.include?("egreso") || kind_text.match?(/\bE\b/i)

      "ingreso"
    end

    def external_status(payload)
      text = [ payload["subestatus"], payload["estatus"], payload["descripcion"] ].compact.join(" ").downcase
      return "cancelled" if text.include?("cancelado")
      return "cancel_pending" if text.include?("espera cancel") || text.include?("proceso de cancel")

      "issued"
    end

    def decimal_value(value)
      BigDecimal(value.to_s)
    rescue ArgumentError
      0.to_d
    end

    def build_payload_snapshot(payload:, issuer_entity:, receiver_entity:, kind:)
      receiver_profile = receiver_entity.fiscal_profile
      receiver_address = receiver_entity.fiscal_address
      issuer_profile = issuer_entity.fiscal_profile

      forma_pago = normalized_present_string(payload["satFormaPagoClave"]) ||
           normalized_present_string(payload["formaPago"])
      metodo_pago = normalized_present_string(payload["satMetodoPagoClave"]) ||
            normalized_present_string(payload["metodoPago"])

      serie = normalized_present_string(payload["serie"])
      folio = normalized_present_string(payload["folio"]) ||
              normalized_present_string(payload["noComprobante"]) ||
              normalized_present_string(payload["numeroComprobante"]) ||
              normalized_comprobante_id(payload["idComprobante"])&.to_s

      concept_amount = decimal_value(payload["subtotal"])
      tax_amount = decimal_value(payload["impuestos"])
      tax_rate = if concept_amount.positive? && tax_amount.positive?
        (tax_amount / concept_amount).round(6).to_s("F")
      else
        "0.160000"
      end

      {
        "version" => payload["version"].to_s.presence || "4.0",
        "tipoDeComprobante" => cfdi_type_code(kind),
        "moneda" => payload["moneda"].to_s.presence || "MXN",
        "serie" => serie,
        "folio" => folio,
        "fecha" => (parse_provider_datetime(payload["fecha"]) || synced_at).iso8601,
        "formaPago" => forma_pago,
        "metodoPago" => metodo_pago,
        "emisor" => {
          "nombre" => issuer_profile&.razon_social.to_s.presence || issuer_entity.name,
          "rfc" => issuer_profile&.rfc.to_s.presence,
          "regimenFiscal" => issuer_profile&.regimen.to_s.presence
        },
        "receptor" => {
          "nombre" => normalized_present_string(payload["receptorNombre"]) || receiver_entity.name,
          "rfc" => normalized_rfc(payload["receptorRfc"]) || receiver_profile&.rfc.to_s.presence,
          "usoCFDI" => receiver_profile&.uso_cfdi.to_s.presence,
          "regimenFiscalReceptor" => receiver_profile&.regimen.to_s.presence,
          "domicilioFiscalReceptor" => receiver_address&.codigo_postal.to_s.presence
        },
        "conceptos" => [
          {
            "cantidad" => "1",
            "claveProdServ" => "80151600",
            "claveUnidad" => "E48",
            "descripcion" => normalized_present_string(payload["tipoComprobante"]) || "CFDI importado desde Facturador",
            "importe" => concept_amount.to_s("F"),
            "impuestos" => {
              "traslados" => [
                {
                  "base" => concept_amount.to_s("F"),
                  "impuesto" => "002",
                  "tipoFactor" => "Tasa",
                  "tasaOCuota" => tax_rate,
                  "importe" => tax_amount.to_s("F")
                }
              ]
            }
          }
        ]
      }.deep_stringify_keys
    end

    def merge_payload_snapshot(existing:, imported_payload_snapshot:)
      existing_snapshot = existing.payload_snapshot.to_h.deep_stringify_keys
      incoming_snapshot = imported_payload_snapshot.to_h.deep_stringify_keys

      merged = existing_snapshot.merge(incoming_snapshot)
      preserve_if_blank!(merged, existing_snapshot, "formaPago")
      preserve_if_blank!(merged, existing_snapshot, "metodoPago")
      merged["receptor"] = existing_snapshot.fetch("receptor", {}).to_h.deep_stringify_keys.merge(incoming_snapshot.fetch("receptor", {}).to_h.deep_stringify_keys)
      merged["emisor"] = existing_snapshot.fetch("emisor", {}).to_h.deep_stringify_keys.merge(incoming_snapshot.fetch("emisor", {}).to_h.deep_stringify_keys)

      if Array(existing_snapshot["conceptos"]).any?
        merged["conceptos"] = existing_snapshot["conceptos"]
      end

      merged
    end

    def cfdi_type_code(kind)
      case kind
      when "egreso" then "E"
      when "pago" then "P"
      else "I"
      end
    end

    def normalized_present_string(value)
      token = value.to_s.strip
      return nil if token.blank?
      return nil if %w[undefined null sin serie].include?(token.downcase)

      token
    end

    def preserve_if_blank!(target, source, key)
      return if target[key].to_s.strip.present?
      return if source[key].to_s.strip.blank?

      target[key] = source[key]
    end

    def external_fingerprint(payload)
      serie = payload["serie"].to_s.strip.upcase
      folio = payload["folio"].to_s.strip.upcase
      receptor_rfc = normalized_rfc(payload["receptorRfc"]).to_s
      fecha = parse_provider_datetime(payload["fecha"])&.to_date&.iso8601.to_s
      total = decimal_value(payload["total"]).to_s("F")

      key = [ serie, folio, receptor_rfc, fecha, total ].join("|")
      return nil if key.gsub("|", "").blank?

      Digest::SHA256.hexdigest(key)
    end

    def normalized_take(value)
      parsed = value.to_i
      return Config.external_sync_take unless parsed.positive?

      [ parsed, 200 ].min
    end

    def normalized_max_pages(value)
      parsed = value.to_i
      return Config.external_sync_max_pages if parsed <= 0

      [ parsed, MAX_SAFE_PAGES ].min
    end
  end
end
