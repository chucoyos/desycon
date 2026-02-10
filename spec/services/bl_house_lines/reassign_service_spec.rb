require "rails_helper"

RSpec.describe BlHouseLines::ReassignService do
  let(:current_user) { create(:user, :executive) }
  let(:original_agent) { create(:entity, :customs_agent) }
  let(:new_agent) { create(:entity, :customs_agent) }
  let(:new_broker) { create(:entity, :customs_broker) }
  let(:new_client) { create(:entity, :client, customs_agent: new_agent) }
  let(:bl_house_line) { create(:bl_house_line, customs_agent: original_agent) }

  let!(:agency_broker_link) { AgencyBroker.create!(agency: new_agent, broker: new_broker) }
  let!(:catalog) do
    create(:service_catalog,
      name: "Asignacion electronica de carga",
      code: "BL-ASIG",
      applies_to: "bl_house_line")
  end

  it "updates the bl house line and adds the reassignment service" do
    expect {
      described_class.new(
        bl_house_line: bl_house_line,
        new_customs_agent_id: new_agent.id,
        new_customs_broker_id: new_broker.id,
        new_client_id: new_client.id,
        current_user: current_user
      ).call
    }.to change(BlHouseLineService, :count).by(1)

    bl_house_line.reload
    expect(bl_house_line.customs_agent_id).to eq(new_agent.id)
    expect(bl_house_line.customs_broker_id).to eq(new_broker.id)
    expect(bl_house_line.client_id).to eq(new_client.id)

    service = bl_house_line.bl_house_line_services.last
    expect(service.service_catalog_id).to eq(catalog.id)
    expect(service.billed_to_entity_id).to eq(new_client.id)
  end

  it "creates notifications for users of the new agent" do
    recipient = create(:user, :customs_broker, entity: new_agent)

    expect {
      described_class.new(
        bl_house_line: bl_house_line,
        new_customs_agent_id: new_agent.id,
        new_customs_broker_id: new_broker.id,
        new_client_id: new_client.id,
        current_user: current_user
      ).call
    }.to change(Notification, :count).by(1)

    notification = Notification.order(:created_at).last
    expect(notification.recipient).to eq(recipient)
    expect(notification.actor).to eq(current_user)
    expect(notification.notifiable).to eq(bl_house_line)
    expect(notification.action).to eq("Partida reasignada")
  end

  it "raises when broker is missing" do
    expect {
      described_class.new(
        bl_house_line: bl_house_line,
        new_customs_agent_id: new_agent.id,
        new_customs_broker_id: nil,
        new_client_id: new_client.id,
        current_user: current_user
      ).call
    }.to raise_error(BlHouseLines::ReassignService::Error, "Debes seleccionar un broker.")
  end
end
