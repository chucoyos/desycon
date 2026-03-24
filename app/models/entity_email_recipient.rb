class EntityEmailRecipient < ApplicationRecord
  belongs_to :entity

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(primary_recipient: :desc, position: :asc, id: :asc) }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { scope: :entity_id, case_sensitive: false }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :entity_role_supported

  before_validation :normalize_email

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def entity_role_supported
    return if entity.blank?
    return if entity.role_customs_agent? || entity.role_consolidator?

    errors.add(:entity, "solo puede configurar correos para agencia aduanal o consolidador")
  end
end
