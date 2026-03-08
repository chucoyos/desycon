module Facturador
  class SendInvoiceEmailJob < ApplicationJob
    queue_as :default

    AUTH_ATTEMPTS = 3
    REQUEST_ATTEMPTS = 4
    UUID_ATTEMPTS = 4

    def perform(invoice_id:, trigger:, actor_id: nil)
      invoice = Invoice.find(invoice_id)
      actor = User.find_by(id: actor_id) if actor_id.present?

      Facturador::SendInvoiceEmailService.call(
        invoice: invoice,
        actor: actor,
        trigger: trigger
      )
    rescue Facturador::ValidationError => e
      handle_validation_error!(error: e, trigger: trigger)
      raise
    rescue Facturador::AuthenticationError => e
      retry_if_supported!(error: e, attempts: AUTH_ATTEMPTS, wait_time: 30.seconds)
      raise
    rescue Facturador::RequestError => e
      retry_if_supported!(error: e, attempts: REQUEST_ATTEMPTS, wait_time: 1.minute)
      raise
    end

    private

    def handle_validation_error!(error:, trigger:)
      return unless retryable_missing_uuid?(error: error, trigger: trigger)

      retry_if_supported!(error: error, attempts: UUID_ATTEMPTS, wait_time: 20.seconds)
    end

    def retryable_missing_uuid?(error:, trigger:)
      return false if trigger.to_s == "manual"

      error.message.to_s.include?("Invoice UUID is missing")
    end

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
