module Facturador
  class RequestPaymentComplementService
    class DuplicateComplementError < RequestError; end

    class << self
      def call(payment:, actor: nil)
        new(payment: payment, actor: actor).call
      end
    end

    def initialize(payment:, actor: nil)
      @payment = payment
      @actor = actor
    end

    def call
      validate_flags!
      validate_payment_eligibility!
      block_if_complement_exists!

      invoice.invoice_events.create!(
        event_type: "payment_complement_manual_requested",
        created_by: actor,
        request_payload: { payment_id: payment.id },
        response_payload: {}
      )

      IssuePaymentComplementService.call(payment: payment, actor: actor)

      invoice.invoice_events.create!(
        event_type: "payment_complement_manual_queued",
        created_by: actor,
        request_payload: { payment_id: payment.id },
        response_payload: { status: payment.reload.status }
      )

      payment
    rescue DuplicateComplementError
      raise
    rescue Error => e
      invoice.invoice_events.create!(
        event_type: "payment_complement_manual_failed",
        created_by: actor,
        request_payload: { payment_id: payment.id },
        response_payload: { error: e.message },
        provider_error_message: e.message
      )
      raise
    end

    private

    attr_reader :payment, :actor

    def invoice
      @invoice ||= payment.invoice
    end

    def validate_flags!
      raise RequestError, "Facturador no esta habilitado." unless Config.enabled?
      raise RequestError, "Los complementos de pago estan deshabilitados." unless Config.payment_complements_enabled?
      raise RequestError, "Las acciones manuales de Facturador estan deshabilitadas." unless Config.manual_actions_enabled?
    end

    def validate_payment_eligibility!
      unless payment.status.in?([ "registered", "failed" ])
        raise RequestError, "Este pago no esta en un estado valido para solicitar REP."
      end

      raise RequestError, "El CFDI origen debe estar emitido para solicitar REP." unless invoice.issued?
      raise RequestError, "Solo aplica REP para facturas con metodoPago PPD." unless invoice.payment_method_code == FiscalProfile::METODO_PAGO_PPD
      raise RequestError, "No se puede solicitar REP para CFDI de tipo pago." if invoice.kind == "pago"
    end

    def block_if_complement_exists!
      return if payment.complement_invoice.blank?

      invoice.invoice_events.create!(
        event_type: "payment_complement_manual_blocked_duplicate",
        created_by: actor,
        request_payload: {
          payment_id: payment.id,
          complement_invoice_id: payment.complement_invoice_id
        },
        response_payload: {
          complement_status: payment.complement_invoice.status,
          complement_uuid: payment.complement_invoice.sat_uuid
        }
      )

      raise DuplicateComplementError, "Este pago ya tiene un REP ligado. Eliminalo primero si no esta timbrado para intentar de nuevo."
    end
  end
end
