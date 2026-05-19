module Facturador
  class ImportExternalInvoicesJob < ApplicationJob
    queue_as :default

    retry_on Facturador::RequestError, wait: :exponentially_longer, attempts: 5
    retry_on Facturador::AuthenticationError, wait: 30.seconds, attempts: 3

    def perform(window_start_iso8601: nil, window_end_iso8601: nil, dry_run: false, max_pages: nil, take: nil, actor_id: nil, source: "nightly")
      unless Facturador::Config.external_invoices_runtime_enabled?
        Rails.logger.info("Facturador external import skipped: runtime gate disabled for environment=#{Rails.env}")
        return
      end

      actor = actor_id.present? ? User.find_by(id: actor_id) : nil
      window_end = parse_time(window_end_iso8601) || Time.current
      window_start = parse_time(window_start_iso8601) || default_window_start(window_end)

      summary = Facturador::ImportExternalInvoicesService.call(
        window_start: window_start,
        window_end: window_end,
        dry_run: dry_run,
        max_pages: max_pages,
        take: take,
        actor: actor,
        source: source
      )

      Rails.logger.info(
        "Facturador external import job finished source=#{source} read=#{summary.read_count} " \
        "created=#{summary.created_count} updated=#{summary.updated_count} duplicates=#{summary.duplicate_count} " \
        "pending=#{summary.pending_assignment_count} errors=#{summary.error_count} dry_run=#{summary.dry_run}"
      )
    end

    private

    def parse_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def default_window_start(window_end)
      window_end - Facturador::Config.external_sync_window_hours.hours - Facturador::Config.external_sync_overlap_minutes.minutes
    end
  end
end
