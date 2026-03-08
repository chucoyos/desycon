module Facturador
  class IssueInvoiceJob < ApplicationJob
    queue_as :default

    FAC119_RETRY_WAIT = [ 5.minutes, 15.minutes, 30.minutes, 60.minutes ].freeze

    discard_on Facturador::RequestError
    discard_on Facturador::ValidationError
    retry_on Facturador::AuthenticationError, wait: 30.seconds, attempts: 3
    retry_on Facturador::TransientIssueError,
      wait: ->(executions) { FAC119_RETRY_WAIT.fetch(executions - 1, FAC119_RETRY_WAIT.last) },
      attempts: FAC119_RETRY_WAIT.size + 1

    def perform(invoice_id)
      Facturador::IssueInvoiceService.call(invoice_id: invoice_id)
    end
  end
end
