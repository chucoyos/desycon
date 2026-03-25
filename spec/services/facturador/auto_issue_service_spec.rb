require "rails_helper"

RSpec.describe Facturador::AutoIssueService, type: :service do
  describe ".call" do
    let(:issuer) { create_entity_with_fiscal_data(:customs_agent) }

    before do
      allow(Facturador::Config).to receive(:enabled?).and_return(true)
      allow(Facturador::Config).to receive(:auto_issue_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:issuer_entity_id).and_return(issuer.id)
      allow_any_instance_of(Invoice).to receive(:queue_issue!).and_return(true)
    end

    it "skips auto issue for BlHouseLineService when configured RFC matches consolidator and billed client" do
      consolidator = create_entity_with_fiscal_data(:consolidator)
      receiver = create_entity_with_fiscal_data(:client, :client_of_customs_agent)
      consolidator.fiscal_profile.update!(rfc: "EWE1709045U0")
      receiver.fiscal_profile.update!(rfc: "EWE1709045U0")

      container = create(:container, consolidator_entity: consolidator)
      bl_house_line = create(:bl_house_line, container: container, client: receiver)
      service = create(:bl_house_line_service, bl_house_line: bl_house_line, billed_to_entity: receiver, amount: 100)

      allow(Facturador::Config).to receive(:auto_issue_nipon_exception_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:auto_issue_nipon_rfc).and_return("EWE1709045U0")

      expect {
        described_class.call(invoiceable: service)
      }.not_to change(Invoice, :count)
    end

    it "does not skip auto issue when RFC does not match configured exception" do
      consolidator = create_entity_with_fiscal_data(:consolidator)
      receiver = create_entity_with_fiscal_data(:client, :client_of_customs_agent)
      consolidator.fiscal_profile.update!(rfc: "ABC010101AAA")
      receiver.fiscal_profile.update!(rfc: "ABC010101AAA")

      container = create(:container, consolidator_entity: consolidator)
      bl_house_line = create(:bl_house_line, container: container, client: receiver)
      service = create(:bl_house_line_service, bl_house_line: bl_house_line, billed_to_entity: receiver, amount: 100)

      allow(Facturador::Config).to receive(:auto_issue_nipon_exception_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:auto_issue_nipon_rfc).and_return("EWE1709045U0")

      expect {
        described_class.call(invoiceable: service)
      }.to change(Invoice, :count).by(1)
    end

    it "does not apply Nipon exception to ContainerService" do
      consolidator = create_entity_with_fiscal_data(:consolidator)
      consolidator.fiscal_profile.update!(rfc: "EWE1709045U0")

      container = create(:container, consolidator_entity: consolidator)
      service = create(:container_service, container: container, billed_to_entity: consolidator, amount: 100)

      allow(Facturador::Config).to receive(:auto_issue_nipon_exception_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:auto_issue_nipon_rfc).and_return("EWE1709045U0")

      expect {
        described_class.call(invoiceable: service)
      }.to change(Invoice, :count).by(1)
    end
  end

  def create_entity_with_fiscal_data(*traits)
    entity = create(:entity, *traits)
    create(:fiscal_profile, profileable: entity)
    create(:address, addressable: entity, tipo: "matriz")
    entity.reload
  end
end
