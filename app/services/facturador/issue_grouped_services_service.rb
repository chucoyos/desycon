require "digest"

module Facturador
  class IssueGroupedServicesService
    Result = Struct.new(:invoice, :error_message, keyword_init: true) do
      def success?
        error_message.blank?
      end
    end

    class << self
      def call(serviceables:, actor: nil)
        new(serviceables: serviceables, actor: actor).call
      end
    end

    def initialize(serviceables:, actor: nil)
      @serviceables = Array(serviceables).compact
      @actor = actor
    end

    def call
      return Result.new(error_message: "Facturador está deshabilitado") unless Config.enabled?
      return Result.new(error_message: "Las acciones manuales de Facturador están deshabilitadas") unless Config.manual_actions_enabled?
      return Result.new(error_message: "Debes seleccionar al menos un servicio") if serviceables.empty?

      existing_invoice = existing_grouped_invoice_for_selected_services
      if existing_invoice.present?
        queue_grouped_issue_if_needed(existing_invoice)
        return Result.new(invoice: existing_invoice)
      end

      invalid_service = serviceables.find(&:facturado?)
      if invalid_service.present?
        return Result.new(error_message: "No se puede facturar en bloque un servicio que ya está facturado")
      end

      receiver = resolve_receiver
      return Result.new(error_message: "Todos los servicios seleccionados deben tener el mismo receptor") if receiver.blank?

      issuer = Config.issuer_entity
      return Result.new(error_message: "No se encontró el emisor configurado") if issuer.blank?

      return Result.new(error_message: "El emisor debe tener perfil fiscal y domicilio fiscal") unless fiscal_ready?(issuer)
      return Result.new(error_message: "El receptor debe tener perfil fiscal y domicilio fiscal") unless fiscal_ready?(receiver)

      line_items = build_line_items
      return Result.new(error_message: "No hay conceptos válidos para facturar") if line_items.empty?

      grouped_services_snapshot = grouped_services_snapshot_payload
      grouped_key = grouped_idempotency_key(issuer_id: issuer.id, receiver_id: receiver.id, line_items: line_items)

      invoice = nil

      ActiveRecord::Base.transaction do
        lock_selected_services!

        subtotal = line_items.sum { |item| item[:subtotal] }
        tax_total = line_items.sum { |item| item[:tax_amount] }
        total = line_items.sum { |item| item[:total] }

        invoice = find_or_build_grouped_invoice(
          grouped_key: grouped_key,
          issuer: issuer,
          receiver: receiver,
          subtotal: subtotal,
          tax_total: tax_total,
          total: total,
          grouped_services_snapshot: grouped_services_snapshot
        )

        if invoice.new_record?
          invoice.save!

          line_items.each_with_index do |item, idx|
            invoice.invoice_line_items.create!(item.merge(position: idx))
          end

          serviceables.each do |service|
            invoice.invoice_service_links.create!(serviceable: service)
          end
        end
      end

      queue_grouped_issue_if_needed(invoice)
      Result.new(invoice: invoice)
    rescue ActiveRecord::RecordNotUnique
      # Handles concurrent clicks that race while creating the same grouped invoice key.
      invoice = Invoice.find_by(idempotency_key: grouped_idempotency_key(
        issuer_id: issuer.id,
        receiver_id: receiver.id,
        line_items: line_items
      ))
      queue_grouped_issue_if_needed(invoice) if invoice.present?
      Result.new(invoice: invoice, error_message: invoice.blank? ? "No fue posible recuperar la factura agrupada" : nil)
    rescue Facturador::Error => e
      Result.new(error_message: e.message)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(error_message: e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :serviceables, :actor

    def resolve_receiver
      receiver_ids = serviceables.map(&:billed_to_entity_id).uniq
      return nil unless receiver_ids.size == 1
      return nil if receiver_ids.first.blank?

      Entity.find_by(id: receiver_ids.first)
    end

    def fiscal_ready?(entity)
      entity.fiscal_profile.present? && entity.fiscal_address.present?
    end

    def build_line_items
      serviceables.map.with_index(1) do |service, index|
        service_catalog = service.service_catalog
        if service_catalog.blank?
          raise ValidationError, "El servicio ##{index} no tiene catálogo asociado"
        end

        if service_catalog.sat_clave_prod_serv.to_s.blank? || service_catalog.sat_clave_unidad.to_s.blank?
          raise ValidationError, "El servicio #{service_catalog.name} no tiene claves SAT completas"
        end

        unit_price = service.amount.to_d
        sat_tasa_iva = service_catalog.sat_tasa_iva.to_d
        subtotal = unit_price
        tax_amount = service_catalog.sat_objeto_imp == "02" ? (subtotal * sat_tasa_iva) : 0.to_d

        {
          service_catalog: service_catalog,
          description: build_line_item_description(service_catalog.name, service),
          sat_clave_prod_serv: service_catalog.sat_clave_prod_serv.to_s,
          sat_clave_unidad: service_catalog.sat_clave_unidad.to_s,
          sat_objeto_imp: service_catalog.sat_objeto_imp.to_s,
          sat_tasa_iva: sat_tasa_iva,
          quantity: 1,
          unit_price: unit_price,
          subtotal: subtotal,
          tax_amount: tax_amount,
          total: subtotal + tax_amount
        }
      end
    end

    def build_line_item_description(base_description, service)
      description = base_description.to_s.strip

      extras = []
      container = normalized_grouped_token(grouped_container_number_for(service))
      blhouse = normalized_grouped_token(grouped_blhouse_number_for(service))

      extras << "Contenedor: #{container}" if container.present?
      extras << "BlHouse: #{blhouse}" if blhouse.present?
      return description if extras.empty?

      base_line = description.end_with?(".") ? description : "#{description}."
      ([ base_line ] + extras).join("\n")
    end

    def grouped_container_number_for(service)
      if service.respond_to?(:container)
        service.container&.number.to_s.presence
      elsif service.respond_to?(:bl_house_line)
        service.bl_house_line&.container&.number.to_s.presence
      elsif service.respond_to?(:number)
        service.number.to_s.presence
      end
    end

    def grouped_blhouse_number_for(service)
      if service.respond_to?(:bl_house_line)
        service.bl_house_line&.blhouse.to_s.presence
      elsif service.respond_to?(:blhouse)
        service.blhouse.to_s.presence
      end
    end

    def normalized_grouped_token(value)
      I18n.transliterate(value.to_s).gsub(/[^A-Za-z0-9]/, "")
    end

    def grouped_idempotency_key(issuer_id:, receiver_id:, line_items:)
      canonical_lines = line_items.map do |line|
        [
          line[:service_catalog].id,
          line[:description],
          line[:quantity].to_s,
          line[:unit_price].to_s("F")
        ].join("|")
      end.sort

      canonical_services = serviceables
        .map { |service| [ service.class.name, service.id ].join(":") }
        .sort

      raw = [
        "grouped",
        issuer_id,
        receiver_id,
        canonical_services.join(";"),
        canonical_lines.join(";"),
        "v2"
      ].join(":")

      Digest::SHA256.hexdigest(raw)
    end

    def lock_selected_services!
      serviceables.group_by(&:class).each do |klass, records|
        ids = records.map(&:id)
        klass.where(id: ids).lock.load
      end
    end

    def grouped_services_snapshot_payload
      serviceables
        .map { |service| { type: service.class.name, id: service.id } }
        .sort_by { |item| [ item[:type], item[:id] ] }
    end

    def find_or_build_grouped_invoice(grouped_key:, issuer:, receiver:, subtotal:, tax_total:, total:, grouped_services_snapshot:)
      Invoice.find_or_initialize_by(idempotency_key: grouped_key).tap do |candidate|
        if candidate.new_record?
          candidate.assign_attributes(
            invoiceable: nil,
            issuer_entity: issuer,
            receiver_entity: receiver,
            customs_agent: receiver.customs_agent,
            kind: "ingreso",
            status: "draft",
            currency: "MXN",
            subtotal: subtotal,
            tax_total: tax_total,
            total: total,
            payload_snapshot: {
              grouped_issue: true,
              grouped_services: grouped_services_snapshot
            },
            provider_response: {}
          )
        end
      end
    end

    def queue_grouped_issue_if_needed(invoice)
      return if invoice.blank?

      invoice.with_lock do
        return if invoice.issued?
        return if invoice.status == "queued"
        return if invoice.invoice_events.where(event_type: "issue_requested").exists?

        invoice.queue_issue!(actor: actor)
      end
    end

    def existing_grouped_invoice_for_selected_services
      return nil if serviceables.empty?

      candidate_ids = nil

      serviceables.each do |service|
        invoice_ids = InvoiceServiceLink
          .joins(:invoice)
          .where(serviceable: service)
          .where(invoices: { kind: "ingreso", status: %w[draft queued issued cancel_pending failed] })
          .pluck(:invoice_id)

        candidate_ids = candidate_ids.nil? ? invoice_ids : (candidate_ids & invoice_ids)
        return nil if candidate_ids.blank?
      end

      Invoice.where(id: candidate_ids).order(created_at: :desc, id: :desc).first
    end
  end
end
