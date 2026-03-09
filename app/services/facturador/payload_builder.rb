module Facturador
  class PayloadBuilder
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

      payload[:serie] = Config.serie if Config.serie.present?
      payload[:impuestos] = impuestos_payload if requires_tax_breakdown?
      payload
    end

    def build_payment_complement_payload
      payload = {
        emisor: emisor_payload,
        receptor: receptor_payload,
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
        metadataInterna: invoice.payload_snapshot
      }

      payload[:serie] = Config.serie if Config.serie.present?
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

    def receptor_payload
      {
        rfc: receiver_fiscal_profile.rfc,
        nombre: receiver_fiscal_profile.razon_social,
        usoCFDI: receiver_fiscal_profile.uso_cfdi.presence || "G03",
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
        descripcion: service_catalog.name,
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
        descripcion: item.description,
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
  end
end
