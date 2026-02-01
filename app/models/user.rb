class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :role
  belongs_to :entity, optional: true

  # Associations that reference users; prevent deletion when present
  has_many :container_status_histories, dependent: :restrict_with_error
  has_many :bl_house_line_status_histories, dependent: :restrict_with_error

  has_many :notifications, foreign_key: :recipient_id, dependent: :destroy
  has_many :sent_notifications, class_name: "Notification", foreign_key: :actor_id, dependent: :destroy

  validates :role, presence: true
  validates :disabled, inclusion: { in: [ true, false ] }
  validate :admin_cannot_be_disabled

  # Override Devise password validation to allow blank when updating
  validates :password, presence: true, if: :password_required?
  validates :password_confirmation, presence: true, if: :password_required?

  # Delegaciones para facilitar el acceso a métodos del rol
  delegate :admin?, :executive?, :customs_broker?, :internal?, :admin_or_executive?, to: :role, allow_nil: true

  # Método para obtener el nombre del rol
  def role_name
    role&.name
  end

  def can?(permission_key)
    role&.allows?(permission_key)
  end

  private

  def admin_cannot_be_disabled
    return unless role&.admin?
    return unless disabled?

    errors.add(:disabled, "no puede activarse para cuentas admin")
  end

  # Only require password when creating a new user
  def password_required?
    new_record? || password.present?
  end
end
