module Facturador
  class ReconcileInvoicesJob < ApplicationJob
    queue_as :default

    retry_on Facturador::RequestError, wait: :exponentially_longer, attempts: 5
    retry_on Facturador::AuthenticationError, wait: 30.seconds, attempts: 3

    def perform(limit = Facturador::ReconcileInvoicesService::DEFAULT_LIMIT)
      Facturador::ReconcileInvoicesService.call(limit: limit)
    end
  end
end
