class Photos::CleanupExpiredArchivesJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 200

  def perform
    PhotoArchiveRequest.where("expires_at <= ?", Time.current).find_in_batches(batch_size: BATCH_SIZE) do |batch|
      batch.each do |download_request|
        download_request.archive.purge_later if download_request.archive.attached?
        download_request.destroy!
      rescue StandardError => e
        Rails.logger.error("[Photos::CleanupExpiredArchivesJob] request_id=#{download_request.id} error=#{e.class}: #{e.message}")
      end
    end
  end
end
