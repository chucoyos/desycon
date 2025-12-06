class Address < ApplicationRecord
  belongs_to :addressable, polymorphic: true

  # Tipos de dirección
  TIPOS = {
    "fiscal" => "Domicilio Fiscal",
    "envio" => "Dirección de Envío",
    "almacen" => "Almacén",
    "entrega" => "Entrega"
  }.freeze

  # Países
  PAISES = {
    "MX" => "México",
    "US" => "Estados Unidos",
    "CA" => "Canadá",
    "ES" => "España"
  }.freeze

  # Validaciones
  validates :pais, presence: true, length: { is: 2 }, format: { with: /\A[A-Z]{2}\z/ }
  validates :codigo_postal, presence: true, length: { maximum: 10 }
  validates :estado, presence: true, length: { maximum: 100 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :calle, length: { maximum: 200 }, allow_blank: true
  validates :municipio, length: { maximum: 100 }, allow_blank: true
  validates :localidad, length: { maximum: 100 }, allow_blank: true
  validates :colonia, length: { maximum: 100 }, allow_blank: true
  validates :numero_exterior, length: { maximum: 20 }, allow_blank: true
  validates :numero_interior, length: { maximum: 20 }, allow_blank: true
  validates :tipo, inclusion: { in: TIPOS.keys }, allow_blank: true

  # Normalización
  before_validation :normalize_codigo_postal

  # Scopes
  scope :fiscales, -> { where(tipo: "fiscal") }
  scope :envio, -> { where(tipo: "envio") }
  scope :almacenes, -> { where(tipo: "almacen") }
  scope :by_codigo_postal, ->(cp) { where(codigo_postal: cp) }

  def to_s
    [
      calle,
      numero_exterior,
      numero_interior.present? ? "Int. #{numero_interior}" : nil,
      colonia,
      "CP #{codigo_postal}",
      municipio,
      estado,
      pais
    ].compact.join(", ")
  end

  def domicilio_completo
    to_s
  end

  def tipo_nombre
    TIPOS[tipo] || tipo
  end

  private

  def normalize_codigo_postal
    self.codigo_postal = codigo_postal&.strip&.gsub(/\s+/, "")
    self.pais = pais&.upcase&.strip
  end
end
