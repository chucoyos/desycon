class FiscalProfile < ApplicationRecord
  belongs_to :profileable, polymorphic: true

  # Catálogos SAT (simplificados - expandir según necesidad)
  REGIMENES = {
    "601" => "General de Ley Personas Morales",
    "603" => "Personas Morales con Fines no Lucrativos",
    "605" => "Sueldos y Salarios e Ingresos Asimilados a Salarios",
    "606" => "Arrendamiento",
    "608" => "Demás ingresos",
    "610" => "Residentes en el Extranjero sin Establecimiento Permanente en México",
    "611" => "Ingresos por Dividendos (socios y accionistas)",
    "612" => "Personas Físicas con Actividades Empresariales y Profesionales",
    "614" => "Ingresos por intereses",
    "616" => "Sin obligaciones fiscales",
    "620" => "Sociedades Cooperativas de Producción que optan por diferir sus ingresos",
    "621" => "Incorporación Fiscal",
    "622" => "Actividades Agrícolas, Ganaderas, Silvícolas y Pesqueras",
    "623" => "Opcional para Grupos de Sociedades",
    "624" => "Coordinados",
    "625" => "Régimen de las Actividades Empresariales con ingresos a través de Plataformas Tecnológicas",
    "626" => "Régimen Simplificado de Confianza"
  }.freeze

  USOS_CFDI = {
    "G01" => "Adquisición de mercancías",
    "G02" => "Devoluciones, descuentos o bonificaciones",
    "G03" => "Gastos en general",
    "I01" => "Construcciones",
    "I02" => "Mobilario y equipo de oficina por inversiones",
    "I03" => "Equipo de transporte",
    "I04" => "Equipo de computo y accesorios",
    "I05" => "Dados, troqueles, moldes, matrices y herramental",
    "I06" => "Comunicaciones telefónicas",
    "I07" => "Comunicaciones satelitales",
    "I08" => "Otra maquinaria y equipo",
    "D01" => "Honorarios médicos, dentales y gastos hospitalarios",
    "D02" => "Gastos médicos por incapacidad o discapacidad",
    "D03" => "Gastos funerales",
    "D04" => "Donativos",
    "D05" => "Intereses reales efectivamente pagados por créditos hipotecarios (casa habitación)",
    "D06" => "Aportaciones voluntarias al SAR",
    "D07" => "Primas por seguros de gastos médicos",
    "D08" => "Gastos de transportación escolar obligatoria",
    "D09" => "Depósitos en cuentas para el ahorro, primas que tengan como base planes de pensiones",
    "D10" => "Pagos por servicios educativos (colegiaturas)",
    "S01" => "Sin efectos fiscales",
    "CP01" => "Pagos",
    "CN01" => "Nómina"
  }.freeze

  FORMAS_PAGO = {
    "01" => "Efectivo",
    "02" => "Cheque nominativo",
    "03" => "Transferencia electrónica de fondos",
    "04" => "Tarjeta de crédito",
    "05" => "Monedero electrónico",
    "06" => "Dinero electrónico",
    "08" => "Vales de despensa",
    "12" => "Dación en pago",
    "13" => "Pago por subrogación",
    "14" => "Pago por consignación",
    "15" => "Condonación",
    "17" => "Compensación",
    "23" => "Novación",
    "24" => "Confusión",
    "25" => "Remisión de deuda",
    "26" => "Prescripción o caducidad",
    "27" => "A satisfacción del acreedor",
    "28" => "Tarjeta de débito",
    "29" => "Tarjeta de servicios",
    "30" => "Aplicación de anticipos",
    "31" => "Intermediario pagos",
    "99" => "Por definir"
  }.freeze

  METODOS_PAGO = {
    "PUE" => "Pago en una sola exhibición",
    "PPD" => "Pago en parcialidades o diferido"
  }.freeze

  # Validaciones
  validates :razon_social, presence: true, length: { maximum: 254 }
  validates :rfc, presence: true,
                  length: { in: 12..13, message: "debe tener 12 caracteres (persona moral) o 13 caracteres (persona física)" },
                  format: { with: /\A[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{3}\z/, message: "formato inválido" },
                  uniqueness: { case_sensitive: false }
  validates :regimen, presence: true, inclusion: { in: REGIMENES.keys }
  validates :uso_cfdi, inclusion: { in: USOS_CFDI.keys }, allow_blank: true
  validates :forma_pago, inclusion: { in: FORMAS_PAGO.keys }, allow_blank: true
  validates :metodo_pago, inclusion: { in: METODOS_PAGO.keys }, allow_blank: true

  # Normalización
  before_validation :normalize_rfc

  # Scopes
  scope :by_rfc, ->(rfc) { where("UPPER(rfc) = ?", rfc.upcase) }

  def to_s
    razon_social
  end

  def regimen_nombre
    REGIMENES[regimen]
  end

  def uso_cfdi_nombre
    USOS_CFDI[uso_cfdi]
  end

  def forma_pago_nombre
    FORMAS_PAGO[forma_pago]
  end

  def metodo_pago_nombre
    METODOS_PAGO[metodo_pago]
  end

  private

  def normalize_rfc
    self.rfc = rfc&.upcase&.strip
  end
end
