module Facturador
  class IssueInvoiceJob < ApplicationJob
    queue_as :default

    discard_on Facturador::RequestError
    discard_on Facturador::ValidationError
    retry_on Facturador::AuthenticationError, wait: 30.seconds, attempts: 3

    def perform(invoice_id)
      Facturador::IssueInvoiceService.call(invoice_id: invoice_id)
    end
  end
end
