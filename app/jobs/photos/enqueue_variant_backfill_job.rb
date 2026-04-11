class Photos::EnqueueVariantBackfillJob < ApplicationJob
  queue_as :default

  DEFAULT_LIMIT = 300
  DEFAULT_LOOKBACK_HOURS = 72
  MAX_LIMIT = 2_000
  VARIANT_RECORDS_TABLE = "active_storage_variant_records".freeze

  def perform(limit = DEFAULT_LIMIT, lookback_hours = DEFAULT_LOOKBACK_HOURS)
    safe_limit = normalize_limit(limit)
    safe_lookback_hours = normalize_lookback_hours(lookback_hours)
    variation_digest = gallery_variation_digest

    photo_ids = Photo
      .joins(:image_attachment)
      .joins("INNER JOIN active_storage_blobs ON active_storage_blobs.id = active_storage_attachments.blob_id")
      .joins(
        "LEFT JOIN #{VARIANT_RECORDS_TABLE} ON #{VARIANT_RECORDS_TABLE}.blob_id = active_storage_blobs.id " \
        "AND #{VARIANT_RECORDS_TABLE}.variation_digest = #{ActiveRecord::Base.connection.quote(variation_digest)}"
      )
      .where(created_at: safe_lookback_hours.hours.ago..Time.current)
      .where("#{VARIANT_RECORDS_TABLE}.id IS NULL")
      .order(created_at: :asc)
      .limit(safe_limit)
      .pluck(:id)

    photo_ids.each { |photo_id| Photos::PreprocessVariantJob.perform_later(photo_id) }

    Rails.logger.info(
      "[Photos::EnqueueVariantBackfillJob] Enqueued=#{photo_ids.size} limit=#{safe_limit} lookback_hours=#{safe_lookback_hours}"
    )
  end

  private

  def normalize_limit(limit)
    parsed = limit.to_i
    return DEFAULT_LIMIT unless parsed.positive?

    [ parsed, MAX_LIMIT ].min
  end

  def normalize_lookback_hours(lookback_hours)
    parsed = lookback_hours.to_i
    return DEFAULT_LOOKBACK_HOURS unless parsed.positive?

    parsed
  end

  def gallery_variation_digest
    ActiveStorage::Variation.wrap(Photos::PreprocessVariantJob::GALLERY_VARIANT_TRANSFORMATIONS).digest
  end
end
