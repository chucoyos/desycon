module Facturador
  class ReconcileInvoicesJob < ApplicationJob
    queue_as :default

    retry_on Facturador::RequestError, wait: :exponentially_longer, attempts: 5
    retry_on Facturador::AuthenticationError, wait: 30.seconds, attempts: 3

    def perform(limit = Facturador::ReconcileInvoicesService::DEFAULT_LIMIT, nightly = false)
      Facturador::ReconcileInvoicesService.call(limit: limit, nightly: nightly)
    end
  end
end
