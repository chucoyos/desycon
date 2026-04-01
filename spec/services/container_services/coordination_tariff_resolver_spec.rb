require "rails_helper"

RSpec.describe ContainerServices::CoordinationTariffResolver do
  PortStub = Struct.new(:code)
  FiscalProfileStub = Struct.new(:rfc)
  ConsolidatorStub = Struct.new(:fiscal_profile)
  ContainerStub = Struct.new(:consolidator_entity, :destination_port, :recinto, :almacen)

  def build_container(rfc:, port_code:, recinto:, almacen:)
    ContainerStub.new(
      ConsolidatorStub.new(FiscalProfileStub.new(rfc)),
      PortStub.new(port_code),
      recinto,
      almacen
    )
  end

  describe ".call" do
    context "when RFC alias is enabled in development" do
      it "does not assign Veracruz tariff because NIPPON has no Veracruz rule" do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))

        container = build_container(
          rfc: "EWE1709045U0",
          port_code: "MXVER",
          recinto: "ICAVE",
          almacen: "CICE"
        )

        expect(described_class.call(container: container)).to be_nil
      end

      it "treats EWE as NIPPON for Manzanillo matrix no-tariff rules" do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))

        container = build_container(
          rfc: "EWE1709045U0",
          port_code: "MXZLO",
          recinto: "CONTECON",
          almacen: "HAZESA"
        )

        expect(described_class.call(container: container)).to be_nil
      end
    end

    context "when RFC alias is enabled in staging" do
      it "applies NIPPON positive matrix rule for EWE" do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("staging"))

        container = build_container(
          rfc: "EWE1709045U0",
          port_code: "MXZLO",
          recinto: "CONTECON",
          almacen: "SSA"
        )

        expect(described_class.call(container: container)).to eq(BigDecimal("3500"))
      end
    end

    context "when environment is production" do
      it "does not apply EWE alias" do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))

        container = build_container(
          rfc: "EWE1709045U0",
          port_code: "MXVER",
          recinto: "ICAVE",
          almacen: "CICE"
        )

        expect(described_class.call(container: container)).to be_nil
      end
    end
  end
end
