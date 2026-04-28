class PhotoDownloadLink < ApplicationRecord
  PUBLIC_TTL = 72.hours

  belongs_to :attachable, polymorphic: true
  belongs_to :created_by, class_name: "User"
  belongs_to :revoked_by, class_name: "User", optional: true

  validates :section, presence: true
  validates :expires_at, presence: true
  validate :section_allowed_for_attachable

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def revoked?
    revoked_at.present?
  end

  def revoke!(revoked_by: nil)
    update!(revoked_at: Time.current, revoked_by: revoked_by)
  end

  private

  def section_allowed_for_attachable
    return if attachable.blank? || section.blank?

    allowed_sections = Photo.allowed_sections_for(attachable) + [ PhotoArchiveRequest::SECTION_ALL ]
    return if allowed_sections.include?(section)

    errors.add(:section, "no es válida para este tipo de registro")
  end
end
