module Facturador
  class SendInvoiceEmailJob < ApplicationJob
    queue_as :default

    discard_on Facturador::ValidationError

    AUTH_ATTEMPTS = 3
    REQUEST_ATTEMPTS = 4

    def perform(invoice_id:, trigger:, actor_id: nil)
      invoice = Invoice.find(invoice_id)
      actor = User.find_by(id: actor_id) if actor_id.present?

      Facturador::SendInvoiceEmailService.call(
        invoice: invoice,
        actor: actor,
        trigger: trigger
      )
    rescue Facturador::AuthenticationError => e
      retry_if_supported!(error: e, attempts: AUTH_ATTEMPTS, wait_time: 30.seconds)
      raise
    rescue Facturador::RequestError => e
      retry_if_supported!(error: e, attempts: REQUEST_ATTEMPTS, wait_time: 1.minute)
      raise
    end

    private

    def retry_if_supported!(error:, attempts:, wait_time:)
      return unless scheduled_retry_supported?
      return if executions >= attempts

      retry_job(wait: wait_time, error: error)
    rescue NotImplementedError
      # Inline adapter cannot schedule future retries.
      nil
    end

    def scheduled_retry_supported?
      !ActiveJob::Base.queue_adapter.is_a?(ActiveJob::QueueAdapters::InlineAdapter)
    end
  end
end
