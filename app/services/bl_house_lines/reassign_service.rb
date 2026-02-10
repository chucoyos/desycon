# frozen_string_literal: true

module BlHouseLines
  class ReassignService
    class Error < StandardError; end

    def initialize(bl_house_line:, new_customs_agent_id:, new_customs_broker_id:, new_client_id:, current_user: nil)
      @bl_house_line = bl_house_line
      @new_customs_agent_id = new_customs_agent_id
      @new_customs_broker_id = new_customs_broker_id
      @new_client_id = new_client_id
      @current_user = current_user
    end

    def call
      ActiveRecord::Base.transaction do
        apply_reassign!
        add_reassign_service!
        notify_new_agent
      end
    end

    private

    attr_reader :bl_house_line, :new_customs_agent_id, :new_customs_broker_id, :new_client_id, :current_user

    def apply_reassign!
      new_broker_id = new_customs_broker_id.presence
      new_client_id_value = new_client_id.presence

      raise Error, "Debes seleccionar un broker." if new_broker_id.blank?
      raise Error, "Debes seleccionar un cliente." if new_client_id_value.blank?

      bl_house_line.update!(
        customs_agent_id: new_customs_agent_id.presence || bl_house_line.customs_agent_id,
        customs_broker_id: new_broker_id,
        client_id: new_client_id_value
      )
    end

    def add_reassign_service!
      catalog = ServiceCatalog.find_by(code: "BL-ASIG", applies_to: "bl_house_line")
      catalog ||= ServiceCatalog.find_by(name: "Asignación electrónica de carga", applies_to: "bl_house_line")
      return unless catalog

      bl_house_line.bl_house_line_services.create!(
        service_catalog_id: catalog.id,
        billed_to_entity_id: new_client_id.presence || new_customs_agent_id.presence || bl_house_line.customs_agent_id,
        factura: nil
      )
    end

    def notify_new_agent
      return unless new_customs_agent_id.present?

      recipients = User.where(entity_id: new_customs_agent_id)
      return if recipients.empty?

      recipients.each do |recipient|
        Notification.create!(
          recipient: recipient,
          actor: current_user,
          notifiable: bl_house_line,
          action: "Partida reasignada"
        )
      end
    end
  end
end
