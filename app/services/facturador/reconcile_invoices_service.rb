module Facturador
  class ReconcileInvoicesService
    DEFAULT_LIMIT = 100

    class << self
      def call(limit: DEFAULT_LIMIT, actor: nil)
        new(limit: limit, actor: actor).call
      end
    end

    def initialize(limit:, actor: nil)
      @limit = limit.to_i.positive? ? limit.to_i : DEFAULT_LIMIT
      @actor = actor
    end

    def call
      return [] unless Config.enabled?
      return [] unless Config.reconciliation_enabled?

      access_token = AccessTokenService.fetch!
      emisor_id = EmisorService.emisor_id!(access_token: access_token)
      client = Client.new(access_token: access_token)

      invoices = Invoice.pending_reconciliation.recent_first.limit(limit)
      invoices.each { |invoice| reconcile_invoice!(invoice: invoice, client: client, emisor_id: emisor_id) }
      invoices
    end

    private

    attr_reader :limit, :actor

    def reconcile_invoice!(invoice:, client:, emisor_id:)
      invoice.invoice_events.create!(
        event_type: "reconcile_requested",
        created_by: actor,
        request_payload: { invoice_id: invoice.id, uuid: invoice.sat_uuid },
        response_payload: {}
      )

      date_from = (invoice.issued_at || invoice.created_at || Time.current).to_i - 2.days.to_i
      date_to = Time.current.to_i

      response = client.buscar_comprobantes(
        emisor_id: emisor_id,
        finicial: date_from,
        ffinal: date_to,
        uuid: invoice.sat_uuid,
        take: 10
      )

      provider_items = extract_provider_items(response)
      provider_invoice = provider_items.find do |item|
        item.is_a?(Hash) && item["uuid"].to_s.casecmp(invoice.sat_uuid.to_s).zero?
      end

      unless provider_invoice
        invoice.invoice_events.create!(
          event_type: "reconcile_not_found",
          created_by: actor,
          request_payload: { uuid: invoice.sat_uuid },
          response_payload: response
        )
        return
      end

      apply_status_sync!(invoice: invoice, provider_invoice: provider_invoice)
      invoice.invoice_events.create!(
        event_type: "reconcile_synced",
        created_by: actor,
        request_payload: { uuid: invoice.sat_uuid },
        response_payload: provider_invoice,
        provider_status: provider_invoice["subestatusId"]&.to_s
      )
    rescue StandardError => e
      error_code = ErrorCodeResolver.call(context: :reconcile, message: e.message, exception: e)
      if invoice.sat_uuid.present? && invoice.status != "cancelled"
        invoice.mark_cancel_failed_attempt!(error_code: error_code, error_message: e.message)
      else
        invoice.mark_failed!(error_code: error_code, error_message: e.message)
      end
      invoice.invoice_events.create!(
        event_type: "reconcile_failed",
        created_by: actor,
        request_payload: { uuid: invoice.sat_uuid },
        response_payload: { error: e.message },
        provider_error_message: e.message
      )
    end

    def apply_status_sync!(invoice:, provider_invoice:)
      subestatus = provider_invoice["subestatus"].to_s.downcase
      descripcion = provider_invoice["descripcion"].to_s.downcase
      status_text = "#{subestatus} #{descripcion}"

      if status_text.include?("cancelado")
        invoice.mark_cancelled!(
          cancelled_at: Time.current,
          provider_response: provider_invoice
        )
        return
      end

      if status_text.include?("espera cancel") || status_text.include?("proceso de cancel")
        invoice.mark_cancel_pending!(
          motive: invoice.cancellation_motive.presence || "02",
          replacement_uuid: invoice.replacement_uuid,
          provider_response: provider_invoice
        )
        return
      end

      return unless provider_invoice["uuid"].present?

      comprobante_id = normalized_comprobante_id(provider_invoice, invoice)

      invoice.mark_issued!(
        uuid: provider_invoice["uuid"],
        comprobante_id: comprobante_id,
        issued_at: parse_provider_datetime(provider_invoice["fecha"]) || invoice.issued_at || Time.current,
        provider_response: provider_invoice
      )
    end

    def parse_provider_datetime(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def extract_provider_items(response)
      if response.is_a?(Hash)
        Array(response["resumenComprobante"])
      else
        Array(response)
      end
    end

    def normalized_comprobante_id(provider_invoice, invoice)
      raw = provider_invoice["idComprobante"]
      normalized = raw.to_s.strip.presence
      return invoice.facturador_comprobante_id if normalized.blank? || normalized.to_i.zero?

      if Invoice.where.not(id: invoice.id).exists?(facturador_comprobante_id: normalized)
        return invoice.facturador_comprobante_id
      end

      normalized
    end
  end
end
