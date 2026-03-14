require "digest"

module Facturador
  class CreateManualInvoiceService
    Result = Struct.new(:invoice, :error_message, keyword_init: true) do
      def success?
        error_message.blank?
      end
    end

    class << self
      def call(actor:, receiver_entity_id:, customs_agent_id:, line_items_params:)
        new(
          actor: actor,
          receiver_entity_id: receiver_entity_id,
          customs_agent_id: customs_agent_id,
          line_items_params: line_items_params
        ).call
      end
    end

    def initialize(actor:, receiver_entity_id:, customs_agent_id:, line_items_params:)
      @actor = actor
      @receiver_entity_id = receiver_entity_id
      @customs_agent_id = customs_agent_id
      @line_items_params = line_items_params
    end

    def call
      return Result.new(error_message: "Facturador está deshabilitado") unless Config.enabled?
      return Result.new(error_message: "Las acciones manuales de Facturador están deshabilitadas") unless Config.manual_actions_enabled?

      issuer = Config.issuer_entity
      return Result.new(error_message: "No se encontró el emisor configurado") unless issuer

      receiver = Entity.find_by(id: receiver_entity_id)
      return Result.new(error_message: "Receptor no encontrado") unless receiver

      customs_agent = resolve_customs_agent
      return Result.new(error_message: "La agencia aduanal seleccionada no existe") if customs_agent_id.present? && customs_agent.blank?
      return Result.new(error_message: "La entidad seleccionada no es una agencia aduanal") if customs_agent.present? && !customs_agent.role_customs_agent?

      if customs_agent.present? && receiver.role_client? && receiver.customs_agent_id != customs_agent.id
        return Result.new(error_message: "El cliente receptor no pertenece a la agencia aduanal seleccionada")
      end

      parsed_line_items = build_line_items
      return Result.new(error_message: "Debes agregar al menos un concepto") if parsed_line_items.empty?

      unless fiscal_ready?(issuer) && fiscal_ready?(receiver)
        return Result.new(error_message: "Emisor y receptor deben tener perfil fiscal y domicilio fiscal")
      end

      invoice = nil

      ActiveRecord::Base.transaction do
        subtotal = parsed_line_items.sum { |item| item[:subtotal] }
        tax_total = parsed_line_items.sum { |item| item[:tax_amount] }
        total = parsed_line_items.sum { |item| item[:total] }

        invoice = Invoice.create!(
          invoiceable: nil,
          kind: "ingreso",
          status: "draft",
          currency: "MXN",
          issuer_entity: issuer,
          receiver_entity: receiver,
          customs_agent: customs_agent,
          subtotal: subtotal,
          tax_total: tax_total,
          total: total,
          idempotency_key: manual_idempotency_key(
            issuer_id: issuer.id,
            receiver_id: receiver.id,
            line_items: parsed_line_items
          ),
          payload_snapshot: {
            manual: true,
            receiver_kind: receiver.role_kind,
            customs_agent_id: customs_agent&.id,
            line_items: parsed_line_items
          }
        )

        parsed_line_items.each_with_index do |item, idx|
          invoice.invoice_line_items.create!(item.merge(position: idx))
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

    attr_reader :actor, :receiver_entity_id, :customs_agent_id, :line_items_params

    def resolve_customs_agent
      return nil if customs_agent_id.blank?

      Entity.find_by(id: customs_agent_id)
    end

    def fiscal_ready?(entity)
      entity.fiscal_profile.present? && entity.fiscal_address.present?
    end

    def build_line_items
      Array(line_items_params).map.with_index(1) do |item, index|
        service_catalog_id = item[:service_catalog_id].to_s.strip
        description_raw = item[:description].to_s.strip
        quantity_raw = item[:quantity].to_s.strip
        unit_price_raw = item[:unit_price].to_s.strip

        if service_catalog_id.blank? || description_raw.blank? || quantity_raw.blank? || unit_price_raw.blank?
          raise ValidationError, "El concepto ##{index} está incompleto. Debes capturar concepto, descripción, cantidad y precio unitario."
        end

        service_catalog = ServiceCatalog.active.find_by(id: service_catalog_id)
        raise ValidationError, "El concepto ##{index} no existe o está inactivo." if service_catalog.blank?

        if service_catalog.sat_clave_prod_serv.to_s.blank? || service_catalog.sat_clave_unidad.to_s.blank?
          raise ValidationError, "El concepto #{service_catalog.name} no tiene claves SAT completas"
        end

        unless quantity_raw.match?(/\A\d+\z/)
          raise ValidationError, "El concepto ##{index} debe tener una cantidad entera mayor o igual a 1."
        end

        quantity = quantity_raw.to_i
        unit_price = item[:unit_price].to_d

        raise ValidationError, "El concepto ##{index} debe tener una cantidad entera mayor o igual a 1." if quantity < 1
        raise ValidationError, "El concepto ##{index} no puede tener precio unitario negativo." if unit_price.negative?

        sat_tasa_iva = service_catalog.sat_tasa_iva.to_d
        subtotal = quantity * unit_price
        tax_amount = service_catalog.sat_objeto_imp == "02" ? (subtotal * sat_tasa_iva) : 0.to_d

        {
          service_catalog: service_catalog,
          description: description_raw,
          sat_clave_prod_serv: service_catalog.sat_clave_prod_serv.to_s,
          sat_clave_unidad: service_catalog.sat_clave_unidad.to_s,
          sat_objeto_imp: service_catalog.sat_objeto_imp.to_s,
          sat_tasa_iva: sat_tasa_iva,
          quantity: quantity,
          unit_price: unit_price,
          subtotal: subtotal,
          tax_amount: tax_amount,
          total: subtotal + tax_amount
        }
      end
    end

    def manual_idempotency_key(issuer_id:, receiver_id:, line_items:)
      canonical_lines = line_items.map do |line|
        [
          line[:service_catalog].id,
          line[:description],
          line[:quantity].to_s("F"),
          line[:unit_price].to_s("F")
        ].join("|")
      end

      raw = [
        "manual",
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
