class Address < ApplicationRecord
  belongs_to :addressable, polymorphic: true

  # Tipos de dirección
  TIPOS = {
    "fiscal" => "Domicilio Fiscal",
    "envio" => "Dirección de Envío",
    "almacen" => "Almacén",
    "entrega" => "Entrega"
  }.freeze

  # Países usando la gema countries
  def self.paises_options
    ISO3166::Country.all.map do |country|
      [ country.alpha2, country.iso_short_name || country.translations["en"] || country.name ]
    end.sort_by { |code, name| name }
  end

  # Países con banderas (usando códigos de país a emoji)
  def self.paises_con_banderas
    ISO3166::Country.all.map do |country|
      name = country.iso_short_name || country.translations["en"] || country.name
      emoji_flag = country_code_to_emoji(country.alpha2)
      display = "#{emoji_flag} #{name}"
      sort_key = I18n.transliterate(name).downcase
      [ display, country.alpha2, sort_key ]
    end
    .sort_by { |(_display, _code, sort_key)| sort_key }
    .map { |display, code, _sort_key| [ display, code ] }
  end

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

  def self.country_code_to_emoji(country_code)
    return "" if country_code.nil? || country_code.empty?

    # Convertir código de país a emoji de bandera
    # Los emojis de banderas usan caracteres regionales (🇦-🇿)
    # que corresponden a las letras A-Z más 0x1F1E6-0x1F1FF
    base = 0x1F1E6
    country_code.upcase.each_char.map do |char|
      (base + (char.ord - "A".ord)).chr("UTF-8")
    end.join
  end

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

  private

  def normalize_codigo_postal
    self.codigo_postal = codigo_postal&.strip&.gsub(/\s+/, "")
    self.pais = pais&.upcase&.strip
  end
end
