class InvoiceLineItem < ApplicationRecord
  belongs_to :invoice
  belongs_to :service_catalog

  before_validation :assign_defaults_from_service_catalog
  before_validation :recalculate_totals

  validates :description, presence: true
  validates :sat_clave_prod_serv, presence: true
  validates :sat_clave_unidad, presence: true
  validates :sat_objeto_imp, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :subtotal, :tax_amount, :total, numericality: { greater_than_or_equal_to: 0 }
  validates :position, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  private

  def assign_defaults_from_service_catalog
    return if service_catalog.blank?

    self.description = service_catalog.name if description.blank?
    self.sat_clave_prod_serv = service_catalog.sat_clave_prod_serv.to_s.presence || sat_clave_prod_serv
    self.sat_clave_unidad = service_catalog.sat_clave_unidad.to_s.presence || sat_clave_unidad
    self.sat_objeto_imp = service_catalog.sat_objeto_imp.to_s.presence || sat_objeto_imp
    self.sat_tasa_iva = service_catalog.sat_tasa_iva if sat_tasa_iva.blank?
    self.unit_price = service_catalog.amount if unit_price.blank?
  end

  def recalculate_totals
    self.position = 0 if position.blank?
    return if quantity.blank? || unit_price.blank?

    self.subtotal = quantity.to_d * unit_price.to_d
    if sat_objeto_imp.to_s == "02"
      self.tax_amount = subtotal.to_d * sat_tasa_iva.to_d
    else
      self.tax_amount = 0
    end
    self.total = subtotal.to_d + tax_amount.to_d
  end
end
