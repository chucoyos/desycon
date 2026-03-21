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

      invoice = nil

      ActiveRecord::Base.transaction do
        subtotal = line_items.sum { |item| item[:subtotal] }
        tax_total = line_items.sum { |item| item[:tax_amount] }
        total = line_items.sum { |item| item[:total] }

        invoice = Invoice.create!(
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
          idempotency_key: grouped_idempotency_key(issuer_id: issuer.id, receiver_id: receiver.id, line_items: line_items),
          payload_snapshot: {
            grouped_issue: true,
            grouped_services: serviceables.map { |service| { type: service.class.name, id: service.id } }
          },
          provider_response: {}
        )

        line_items.each_with_index do |item, idx|
          invoice.invoice_line_items.create!(item.merge(position: idx))
        end

        serviceables.each do |service|
          invoice.invoice_service_links.create!(serviceable: service)
        end
      end

      invoice.queue_issue!(actor: actor)
      Result.new(invoice: invoice)
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
          description: service_catalog.name,
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

    def grouped_idempotency_key(issuer_id:, receiver_id:, line_items:)
      canonical_lines = line_items.map do |line|
        [
          line[:service_catalog].id,
          line[:description],
          line[:quantity].to_s,
          line[:unit_price].to_s("F")
        ].join("|")
      end

      raw = [
        "grouped",
        issuer_id,
        receiver_id,
        canonical_lines.join(";"),
        Time.current.to_f,
        actor&.id
      ].join(":")

      Digest::SHA256.hexdigest(raw)
    end
  end
end
