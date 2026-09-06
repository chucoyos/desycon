class ConsolidatorApiCredential < ApplicationRecord
  KEY_PREFIX_LENGTH = 16

  belongs_to :entity

  scope :active, -> {
    where(revoked_at: nil)
      .where("expires_at IS NULL OR expires_at > ?", Time.current)
  }

  validates :name, presence: true
  validates :key_prefix, :key_digest, presence: true
  validate :entity_must_be_consolidator

  def self.issue!(entity:, name:, expires_at: nil)
    raise ArgumentError, "Entity must be a consolidator" unless entity&.role_consolidator?

    raw_key = "dsc_#{Rails.env.production? ? "live" : "test"}_#{SecureRandom.urlsafe_base64(32)}"
    credential = create!(
      entity: entity,
      name: name,
      key_prefix: raw_key.first(KEY_PREFIX_LENGTH),
      key_digest: digest_for(raw_key),
      expires_at: expires_at
    )

    [ credential, raw_key ]
  end

  def self.authenticate(raw_key)
    return if raw_key.blank?

    credential = active.find_by(key_prefix: raw_key.first(KEY_PREFIX_LENGTH))
    return unless credential
    return unless ActiveSupport::SecurityUtils.secure_compare(credential.key_digest, digest_for(raw_key))

    credential
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def touch_last_used!
    update_columns(last_used_at: Time.current, updated_at: Time.current)
  end

  def self.digest_for(raw_key)
    Digest::SHA256.hexdigest(raw_key.to_s)
  end

  private

  def entity_must_be_consolidator
    return if entity&.role_consolidator?

    errors.add(:entity, "must be a consolidator")
  end
end
