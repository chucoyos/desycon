module Facturador
  class SyncInvoiceDocumentsJob < ApplicationJob
    queue_as :default

    retry_on Facturador::RequestError, wait: :exponentially_longer, attempts: 5
    retry_on Facturador::AuthenticationError, wait: 30.seconds, attempts: 3

    def perform(invoice_id:, actor_id: nil)
      invoice = Invoice.find(invoice_id)
      actor = actor_id.present? ? User.find_by(id: actor_id) : nil

      Facturador::SyncInvoiceDocumentsService.call(invoice: invoice, actor: actor, force: true)
    end
  end
end
