# frozen_string_literal: true

module BlHouseLines
  class ReassignService
    class Error < StandardError; end

    def initialize(bl_house_line:, new_customs_agent_id:, new_customs_agent_patent_id:, new_client_id:, hide_original: true, current_user: nil)
      @bl_house_line = bl_house_line
      @new_customs_agent_id = new_customs_agent_id
      @new_customs_agent_patent_id = new_customs_agent_patent_id
      @new_client_id = new_client_id
      @hide_original = hide_original
      @current_user = current_user
      @original_blhouse = bl_house_line.blhouse
    end

    def call
      ActiveRecord::Base.transaction do
        rename_original_blhouse!
        hide_original_line!
        clone_line!
      end
    end

    private

    attr_reader :bl_house_line, :new_customs_agent_id, :new_customs_agent_patent_id, :new_client_id, :hide_original, :current_user

    def rename_original_blhouse!
      base = original_blhouse.to_s
      suffix_index = 0

      loop do
        candidate = suffix_index.zero? ? "#{base}R" : "#{base}R#{suffix_index + 1}"
        unless BlHouseLine.where(container_id: bl_house_line.container_id, blhouse: candidate).exists?
          bl_house_line.update!(blhouse: candidate)
          break
        end
        suffix_index += 1
      end
    end

    def hide_original_line!
      return unless hide_original

      bl_house_line.update!(hidden_from_customs_agent: true)
    end

    def clone_line!
      cloned = bl_house_line.dup
      cloned.assign_attributes(
        blhouse: original_blhouse,
        customs_agent_id: new_customs_agent_id,
        customs_agent_patent_id: new_customs_agent_patent_id,
        client_id: new_client_id,
        partida: nil,
        status: BlHouseLine.statuses[:revalidado],
        hidden_from_customs_agent: false,
        skip_revalidation_notification: true
      )

      mark_docs_validated(cloned)
      attach_existing_documents(cloned)

      cloned.save!

      duplicate_services_for(cloned)
      notify_new_agent(cloned)

      cloned
    end

    def original_blhouse
      @original_blhouse
    end

    def mark_docs_validated(record)
      BlHouseLine::DOCUMENT_FIELDS.each do |field|
        setter = "#{field}_validated="
        record.public_send(setter, true) if record.respond_to?(setter)
      end
    end

    def attach_existing_documents(record)
      BlHouseLine::DOCUMENT_FIELDS.each do |field|
        next unless bl_house_line.public_send(field).attached?

        record.public_send(field).attach(bl_house_line.public_send(field).blob)
      end
    end

    def duplicate_services_for(cloned)
      bl_house_line.bl_house_line_services.find_each do |service|
        cloned.bl_house_line_services.create!(
          service_catalog_id: service.service_catalog_id,
          billed_to_entity_id: new_client_id.presence || new_customs_agent_id,
          fecha_programada: service.fecha_programada,
          observaciones: service.observaciones,
          factura: nil
        )
      end
    end

    def notify_new_agent(cloned)
      return unless new_customs_agent_id

      recipients = User.where(entity_id: new_customs_agent_id)
      return if recipients.empty?

      recipients.each do |recipient|
        Notification.create!(
          recipient: recipient,
          actor: current_user,
          notifiable: cloned,
          action: "Partida reasignada"
        )
      end
    end
  end
end
