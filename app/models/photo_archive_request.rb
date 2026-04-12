class PhotoArchiveRequest < ApplicationRecord
  SECTION_ALL = "todas_las_secciones".freeze
  ARCHIVE_TTL = 2.months
  PROCESSING_TIMEOUT = 15.minutes

  belongs_to :attachable, polymorphic: true
  belongs_to :requested_by, class_name: "User"

  has_one_attached :archive

  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }

  validates :section, presence: true
  validates :status, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def in_progress?
    pending? || processing?
  end

  def stale_in_progress?(timeout: PROCESSING_TIMEOUT)
    return false unless in_progress?

    reference_time = updated_at || created_at
    reference_time < timeout.ago
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def mark_processing!
    update!(status: :processing, error_message: nil)
  end

  def mark_failed!(message)
    update!(status: :failed, error_message: message.to_s.truncate(500))
  end

  def mark_completed!(photos_count:)
    update!(
      status: :completed,
      photos_count: photos_count,
      generated_at: Time.current,
      expires_at: Time.current + ARCHIVE_TTL,
      error_message: nil
    )
  end
end
