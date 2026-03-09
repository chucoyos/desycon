module Facturador
  class CancelInvoiceJob < ApplicationJob
    queue_as :default

    discard_on Facturador::ValidationError
    discard_on Facturador::RequestError
    retry_on Facturador::AuthenticationError, wait: 30.seconds, attempts: 3

    def perform(invoice_id:, motive:, replacement_uuid: nil, actor_id: nil)
      invoice = Invoice.find(invoice_id)
      actor = User.find_by(id: actor_id) if actor_id.present?

      Facturador::CancelInvoiceService.call(
        invoice: invoice,
        motive: motive,
        replacement_uuid: replacement_uuid,
        actor: actor
      )
    end
  end
end
