class Address < ApplicationRecord
  belongs_to :addressable, polymorphic: true

  # Tipos de dirección
  TIPOS = {
    "matriz" => "Matriz",
    "sucursal" => "Sucursal"
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

  def self.country_display_label(country_code)
    return "" if country_code.blank?

    country = ISO3166::Country[country_code.to_s.upcase]
    return country_code.to_s.upcase if country.blank?

    name = country.iso_short_name || country.translations["en"] || country.name
    "#{country_code_to_emoji(country.alpha2)} #{name}"
  end

  def self.search_countries(query, limit: 20)
    normalized_query = I18n.transliterate(query.to_s).downcase
    return [] if normalized_query.blank?

    ISO3166::Country.all
      .map do |country|
        code = country.alpha2
        name = country.iso_short_name || country.translations["en"] || country.name
        normalized_name = I18n.transliterate(name).downcase

        {
          code:,
          label: "#{country_code_to_emoji(code)} #{name}",
          normalized_name:,
          starts_with: normalized_name.start_with?(normalized_query)
        }
      end
      .select do |country|
        country[:normalized_name].include?(normalized_query) || country[:code].downcase.include?(normalized_query)
      end
      .sort_by { |country| [ country[:starts_with] ? 0 : 1, country[:normalized_name] ] }
      .first(limit)
      .map do |country|
        {
          id: country[:code],
          label: country[:label],
          subtitle: country[:code]
        }
      end
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
  validates :pais, length: { is: 2 }, format: { with: /\A[A-Z]{2}\z/ }, allow_blank: true
  validates :codigo_postal, presence: true, length: { maximum: 10 }
  validates :estado, length: { maximum: 100 }, allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :calle, length: { maximum: 200 }, allow_blank: true
  validates :municipio, length: { maximum: 100 }, allow_blank: true
  validates :localidad, length: { maximum: 100 }, allow_blank: true
  validates :colonia, length: { maximum: 100 }, allow_blank: true
  validates :numero_exterior, length: { maximum: 20 }, allow_blank: true
  validates :numero_interior, length: { maximum: 20 }, allow_blank: true
  validates :tipo, inclusion: { in: TIPOS.keys }, allow_blank: true

  # Normalización
  before_validation :set_default_tipo
  before_validation :normalize_codigo_postal

  # Scopes
  scope :matriz, -> { where(tipo: "matriz") }
  scope :sucursales, -> { where(tipo: "sucursal") }
  scope :by_codigo_postal, ->(cp) { where(codigo_postal: cp) }

  private

  def normalize_codigo_postal
    self.codigo_postal = codigo_postal&.strip&.gsub(/\s+/, "")
    self.pais = pais&.upcase&.strip
  end

  def set_default_tipo
    self.tipo = "matriz" if tipo.blank?
  end
end
