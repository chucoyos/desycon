module Facturador
  class PayloadBuilder
    IMPORT_DESTINATION_SERIES_BY_PORT_CODE_PRODUCTION = {
      "MXZLO" => "GMZO",
      "MXLZC" => "GLZC",
      "MXVER" => "GVRZ",
      "MXATM" => "GATM"
    }.freeze

    IMPORT_DESTINATION_SERIES_BY_PORT_CODE_SANDBOX = {
      "MXZLO" => "MZ",
      "MXLZC" => "A",
      "MXVER" => "B",
      "MXATM" => "C"
    }.freeze

    class << self
      def build(invoice)
        new(invoice).build
      end
    end

    def initialize(invoice)
      @invoice = invoice
    end

    def build
      return build_payment_complement_payload if invoice.kind == "pago"

      conceptos = conceptos_payload

      payload = {
        emisor: emisor_payload,
        receptor: receptor_payload,
        conceptos: conceptos,
        version: "4.0",
        fecha: Time.current.strftime("%Y-%m-%dT%H:%M:%S"),
        formaPago: receiver_fiscal_profile.forma_pago.presence || "99",
        subTotal: invoice.subtotal.to_f,
        moneda: invoice.currency,
        total: invoice.total.to_f,
        tipoDeComprobante: tipo_comprobante,
        exportacion: "01",
        metodoPago: receiver_fiscal_profile.metodo_pago.presence || "PPD",
        lugarExpedicion: emisor_address.codigo_postal,
        descripcionFacturador: descripcion_facturador
      }

      resolved_serie = resolved_ingreso_serie
      payload[:serie] = resolved_serie if resolved_serie.present?
      payload[:impuestos] = impuestos_payload if requires_tax_breakdown?
      payload
    end

    def build_payment_complement_payload
      payment_data = payment_payload_data
      source = source_invoice
      taxes = payment_related_taxes(source: source, payment_data: payment_data)

      payload = {
        emisor: emisor_payload,
        receptor: receptor_payload(for_payment: true),
        conceptos: [
          {
            claveProdServ: "84111506",
            cantidad: "1",
            claveUnidad: "ACT",
            descripcion: "Pago",
            valorUnitario: 0,
            importe: 0,
            objetoImp: "01"
          }
        ],
        version: "4.0",
        fecha: Time.current.strftime("%Y-%m-%dT%H:%M:%S"),
        formaPago: "99",
        subTotal: 0,
        moneda: "XXX",
        total: 0,
        tipoDeComprobante: "P",
        exportacion: "01",
        metodoPago: "PUE",
        lugarExpedicion: emisor_address.codigo_postal,
        descripcionFacturador: descripcion_facturador,
        metadataInterna: internal_metadata_snapshot,
        complemento: {
          complementoPago20: {
            version: "2.0",
            totales: payment_complement_totals(payment_data: payment_data, taxes: taxes),
            pago: [
              payment_entry(source: source, payment_data: payment_data, taxes: taxes)
            ]
          }
        }
      }

      payload[:serie] = Config.payment_serie if Config.payment_serie.present?
      payload
    end

    private

    attr_reader :invoice

    def emisor_entity
      invoice.issuer_entity
    end

    def receiver_entity
      invoice.receiver_entity
    end

    def emisor_fiscal_profile
      emisor_entity.fiscal_profile || raise(ValidationError, "Issuer fiscal profile is required")
    end

    def receiver_fiscal_profile
      receiver_entity.fiscal_profile || raise(ValidationError, "Receiver fiscal profile is required")
    end

    def emisor_address
      emisor_entity.fiscal_address || raise(ValidationError, "Issuer fiscal address is required")
    end

    def receiver_address
      receiver_entity.fiscal_address || raise(ValidationError, "Receiver fiscal address is required")
    end

    def service_catalog
      invoice.invoiceable.service_catalog
    end

    def manual?
      invoice.invoice_line_items.any?
    end

    def emisor_payload
      {
        rfc: emisor_fiscal_profile.rfc,
        nombre: emisor_fiscal_profile.razon_social,
        regimenFiscal: emisor_fiscal_profile.regimen,
        sucursal: {
          nombre: "Principal",
          codigoPostal: emisor_address.codigo_postal,
          pais: "MEX"
        }
      }
    end

    def receptor_payload(for_payment: false)
      {
        rfc: receiver_fiscal_profile.rfc,
        nombre: receiver_fiscal_profile.razon_social,
        usoCFDI: (for_payment ? "CP01" : receiver_fiscal_profile.uso_cfdi.presence || "G03"),
        regimenFiscalReceptor: receiver_fiscal_profile.regimen,
        domicilioFiscalReceptor: receiver_address.codigo_postal,
        direccionIDFacturador: 0,
        direccion: {
          nombre: "Principal",
          codigoPostal: receiver_address.codigo_postal,
          pais: "MEX",
          correo: receiver_address.email
        }
      }
    end

    def concepto_payload
      concept = {
        claveProdServ: sat_clave_prod_serv,
        cantidad: "1",
        claveUnidad: sat_clave_unidad,
        descripcion: enriched_concept_description(service_catalog.name),
        valorUnitario: invoice.subtotal.to_f,
        importe: invoice.subtotal.to_f,
        objetoImp: service_catalog.sat_objeto_imp
      }

      concept[:impuestos] = concepto_impuestos_payload if requires_tax_breakdown?
      concept
    end

    def conceptos_payload
      return [ concepto_payload ] unless manual?

      invoice.invoice_line_items.map { |item| concepto_from_line_item(item) }
    end

    def concepto_from_line_item(item)
      concept = {
        claveProdServ: item.sat_clave_prod_serv,
        cantidad: item.quantity.to_f,
        claveUnidad: item.sat_clave_unidad,
        descripcion: enriched_concept_description(item.description),
        valorUnitario: item.unit_price.to_f,
        importe: item.subtotal.to_f,
        objetoImp: item.sat_objeto_imp
      }

      if line_item_requires_tax_breakdown?(item)
        concept[:impuestos] = {
          traslados: [
            {
              base: item.subtotal.to_f,
              impuesto: "002",
              tipoFactor: "Tasa",
              tasaOCuota: format("%.6f", item.sat_tasa_iva.to_f),
              importe: item.tax_amount.to_f
            }
          ]
        }
      end

      concept
    end

    def requires_tax_breakdown?
      if manual?
        invoice.invoice_line_items.any? { |item| line_item_requires_tax_breakdown?(item) }
      else
        service_catalog.sat_objeto_imp == "02" && invoice.tax_total.to_d.positive?
      end
    end

    def impuestos_payload
      return manual_impuestos_payload if manual?

      {
        totalImpuestosTrasladados: invoice.tax_total.to_f,
        traslados: [ traslado_payload ]
      }
    end

    def manual_impuestos_payload
      taxable_items = invoice.invoice_line_items.select { |item| line_item_requires_tax_breakdown?(item) }
      grouped = taxable_items.group_by { |item| item.sat_tasa_iva.to_d }

      {
        totalImpuestosTrasladados: taxable_items.sum { |item| item.tax_amount.to_d }.to_f,
        traslados: grouped.map do |rate, items|
          {
            base: items.sum { |item| item.subtotal.to_d }.to_f,
            impuesto: "002",
            tipoFactor: "Tasa",
            tasaOCuota: format("%.6f", rate.to_f),
            importe: items.sum { |item| item.tax_amount.to_d }.to_f
          }
        end
      }
    end

    def line_item_requires_tax_breakdown?(item)
      item.sat_objeto_imp.to_s == "02" && item.tax_amount.to_d.positive?
    end

    def concepto_impuestos_payload
      {
        traslados: [ traslado_payload ]
      }
    end

    def traslado_payload
      {
        base: invoice.subtotal.to_f,
        impuesto: "002",
        tipoFactor: "Tasa",
        tasaOCuota: "0.160000",
        importe: invoice.tax_total.to_f
      }
    end

    def tipo_comprobante
      return "I" if invoice.kind == "ingreso"
      return "E" if invoice.kind == "egreso"

      "P"
    end

    def descripcion_facturador
      return "Factura" if invoice.kind == "ingreso"
      return "Nota de crédito" if invoice.kind == "egreso"

      "Complemento de pago"
    end

    def enriched_concept_description(base_description)
      description = normalize_cfdi_description(base_description)

      extras = []
      extras << "Contenedor #{normalize_cfdi_token(container_number)}" if container_number.present?
      extras << "BlHouse #{normalize_cfdi_token(blhouse_number)}" if blhouse_number.present?
      return description if extras.empty?

      normalize_cfdi_description("#{description} #{extras.join(' ')}")
    end

    def normalize_cfdi_description(value)
      I18n.transliterate(value.to_s)
        .gsub(/[^A-Za-z0-9 ]/, " ")
        .squeeze(" ")
        .strip
    end

    def normalize_cfdi_token(value)
      I18n.transliterate(value.to_s).gsub(/[^A-Za-z0-9]/, "")
    end

    def container_number
      if invoice.invoiceable.respond_to?(:container)
        invoice.invoiceable.container&.number.to_s.presence
      elsif invoice.invoiceable.respond_to?(:bl_house_line)
        invoice.invoiceable.bl_house_line&.container&.number.to_s.presence
      elsif invoice.invoiceable.respond_to?(:number)
        invoice.invoiceable.number.to_s.presence
      end
    end

    def resolved_ingreso_serie
      manual_serie = manual_serie_override
      return manual_serie if manual_serie.present?

      fallback_serie = Config.serie
      container = invoiceable_container
      return fallback_serie unless container&.tipo_maniobra_importacion?

      port_code = container.destination_port&.code.to_s.upcase
      import_destination_series_map[port_code].presence || fallback_serie
    end

    def manual_serie_override
      return unless invoice.payload_snapshot.present?

      invoice.payload_snapshot.to_h.deep_stringify_keys["serie_override"].to_s.strip.presence
    end

    def import_destination_series_map
      return IMPORT_DESTINATION_SERIES_BY_PORT_CODE_SANDBOX if sandbox_facturador_environment?

      IMPORT_DESTINATION_SERIES_BY_PORT_CODE_PRODUCTION
    end

    def sandbox_facturador_environment?
      Config.environment.to_s.casecmp("sandbox").zero?
    end

    def invoiceable_container
      invoiceable = invoice.invoiceable
      return if invoiceable.blank?

      if invoiceable.respond_to?(:container)
        invoiceable.container
      elsif invoiceable.respond_to?(:bl_house_line)
        invoiceable.bl_house_line&.container
      end
    end

    def blhouse_number
      if invoice.invoiceable.respond_to?(:bl_house_line)
        invoice.invoiceable.bl_house_line&.blhouse.to_s.presence
      elsif invoice.invoiceable.respond_to?(:blhouse)
        invoice.invoiceable.blhouse.to_s.presence
      end
    end

    def sat_clave_prod_serv
      value = service_catalog.sat_clave_prod_serv.to_s.strip
      return value if value.present?

      raise ValidationError, "ServiceCatalog ##{service_catalog.id} requiere sat_clave_prod_serv para emitir CFDI"
    end

    def sat_clave_unidad
      value = service_catalog.sat_clave_unidad.to_s.strip
      return value if value.present?

      raise ValidationError, "ServiceCatalog ##{service_catalog.id} requiere sat_clave_unidad para emitir CFDI"
    end

    def payment_payload_data
      payment_snapshot = internal_metadata_snapshot.fetch("payment", {}).to_h
      payment = related_payment

      amount = payment&.amount&.to_d || payment_snapshot["amount"].to_d
      paid_at = payment&.paid_at || parse_time(payment_snapshot["paid_at"])
      payment_method = payment&.payment_method.to_s.presence || payment_snapshot["payment_method"].to_s.presence || "99"
      currency = payment&.currency.to_s.presence || invoice.currency

      raise ValidationError, "Payment amount is required for payment complement" if amount <= 0
      raise ValidationError, "Payment date is required for payment complement" if paid_at.blank?

      {
        amount: amount,
        paid_at: paid_at,
        payment_method: payment_method,
        currency: currency
      }
    end

    def source_invoice
      source = related_source_invoice
      sat_uuid = source&.sat_uuid.to_s.presence || internal_metadata_snapshot["source_invoice_uuid"].to_s.presence
      raise ValidationError, "Source invoice UUID is required for payment complement" if sat_uuid.blank?

      source_currency = source&.currency.to_s.presence || "MXN"
      previous_balance, remaining_balance, partiality_number, series, folio = source_balance_metadata(source)

      {
        sat_uuid: sat_uuid,
        currency: source_currency,
        previous_balance: previous_balance,
        remaining_balance: remaining_balance,
        partiality_number: partiality_number,
        serie: series,
        folio: folio,
        objeto_imp: source_tax_object(source)
      }
    end

    def related_payment
      payment_id = internal_metadata_snapshot.dig("payment", "payment_id")
      return nil if payment_id.blank?

      @related_payment ||= InvoicePayment.find_by(id: payment_id)
    end

    def related_source_invoice
      return @related_source_invoice if defined?(@related_source_invoice)

      source_invoice_id = internal_metadata_snapshot["source_invoice_id"]
      @related_source_invoice = if source_invoice_id.present?
        Invoice.find_by(id: source_invoice_id)
      else
        related_payment&.invoice
      end
    end

    def internal_metadata_snapshot
      snapshot = invoice.payload_snapshot.to_h.deep_stringify_keys
      metadata = snapshot["metadataInterna"]
      metadata.is_a?(Hash) ? metadata.to_h.deep_stringify_keys : snapshot
    end

    def source_balance_metadata(source)
      return [ invoice.total.to_d, 0.to_d, 1, nil, nil ] if source.blank?

      payment = related_payment
      if payment.present?
        # Use payment insertion sequence for partiality to avoid timestamp edge cases.
        prior_scope = source.invoice_payments.where("id < ?", payment.id)
        previous_paid = prior_scope.sum(:amount).to_d
        previous_balance = source.total.to_d - previous_paid
        remaining_balance = previous_balance - payment.amount.to_d
        partiality_number = prior_scope.count + 1
      else
        previous_balance = source.total.to_d
        remaining_balance = source.total.to_d
        partiality_number = 1
      end

      provider = source.provider_response.to_h
      series = sanitize_source_serie(provider["serie"].presence || source.payload_snapshot.to_h["serie"].presence)
      folio = provider["folio"].presence || provider["noComprobante"].presence || provider["numeroComprobante"].presence || source.facturador_comprobante_id&.to_s

      [ previous_balance.positive? ? previous_balance : 0.to_d,
        remaining_balance.positive? ? remaining_balance : 0.to_d,
        partiality_number,
        series,
        folio ]
    end

    def parse_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def source_tax_object(source)
      return "02" if source.blank?

      first_line_item = source.invoice_line_items.first
      return first_line_item.sat_objeto_imp if first_line_item&.sat_objeto_imp.present?

      invoiceable_service = source.invoiceable&.service_catalog
      return invoiceable_service.sat_objeto_imp if invoiceable_service&.sat_objeto_imp.present?

      "02"
    end

    def sanitize_source_serie(value)
      serie = value.to_s.strip
      return nil if serie.blank?
      return nil if serie.casecmp("sin serie").zero?

      serie
    end

    def payment_related_document(source:, payment_data:, taxes:)
      doc = {
        idDocumento: source[:sat_uuid],
        monedaDR: source[:currency],
        equivalenciaDR: 1,
        objetoImpDR: source[:objeto_imp],
        numParcialidad: source[:partiality_number].to_s,
        impSaldoAnt: source[:previous_balance].to_f,
        impPagado: payment_data[:amount].to_f,
        impSaldoInsoluto: source[:remaining_balance].to_f
      }
      doc[:serie] = source[:serie] if source[:serie].present?
      doc[:folio] = source[:folio] if source[:folio].present?

      if taxes.present?
        doc[:impuestosDR] = {
          trasladosDR: [
            {
              baseDR: taxes[:base].to_f,
              impuestoDR: "002",
              tipoFactorDR: "Tasa",
              tasaOCuotaDR: format("%.6f", taxes[:rate].to_f),
              importeDR: taxes[:tax].to_f
            }
          ]
        }
      end

      doc
    end

    def payment_entry(source:, payment_data:, taxes:)
      entry = {
        fechaPago: payment_data[:paid_at].in_time_zone.strftime("%Y-%m-%dT%H:%M:%S"),
        formaDePagoP: payment_data[:payment_method],
        monedaP: payment_data[:currency],
        monto: payment_data[:amount].to_f,
        doctoRelacionado: [
          payment_related_document(source: source, payment_data: payment_data, taxes: taxes)
        ]
      }

      if taxes.present?
        entry[:impuestosP] = {
          trasladosP: [
            {
              baseP: taxes[:base].to_f,
              impuestoP: "002",
              tipoFactorP: "Tasa",
              tasaOCuotaP: format("%.6f", taxes[:rate].to_f),
              importeP: taxes[:tax].to_f
            }
          ]
        }
      end

      entry
    end

    def payment_complement_totals(payment_data:, taxes:)
      totals = {
        montoTotalPagos: payment_data[:amount].to_f
      }

      if taxes.present? && taxes[:rate].to_d == 0.16.to_d
        totals[:totalTrasladosBaseIVA16] = taxes[:base].to_f
        totals[:totalTrasladosImpuestoIVA16] = taxes[:tax].to_f
      end

      totals
    end

    def payment_related_taxes(source:, payment_data:)
      return nil if source[:objeto_imp].to_s != "02"

      source_record = related_source_invoice
      return nil if source_record.blank?

      subtotal = source_record.subtotal.to_d
      tax_total = source_record.tax_total.to_d
      return nil unless subtotal.positive? && tax_total.positive?

      paid_amount = payment_data[:amount].to_d
      total = source_record.total.to_d
      return nil unless total.positive?

      ratio = paid_amount / total
      base = (subtotal * ratio).round(2)
      tax = (tax_total * ratio).round(2)
      rate = tax_total / subtotal

      {
        base: base,
        tax: tax,
        rate: rate
      }
    end
  end
end
