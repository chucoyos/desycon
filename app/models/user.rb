class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :role
  belongs_to :entity, optional: true

  validates :role, presence: true

  # Override Devise password validation to allow blank when updating
  validates :password, presence: true, if: :password_required?
  validates :password_confirmation, presence: true, if: :password_required?

  # Delegaciones para facilitar el acceso a métodos del rol
  delegate :admin?, :operator?, :customs_broker?, :internal?, to: :role, allow_nil: true

  # Método para obtener el nombre del rol
  def role_name
    role&.name
  end

  private

  # Only require password when creating a new user
  def password_required?
    new_record? || password.present?
  end
end
