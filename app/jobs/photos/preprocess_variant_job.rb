class Photos::PreprocessVariantJob < ApplicationJob
  queue_as :active_storage
  GALLERY_VARIANT_TRANSFORMATIONS = { resize_to_limit: [ 320, 320 ], format: :jpeg }.freeze

  discard_on ActiveJob::DeserializationError

  def perform(photo_id)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    photo = Photo.find_by(id: photo_id)
    unless photo&.image&.attached?
      log_timing(photo_id: photo_id, status: "skipped", reason: "missing_photo_or_attachment", started_at: started_at)
      return
    end

    unless photo.image.variable?
      log_timing(photo_id: photo_id, status: "skipped", reason: "non_variable_blob", started_at: started_at, blob_id: photo.image.blob_id)
      return
    end

    # Pre-generate gallery variant to speed up first render in photo sections.
    photo.image.variant(GALLERY_VARIANT_TRANSFORMATIONS).processed

    log_timing(
      photo_id: photo_id,
      status: "ok",
      reason: "processed",
      started_at: started_at,
      blob_id: photo.image.blob_id,
      byte_size: photo.image.blob.byte_size
    )
  rescue StandardError => e
    log_timing(photo_id: photo_id, status: "error", reason: e.class.name, started_at: started_at, error: e.message)
    raise
  end

  private

  def log_timing(photo_id:, status:, reason:, started_at:, blob_id: nil, byte_size: nil, error: nil)
    return unless photo_timing_logs_enabled?

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round

    Rails.logger.info(
      "[Photos::PreprocessVariantJob] status=#{status} reason=#{reason} photo_id=#{photo_id} " \
      "blob_id=#{blob_id} byte_size=#{byte_size} duration_ms=#{duration_ms} error=#{error}"
    )
  end

  def photo_timing_logs_enabled?
    ActiveModel::Type::Boolean.new.cast(ENV["PHOTO_TIMING_LOGS"])
  end
end
