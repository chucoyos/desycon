class BlHouseLineServiceRequest < ApplicationRecord
  STATUSES = %w[pending approved rejected executed].freeze
  STATUS_LABELS = { "pending" => "Pendiente", "approved" => "Autorizada", "rejected" => "Rechazada", "executed" => "Ejecutada" }.freeze
  AUTOMATIC_CODES = %w[BL-ASIG BL-ALMA BL-ALM BL-ENTCAM BL-CODIE BL-COCUS].freeze

  belongs_to :bl_house_line
  belongs_to :service_catalog
  belongs_to :requester, class_name: "User"
  belongs_to :customs_agent, class_name: "Entity"
  belongs_to :bl_house_line_service, optional: true
  has_many :events, class_name: "BlHouseLineServiceRequestEvent", dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :requested_date, presence: true
  validates :scheduled_date, :scheduled_time, presence: true, if: -> { status.in?(%w[approved executed]) }
  validate :eligible_for_request, on: :create

  def self.requestable_catalogs
    ServiceCatalog.for_bl_house_lines.where("UPPER(code) LIKE ?", "%LZC")
      .where.not("UPPER(code) IN (?)", AUTOMATIC_CODES.map { |code| "#{code}-LZC" })
  end

  def approve!(actor:, date:, time:, notes:)
    with_lock do
      raise ActiveRecord::RecordInvalid, self unless pending_transition?

      bl_house_line.lock!
      if bl_house_line.customs_agent_id != customs_agent_id || !compatible_client?
        errors.add(:base, "La partida o su cliente ya no corresponde a la agencia solicitante.")
        raise ActiveRecord::RecordInvalid, self
      end
      if automatic_service_already_present?
        errors.add(:base, "Ya existe el servicio automático correspondiente en la partida; no se puede autorizar esta solicitud.")
        raise ActiveRecord::RecordInvalid, self
      end

      self.scheduled_date = date
      self.scheduled_time = time
      self.review_notes = notes
      self.status = "approved"
      validate!
      service = bl_house_line.bl_house_line_services.create!(
        service_catalog: service_catalog,
        fecha_programada: scheduled_date,
        billed_to_entity_id: bl_house_line.client_id
      )
      update!(bl_house_line_service: service)
      events.create!(actor: actor, action: "approved", scheduled_date: scheduled_date, scheduled_time: scheduled_time, notes: notes)
    end
  end

  def reject!(actor:, notes:)
    with_lock do
      raise ActiveRecord::RecordInvalid, self unless pending_transition?
      if notes.blank?
        errors.add(:base, "El motivo del rechazo es obligatorio.")
        raise ActiveRecord::RecordInvalid, self
      end

      update!(status: "rejected", review_notes: notes)
      events.create!(actor: actor, action: "rejected", notes: notes)
    end
  end

  def reschedule!(actor:, date:, time:, notes:)
    with_lock do
      unless status == "approved"
        errors.add(:base, "Solo se pueden reprogramar solicitudes autorizadas.")
        raise ActiveRecord::RecordInvalid, self
      end

      update!(scheduled_date: date, scheduled_time: time, review_notes: notes)
      bl_house_line_service.update!(fecha_programada: scheduled_date) unless bl_house_line_service.facturado?
      events.create!(actor: actor, action: "rescheduled", scheduled_date: scheduled_date, scheduled_time: scheduled_time, notes: notes)
    end
  end

  def execute!(actor:)
    with_lock do
      unless status == "approved"
        errors.add(:base, "Solo se pueden confirmar solicitudes autorizadas.")
        raise ActiveRecord::RecordInvalid, self
      end

      update!(status: "executed", executed_at: Time.current)
      events.create!(actor: actor, action: "executed")
    end
  end

  private

  def automatic_service_already_present?
    codes = case service_catalog.code.to_s.upcase
    when "BL-ALM-LZC" then %w[BL-ALM-LZC BL-ALMA]
    when "BL-CODIE-LZC" then %w[BL-CODIE-LZC]
    else return false
    end
    bl_house_line.bl_house_line_services.joins(:service_catalog).where("UPPER(service_catalogs.code) IN (?)", codes).exists?
  end

  def pending_transition?
    return true if status == "pending"

    errors.add(:base, "La solicitud ya fue revisada.")
    false
  end

  def eligible_for_request
    return if bl_house_line.blank? || requester.blank? || customs_agent.blank? || service_catalog.blank?

    unless requester.customs_broker? && requester.entity_id == customs_agent_id &&
        customs_agent.role_customs_agent? && bl_house_line.customs_agent_id == customs_agent_id &&
        !bl_house_line.hidden_from_customs_agent?
      errors.add(:base, "La partida no pertenece a la agencia solicitante.")
    end
    errors.add(:base, "La partida debe estar revalidada.") unless bl_house_line.revalidado?
    errors.add(:base, "La partida no corresponde a Lázaro Cárdenas.") unless bl_house_line.container&.destination_port&.code.to_s.upcase == "MXLZC"
    unless compatible_client?
      errors.add(:base, "La partida debe tener un cliente facturable compatible con la agencia.")
    end
    errors.add(:service_catalog, "no está disponible para solicitud.") unless self.class.requestable_catalogs.exists?(id: service_catalog_id)
    errors.add(:base, "La factura de asignación debe estar pagada.") unless assignment_paid?
    if CustomsAgents::RestrictionEvaluatorService.call(customs_agent: customs_agent).restricted || customs_agent.reload.restricted_access_enabled?
      errors.add(:base, "La agencia tiene el acceso restringido.")
    end
  end

  def assignment_paid?
    assignment = bl_house_line.assignment_services.order(id: :desc).first
    return false unless assignment

    direct = assignment.invoices.where(status: "issued", kind: "ingreso")
    linked = Invoice.joins(:invoice_service_links)
      .where(status: "issued", kind: "ingreso", invoice_service_links: { serviceable_type: "BlHouseLineService", serviceable_id: assignment.id })
    (direct.to_a + linked.to_a).uniq.any? { |invoice| invoice.payment_status == "paid" }
  end

  def compatible_client?
    client = bl_house_line.client
    client.present? && (client.customs_agent_id.blank? || client.customs_agent_id == customs_agent_id)
  end
end
