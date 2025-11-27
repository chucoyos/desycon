class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :role

  validates :role, presence: true

  # Delegaciones para facilitar el acceso a métodos del rol
  delegate :admin?, :operator?, :customs_broker?, :internal?, to: :role, allow_nil: true

  # Método para obtener el nombre del rol
  def role_name
    role&.name
  end
end
