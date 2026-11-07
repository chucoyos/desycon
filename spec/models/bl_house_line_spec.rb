require 'rails_helper'

RSpec.describe BlHouseLine, type: :model do
  let(:shipping_line) { create(:shipping_line) }
  let(:container) { create(:container, shipping_line: shipping_line) }
  let(:other_container) { create(:container, shipping_line: shipping_line) }

  describe 'validations' do
    subject { build(:bl_house_line) }

    it 'validates presence of blhouse' do
      subject.blhouse = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:blhouse]).to include("no puede estar en blanco")
    end

    it 'validates presence of partida' do
      subject.partida = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:partida]).to include("no puede estar en blanco")
    end

    it 'validates partida is a positive integer' do
      subject.partida = 0
      expect(subject).not_to be_valid
      expect(subject.errors[:partida]).to include("debe ser mayor que 0")

      subject.partida = -1
      expect(subject).not_to be_valid
      expect(subject.errors[:partida]).to include("debe ser mayor que 0")

      subject.partida = 1.5
      expect(subject).not_to be_valid
      expect(subject.errors[:partida]).to include("debe ser un entero")
    end

    it 'validates presence of cantidad' do
      subject.cantidad = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:cantidad]).to include("no puede estar en blanco")
    end

    it 'validates cantidad is a positive integer' do
      subject.cantidad = 0
      expect(subject).not_to be_valid
      expect(subject.errors[:cantidad]).to include("debe ser mayor que 0")
    end

    context 'partida uniqueness within container scope' do
      let!(:existing_bl_house_line) { create(:bl_house_line, container: container, partida: 1) }

      it 'allows same partida number in different containers' do
        new_bl_house_line = build(:bl_house_line, container: other_container, partida: 1)
        expect(new_bl_house_line).to be_valid
      end

      it 'does not allow duplicate partida within same container' do
        new_bl_house_line = build(:bl_house_line, container: container, partida: 1)
        expect(new_bl_house_line).not_to be_valid
        expect(new_bl_house_line.errors[:partida]).to include('debe ser único dentro del contenedor')
      end
    end
  end

  describe 'auto-increment partida number' do
    context 'when container is present' do
      it 'automatically assigns partida 1 for first bl_house_line in container' do
        bl_house_line = BlHouseLine.create!(
          blhouse: "BLH001",
          cantidad: 10,
          contiene: "Test content",
          marcas: "Test marks",
          peso: 1.0,
          volumen: 1.0,
          packaging: create(:packaging),
          container: container
        )
        expect(bl_house_line.partida).to eq(1)
      end

      it 'automatically assigns next available partida number' do
        BlHouseLine.create!(
          blhouse: "BLH001",
          partida: 1,
          cantidad: 10,
          contiene: "Test content",
          marcas: "Test marks",
          peso: 1.0,
          volumen: 1.0,
          packaging: create(:packaging),
          container: container
        )
        BlHouseLine.create!(
          blhouse: "BLH002",
          partida: 3,
          cantidad: 10,
          contiene: "Test content",
            marcas: "Test marks",
            peso: 1.0,
            volumen: 1.0,
            packaging: create(:packaging),
            container: container
        )

        bl_house_line = BlHouseLine.create!(
          blhouse: "BLH003",
          cantidad: 10,
          contiene: "Test content",
            marcas: "Test marks",
            peso: 1.0,
            volumen: 1.0,
            packaging: create(:packaging),
            container: container
        )
        expect(bl_house_line.partida).to eq(4)
      end

      it 'does not auto-assign if partida is already set' do
        bl_house_line = BlHouseLine.create!(
          blhouse: "BLH001",
          partida: 5,
          cantidad: 10,
          contiene: "Test content",
          marcas: "Test marks",
          peso: 1.0,
          volumen: 1.0,
          packaging: create(:packaging),
          container: container
        )
        expect(bl_house_line.partida).to eq(5)
      end

      it 'handles different containers independently' do
        BlHouseLine.create!(
          blhouse: "BLH001",
          partida: 1,
          cantidad: 10,
          contiene: "Test content",
          marcas: "Test marks",
          peso: 1.0,
          volumen: 1.0,
          packaging: create(:packaging),
          container: container
        )

        bl_house_line = BlHouseLine.create!(
          blhouse: "BLH002",
          cantidad: 10,
          contiene: "Test content",
            marcas: "Test marks",
            peso: 1.0,
            volumen: 1.0,
            packaging: create(:packaging),
            container: other_container
        )
        expect(bl_house_line.partida).to eq(1)
      end
    end

    context 'when container is not present' do
      it 'does not auto-assign partida number' do
        bl_house_line = BlHouseLine.new(
          blhouse: "BLH001",
          cantidad: 10,
          contiene: "Test content",
          marcas: "Test marks"
        )
        bl_house_line.valid?
        expect(bl_house_line.partida).to be_nil
      end
    end
  end

  describe 'relationships' do
    it 'belongs to customs_agent' do
      association = described_class.reflect_on_association(:customs_agent)
      expect(association.macro).to eq(:belongs_to)
      expect(association.class_name).to eq('Entity')
      expect(association.options[:optional]).to be_truthy
    end

    it 'belongs to client' do
      association = described_class.reflect_on_association(:client)
      expect(association.macro).to eq(:belongs_to)
      expect(association.class_name).to eq('Entity')
      expect(association.options[:optional]).to be_truthy
    end

    it 'belongs to container' do
      association = described_class.reflect_on_association(:container)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:optional]).to be_truthy
    end

    it 'belongs to packaging' do
      association = described_class.reflect_on_association(:packaging)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:optional]).to be_truthy
    end

    it 'has many bl_house_line_status_histories' do
      association = described_class.reflect_on_association(:bl_house_line_status_histories)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:destroy)
    end
  end

  describe 'enums' do
    it 'defines status enum with correct values' do
      expect(described_class.statuses).to eq({
        "activo" => "activo",
        "validar_documentos" => "validar_documentos",
        "instrucciones_pendientes" => "instrucciones_pendientes",
        "documentos_ok" => "documentos_ok",
        "revalidado" => "revalidado",
        "despachado" => "despachado",
        "abandono" => "abandono"
      })
    end
  end

  describe '#revalidated_at' do
    it 'returns nil when there is no revalidated status history' do
      bl_house_line = create(:bl_house_line, status: 'activo')

      expect(bl_house_line.revalidated_at).to be_nil
    end

    it 'returns the latest changed_at for revalidated status' do
      bl_house_line = create(:bl_house_line, status: 'activo')
      older_revalidated_at = Time.zone.local(2026, 4, 10, 9, 0, 0)
      latest_revalidated_at = Time.zone.local(2026, 4, 11, 11, 30, 0)

      create(:bl_house_line_status_history,
             bl_house_line: bl_house_line,
             status: 'revalidado',
             changed_at: older_revalidated_at)
      create(:bl_house_line_status_history,
             bl_house_line: bl_house_line,
             status: 'documentos_ok',
             changed_at: Time.zone.local(2026, 4, 10, 13, 0, 0))
      create(:bl_house_line_status_history,
             bl_house_line: bl_house_line,
             status: 'revalidado',
             changed_at: latest_revalidated_at)

      expect(bl_house_line.revalidated_at).to eq(latest_revalidated_at)
    end
  end

  describe 'imo normalization and multiplier' do
    it 'normalizes blank imo fields to 0 before validation' do
      bl_house_line = create(:bl_house_line, clase_imo: '  ', tipo_imo: '')

      expect(bl_house_line.clase_imo).to eq('0')
      expect(bl_house_line.tipo_imo).to eq('0')
    end

    it 'returns multiplier 2 only when clase and tipo are different from 0' do
      bl_house_line = create(:bl_house_line, clase_imo: '1', tipo_imo: '2')
      expect(bl_house_line.imo_charge_multiplier).to eq(BigDecimal('2'))

      bl_house_line.update!(tipo_imo: '0')
      expect(bl_house_line.imo_charge_multiplier).to eq(BigDecimal('1'))
    end
  end

  describe 'asignación electrónica de carga service' do
    let!(:catalog) { create(:service_catalog, name: "Asignación electrónica de carga", applies_to: "bl_house_line", amount: 950.0, currency: "MXN") }
    let(:bl_house_line) { create(:bl_house_line, status: "documentos_ok") }

    it 'creates the service when status changes to revalidado' do
      expect {
        bl_house_line.update!(status: "revalidado")
      }.to change { bl_house_line.reload.bl_house_line_services.count }.by(1)

      service = bl_house_line.bl_house_line_services.last
      expect(service.service_catalog).to eq(catalog)
      expect(service.billed_to_entity_id).to eq(bl_house_line.client_id)
    end

    it 'does not duplicate the service on subsequent saves' do
      bl_house_line.update!(status: "revalidado")

      expect {
        bl_house_line.update!(status: "revalidado")
      }.not_to change { bl_house_line.reload.bl_house_line_services.count }
    end

    it 'skips creation if the catalog entry is missing' do
      catalog.destroy

      expect {
        bl_house_line.update!(status: "revalidado")
      }.not_to change { bl_house_line.reload.bl_house_line_services.count }
    end
  end

  describe 'almacenaje service' do
    let!(:catalog) do
      create(
        :service_catalog,
        name: "Almacenaje",
        code: "BL-ALMA",
        applies_to: "bl_house_line",
        amount: 170.91,
        currency: "MXN"
      )
    end
    let!(:codie_veracruz_catalog) do
      create(
        :service_catalog,
        name: "Control Documental Veracruz",
        code: "BL-CODIE",
        applies_to: "bl_house_line",
        amount: 754.0,
        currency: "MXN"
      )
    end
    let!(:codie_altamira_catalog) do
      create(
        :service_catalog,
        name: "Control Documental Altamira",
        code: "BL-CODIE-ATM",
        applies_to: "bl_house_line",
        amount: 700.0,
        currency: "MXN"
      )
    end
    let!(:cocus_veracruz_catalog) do
      create(
        :service_catalog,
        name: "Custodia Veracruz",
        code: "BL-COCUS",
        applies_to: "bl_house_line",
        amount: 633.0,
        currency: "MXN"
      )
    end
    let!(:cocus_altamira_catalog) do
      create(
        :service_catalog,
        name: "Custodia Altamira",
        code: "BL-COCUS-ATM",
        applies_to: "bl_house_line",
        amount: 633.0,
        currency: "MXN"
      )
    end

    let(:veracruz_port) { create(:port, :veracruz) }
    let(:veracruz_voyage) { create(:voyage, destination_port: veracruz_port) }
    let(:container) do
      create(
        :container,
        voyage: veracruz_voyage,
        fecha_desconsolidacion: Date.new(2026, 3, 20),
        tipo_maniobra: 'importacion',
        recinto: 'ICAVE',
        almacen: 'CICE'
      )
    end
    let(:bl_house_line) do
      create(
        :bl_house_line,
        container: container,
        status: "revalidado",
        peso: 12_000,
        volumen: 10,
        fecha_despacho: Time.zone.local(2026, 3, 30, 9, 0, 0)
      )
    end

    it 'creates storage service on despachado when grace period is exceeded' do
      expect {
        bl_house_line.update!(status: "despachado")
      }.to change { bl_house_line.reload.bl_house_line_services.where(service_catalog: catalog).count }.by(1)

      service = bl_house_line.bl_house_line_services.find_by(service_catalog: catalog)
      expect(service.amount).to eq(BigDecimal("6048"))
      expect(service.creation_origin).to be_blank

      codie_service = bl_house_line.bl_house_line_services.find_by(service_catalog: codie_veracruz_catalog)
      cocus_service = bl_house_line.bl_house_line_services.find_by(service_catalog: cocus_veracruz_catalog)
      expect(codie_service&.amount).to eq(BigDecimal("754"))
      expect(cocus_service&.amount).to eq(BigDecimal("633"))
    end

    it 'does not create storage service within grace period' do
      bl_house_line.update!(fecha_despacho: Time.zone.local(2026, 3, 26, 9, 0, 0))

      expect {
        bl_house_line.update!(status: "despachado")
      }.not_to change { bl_house_line.reload.bl_house_line_services.where(service_catalog: catalog).count }

      codie_service = bl_house_line.bl_house_line_services.find_by(service_catalog: codie_veracruz_catalog)
      cocus_service = bl_house_line.bl_house_line_services.find_by(service_catalog: cocus_veracruz_catalog)
      expect(codie_service&.amount).to eq(BigDecimal("754"))
      expect(cocus_service).to be_nil
    end

    it 'creates ATM variants of CODIE and COCUS on Altamira when grace period is exceeded' do
      altamira_port = create(:port, name: 'Altamira', code: 'MXATM', country_code: 'MX')
      altamira_voyage = create(:voyage, destination_port: altamira_port)
      altamira_container = create(
        :container,
        voyage: altamira_voyage,
        fecha_desconsolidacion: Date.new(2026, 3, 20),
        tipo_maniobra: 'importacion',
        recinto: 'ATP',
        almacen: 'SERVICIOS CARRIER INTERPUERTOS'
      )
      altamira_line = create(
        :bl_house_line,
        container: altamira_container,
        status: 'revalidado',
        peso: 12_000,
        volumen: 10,
        fecha_despacho: Time.zone.local(2026, 3, 30, 9, 0, 0)
      )

      altamira_line.update!(status: 'despachado')

      codie_atm_service = altamira_line.bl_house_line_services.find_by(service_catalog: codie_altamira_catalog)
      cocus_atm_service = altamira_line.bl_house_line_services.find_by(service_catalog: cocus_altamira_catalog)
      expect(codie_atm_service&.amount).to eq(BigDecimal("700"))
      expect(cocus_atm_service&.amount).to eq(BigDecimal("633"))
    end

    it 'does not create storage service automatically for non-eligible destination ports' do
      manzanillo_port = create(:port, :manzanillo)
      manzanillo_voyage = create(:voyage, destination_port: manzanillo_port)
      other_container = create(
        :container,
        voyage: manzanillo_voyage,
        fecha_desconsolidacion: Date.new(2026, 3, 20),
        tipo_maniobra: 'importacion',
        recinto: 'CONTECON',
        almacen: 'SSA'
      )
      other_line = create(
        :bl_house_line,
        container: other_container,
        status: 'revalidado',
        peso: 12_000,
        volumen: 10,
        fecha_despacho: Time.zone.local(2026, 3, 30, 9, 0, 0)
      )

      expect {
        other_line.update!(status: 'despachado')
      }.not_to change { other_line.reload.bl_house_line_services.where(service_catalog: catalog).count }
    end

    it 'creates and recalculates Lázaro storage and creates documentary control' do
      lazaro_storage = create(:service_catalog, code: "BL-ALM-LZC", applies_to: "bl_house_line", amount: 170.91)
      lazaro_codie = create(:service_catalog, code: "BL-CODIE-LZC", applies_to: "bl_house_line", amount: 250)
      port = create(:port, name: "Lázaro Cárdenas", code: "MXLZC", country_code: "MX")
      voyage = create(:voyage, destination_port: port)
      lazaro_container = create(:container, voyage: voyage, fecha_desconsolidacion: Date.new(2026, 3, 20), tipo_maniobra: "importacion", recinto: "APM TERMINALS", almacen: "UTTSA RECINTO 173")
      line = create(:bl_house_line, container: lazaro_container, status: "revalidado", peso: 12_000, volumen: 10, fecha_despacho: Time.zone.local(2026, 3, 30))

      line.update!(status: "despachado")
      service = line.bl_house_line_services.find_by!(service_catalog: lazaro_storage)
      expect(service.amount).to eq(BigDecimal("8203.68"))
      expect(line.bl_house_line_services.find_by!(service_catalog: lazaro_codie).amount).to eq(BigDecimal("250"))
      expect(line.bl_house_line_services.count).to eq(2)

      line.update!(clase_imo: "1", tipo_imo: "2")
      expect(service.reload.amount).to eq(BigDecimal("16407.36"))

      service.update!(factura: "LZC-001")
      line.update!(peso: 20_000)
      expect(service.reload.amount).to eq(BigDecimal("16407.36"))
    end

    context "Lázaro dispatch services" do
      let(:port) { create(:port, name: "Lázaro Cárdenas", code: "MXLZC", country_code: "MX") }
      let(:voyage) { create(:voyage, destination_port: port) }
      let(:lazaro_container) { create(:container, voyage: voyage, fecha_desconsolidacion: Date.new(2026, 3, 20), tipo_maniobra: "importacion", recinto: "APM TERMINALS", almacen: "UTTSA RECINTO 173") }
      let(:line) { create(:bl_house_line, container: lazaro_container, status: "revalidado", peso: 12_000, volumen: 10, fecha_despacho: Time.zone.local(2026, 3, 26)) }
      let!(:lazaro_storage) { create(:service_catalog, code: "BL-ALM-LZC", applies_to: "bl_house_line", amount: 100) }
      let!(:lazaro_codie) { create(:service_catalog, code: "BL-CODIE-LZC", applies_to: "bl_house_line", amount: 250) }

      it "creates documentary control but no storage on the final grace day" do
        line.update!(status: "despachado")
        expect(line.bl_house_line_services.where(service_catalog: lazaro_codie).count).to eq(1)
        expect(line.bl_house_line_services.where(service_catalog: lazaro_storage).count).to eq(0)
      end

      it "uses the Lázaro tariff on the first billable day without duplicating services" do
        line.update!(fecha_despacho: Time.zone.local(2026, 3, 27), status: "despachado")
        expect(line.bl_house_line_services.find_by!(service_catalog: lazaro_storage).amount).to eq(1200)
        line.update!(status: "revalidado")
        line.update!(status: "despachado")
        expect(line.bl_house_line_services.where(service_catalog: lazaro_storage).count).to eq(1)
        expect(line.bl_house_line_services.where(service_catalog: lazaro_codie).count).to eq(1)
      end

      it "preserves historic storage without creating or recalculating a second charge" do
        line.update!(fecha_despacho: Time.zone.local(2026, 3, 27))
        old_service = create(:bl_house_line_service, bl_house_line: line, service_catalog: catalog)
        old_amount = old_service.amount
        line.update!(status: "despachado")
        line.update!(peso: 20_000)
        expect(old_service.reload.amount).to eq(old_amount)
        expect(line.bl_house_line_services.where(service_catalog: lazaro_storage)).to be_empty
        expect(line.bl_house_line_services.where(service_catalog: lazaro_codie).count).to eq(1)
      end

      it "logs missing catalogs independently without blocking dispatch" do
        lazaro_storage.update!(active: false)
        lazaro_codie.update!(active: false)
        expect(Rails.logger).to receive(:error).with(/BL-ALM-LZC/)
        expect(Rails.logger).to receive(:error).with(/BL-CODIE-LZC/)
        line.update!(status: "despachado")
        expect(line.reload).to be_despachado
      end

      it "creates control when only the storage catalog is missing" do
        lazaro_storage.update!(active: false)
        line.update!(fecha_despacho: Time.zone.local(2026, 3, 27), status: "despachado")
        expect(line.bl_house_line_services.where(service_catalog: lazaro_codie).count).to eq(1)
        expect(line.bl_house_line_services.where(service_catalog: lazaro_storage)).to be_empty
      end

      it "creates storage when only the control catalog is missing" do
        lazaro_codie.update!(active: false)
        line.update!(fecha_despacho: Time.zone.local(2026, 3, 27), status: "despachado")
        expect(line.bl_house_line_services.where(service_catalog: lazaro_storage).count).to eq(1)
        expect(line.bl_house_line_services.where(service_catalog: lazaro_codie)).to be_empty
      end

      it "preserves invoiced existing services across dispatch and recalculation" do
        line.update!(fecha_despacho: Time.zone.local(2026, 3, 27))
        storage = create(:bl_house_line_service, bl_house_line: line, service_catalog: lazaro_storage, factura: "ALM-1")
        documentary = create(:bl_house_line_service, bl_house_line: line, service_catalog: lazaro_codie, factura: "COD-1")
        line.update!(status: "despachado")
        line.update!(peso: 20_000)
        expect(storage.reload.amount).to eq(1200)
        expect(documentary.reload.amount).to eq(250)
        expect(line.bl_house_line_services.where(service_catalog: [ lazaro_storage, lazaro_codie ]).count).to eq(2)
      end

      it "removes unbilled Lázaro storage if its dispatch date returns to the grace period" do
        line.update!(fecha_despacho: Time.zone.local(2026, 3, 27), status: "despachado")
        storage = line.bl_house_line_services.find_by!(service_catalog: lazaro_storage)
        line.update!(fecha_despacho: Time.zone.local(2026, 3, 26))
        expect(BlHouseLineService.exists?(storage.id)).to be(false)
        expect(line.bl_house_line_services.where(service_catalog: lazaro_codie).count).to eq(1)
      end

      it "invoices both generated services using their catalog SAT keys" do
        lazaro_storage.update!(sat_clave_prod_serv: "80151600", sat_clave_unidad: "E48")
        lazaro_codie.update!(sat_clave_prod_serv: "78101800", sat_clave_unidad: "H87")
        line.update!(fecha_despacho: Time.zone.local(2026, 3, 27), status: "despachado")
        receiver = line.client
        create(:fiscal_profile, profileable: receiver)
        create(:address, addressable: receiver, tipo: "matriz")
        issuer = create(:entity, :customs_agent, :with_fiscal_profile, :with_address).reload
        receiver.reload
        allow(Facturador::Config).to receive_messages(enabled?: true, manual_actions_enabled?: true, issuer_entity: issuer)
        services = line.bl_house_line_services.where(service_catalog: [ lazaro_storage, lazaro_codie ]).to_a
        result = Facturador::IssueGroupedServicesService.call(serviceables: services)
        expect(result.success?).to be(true), result.error_message
        expect(result.invoice.invoice_line_items.size).to eq(2)
        result.invoice.invoice_line_items.each do |item|
          expect(item.sat_clave_prod_serv).to eq(item.service_catalog.sat_clave_prod_serv)
          expect(item.sat_clave_unidad).to eq(item.service_catalog.sat_clave_unidad)
        end
      end

      it "creates control even when storage dates are missing" do
        line.update!(fecha_despacho: nil, status: "despachado")
        expect(line.bl_house_line_services.where(service_catalog: lazaro_codie).count).to eq(1)
        expect(line.bl_house_line_services.where(service_catalog: lazaro_storage)).to be_empty
      end

      it "does not generate either service for non-import operations" do
        lazaro_container.update!(tipo_maniobra: "exportacion")
        line.update!(status: "despachado")
        expect(line.bl_house_line_services.where(service_catalog: [ lazaro_storage, lazaro_codie ])).to be_empty
      end
    end

    it 'recalculates amount when weight changes and service is not invoiced' do
      bl_house_line.update!(status: "despachado")
      service = bl_house_line.bl_house_line_services.find_by(service_catalog: catalog)
      expect(service.amount).to eq(BigDecimal("6048"))

      bl_house_line.update!(peso: 14_200)

      expect(service.reload.amount).to eq(BigDecimal("7560"))
    end

    it 'recalculates amount when IMO changes and service is not invoiced' do
      bl_house_line.update!(status: "despachado")
      service = bl_house_line.bl_house_line_services.find_by(service_catalog: catalog)
      expect(service.amount).to eq(BigDecimal("6048"))

      bl_house_line.update!(clase_imo: "1", tipo_imo: "2")

      expect(service.reload.amount).to eq(BigDecimal("12096"))
    end

    it 'removes storage service if recalculation falls into grace period' do
      bl_house_line.update!(status: "despachado")
      service = bl_house_line.bl_house_line_services.find_by(service_catalog: catalog)
      expect(service).to be_present

      bl_house_line.update!(fecha_despacho: Time.zone.local(2026, 3, 26, 9, 0, 0))

      expect(BlHouseLineService.exists?(service.id)).to be(false)
    end

    it 'does not recalculate when storage service is invoiced' do
      bl_house_line.update!(status: "despachado")
      service = bl_house_line.bl_house_line_services.find_by(service_catalog: catalog)
      service.update!(factura: "A-001")

      expect {
        bl_house_line.update!(peso: 20_000)
      }.not_to change { service.reload.amount }
    end
  end

  describe 'entcam service' do
    let!(:catalog) do
      create(
        :service_catalog,
        name: "Maniobra de Entrega Almacén a Camión",
        code: "BL-ENTCAM",
        applies_to: "bl_house_line",
        amount: 126.0,
        currency: "MXN"
      )
    end

    let(:veracruz_port) { create(:port, :veracruz) }
    let(:veracruz_voyage) { create(:voyage, destination_port: veracruz_port) }
    let(:container) do
      create(
        :container,
        voyage: veracruz_voyage,
        tipo_maniobra: 'importacion',
        recinto: 'ICAVE',
        almacen: 'CICE'
      )
    end

    let(:bl_house_line) do
      create(
        :bl_house_line,
        container: container,
        status: "revalidado",
        peso: 13_200,
        volumen: 8.1
      )
    end

    it 'creates ENTCAM service on despachado using catalog amount' do
      expect {
        bl_house_line.update!(status: "despachado")
      }.to change { bl_house_line.reload.bl_house_line_services.where(service_catalog: catalog).count }.by(1)

      service = bl_house_line.bl_house_line_services.find_by(service_catalog: catalog)
      expect(service.amount).to eq(BigDecimal("1764"))
      expect(service.creation_origin).to be_blank
    end

    it 'does not duplicate ENTCAM service on repeated despachado updates' do
      bl_house_line.update!(status: "despachado")

      expect {
        bl_house_line.update!(status: "despachado")
      }.not_to change { bl_house_line.reload.bl_house_line_services.where(service_catalog: catalog).count }
    end

    it 'does not create ENTCAM service automatically for non-eligible destination ports' do
      manzanillo_port = create(:port, :manzanillo)
      manzanillo_voyage = create(:voyage, destination_port: manzanillo_port)
      other_container = create(
        :container,
        voyage: manzanillo_voyage,
        tipo_maniobra: 'importacion',
        recinto: 'CONTECON',
        almacen: 'SSA'
      )
      other_line = create(
        :bl_house_line,
        container: other_container,
        status: 'revalidado',
        peso: 13_200,
        volumen: 8.1
      )

      expect {
        other_line.update!(status: 'despachado')
      }.not_to change { other_line.reload.bl_house_line_services.where(service_catalog: catalog).count }
    end

    it 'recalculates ENTCAM amount when peso/volumen changes if not invoiced' do
      bl_house_line.update!(status: "despachado")
      service = bl_house_line.bl_house_line_services.find_by(service_catalog: catalog)
      expect(service.amount).to eq(BigDecimal("1764"))

      bl_house_line.update!(volumen: 15.2)

      expect(service.reload.amount).to eq(BigDecimal("2016"))
    end

    it 'recalculates ENTCAM amount when IMO changes if not invoiced' do
      bl_house_line.update!(status: "despachado")
      service = bl_house_line.bl_house_line_services.find_by(service_catalog: catalog)
      expect(service.amount).to eq(BigDecimal("1764"))

      bl_house_line.update!(clase_imo: "1", tipo_imo: "2")

      expect(service.reload.amount).to eq(BigDecimal("3528"))
    end

    it 'does not recalculate ENTCAM when service is invoiced' do
      bl_house_line.update!(status: "despachado")
      service = bl_house_line.bl_house_line_services.find_by(service_catalog: catalog)
      service.update!(factura: "A-002")

      expect {
        bl_house_line.update!(peso: 20_000)
      }.not_to change { service.reload.amount }
    end
  end

  describe 'previo service' do
    let!(:catalog) do
      create(
        :service_catalog,
        name: 'Maniobra de Previo en Almacén',
        code: 'BL-PREVIO',
        applies_to: 'bl_house_line',
        amount: 126.0,
        currency: 'MXN'
      )
    end

    let(:bl_house_line) do
      create(
        :bl_house_line,
        status: 'revalidado',
        peso: 13_200,
        volumen: 8.1
      )
    end

    it 'does not auto-create PREVIO service on despachado' do
      expect {
        bl_house_line.update!(status: 'despachado')
      }.not_to change { bl_house_line.reload.bl_house_line_services.where(service_catalog: catalog).count }
    end

    it 'recalculates PREVIO amount when peso/volumen changes if service exists and is not invoiced' do
      service = create(
        :bl_house_line_service,
        bl_house_line: bl_house_line,
        service_catalog: catalog,
        factura: nil,
        amount: 1
      )
      expect(service.reload.amount).to eq(BigDecimal('1764'))

      bl_house_line.update!(volumen: 15.2)

      expect(service.reload.amount).to eq(BigDecimal('2016'))
    end

    it 'recalculates PREVIO amount when IMO changes if service exists and is not invoiced' do
      service = create(
        :bl_house_line_service,
        bl_house_line: bl_house_line,
        service_catalog: catalog,
        factura: nil,
        amount: 1
      )
      expect(service.reload.amount).to eq(BigDecimal('1764'))

      bl_house_line.update!(clase_imo: '1', tipo_imo: '2')

      expect(service.reload.amount).to eq(BigDecimal('3528'))
    end

    it 'does not recalculate PREVIO when service is invoiced' do
      service = create(
        :bl_house_line_service,
        bl_house_line: bl_house_line,
        service_catalog: catalog,
        factura: 'A-777'
      )

      expect {
        bl_house_line.update!(peso: 20_000)
      }.not_to change { service.reload.amount }
    end
  end

  describe 'recasu service' do
    let!(:catalog) do
      create(
        :service_catalog,
        name: 'Reacomodo de Carga Suelta',
        code: 'BL-RECASU',
        applies_to: 'bl_house_line',
        amount: 126.0,
        currency: 'MXN'
      )
    end

    let(:bl_house_line) do
      create(
        :bl_house_line,
        status: 'revalidado',
        peso: 13_200,
        volumen: 8.1
      )
    end

    it 'does not auto-create RECASU service on despachado' do
      expect {
        bl_house_line.update!(status: 'despachado')
      }.not_to change { bl_house_line.reload.bl_house_line_services.where(service_catalog: catalog).count }
    end

    it 'recalculates RECASU amount when peso/volumen changes if service exists and is not invoiced' do
      service = create(
        :bl_house_line_service,
        bl_house_line: bl_house_line,
        service_catalog: catalog,
        factura: nil,
        amount: 1
      )
      expect(service.reload.amount).to eq(BigDecimal('1764'))

      bl_house_line.update!(volumen: 15.2)

      expect(service.reload.amount).to eq(BigDecimal('2016'))
    end

    it 'recalculates RECASU amount when IMO changes if service exists and is not invoiced' do
      service = create(
        :bl_house_line_service,
        bl_house_line: bl_house_line,
        service_catalog: catalog,
        factura: nil,
        amount: 1
      )
      expect(service.reload.amount).to eq(BigDecimal('1764'))

      bl_house_line.update!(clase_imo: '1', tipo_imo: '2')

      expect(service.reload.amount).to eq(BigDecimal('3528'))
    end

    it 'does not recalculate RECASU when service is invoiced' do
      service = create(
        :bl_house_line_service,
        bl_house_line: bl_house_line,
        service_catalog: catalog,
        factura: 'A-778'
      )

      expect {
        bl_house_line.update!(peso: 20_000)
      }.not_to change { service.reload.amount }
    end
  end

  describe '#documentos_completos?' do
    let(:bl_house_line) { create(:bl_house_line) }

    it 'returns false when no documents are attached' do
      expect(bl_house_line.documentos_completos?).to be_falsey
    end

    it 'returns false when only some documents are attached' do
      bl_house_line.bl_endosado_documento.attach(io: StringIO.new('test'), filename: 'test.pdf')
      expect(bl_house_line.documentos_completos?).to be_falsey
    end

    it 'returns true when all documents are attached' do
      bl_house_line.bl_endosado_documento.attach(io: StringIO.new('test'), filename: 'test.pdf')
      bl_house_line.liberacion_documento.attach(io: StringIO.new('test'), filename: 'test.pdf')
      bl_house_line.encomienda_documento.attach(io: StringIO.new('test'), filename: 'test.pdf')
      bl_house_line.pago_documento.attach(io: StringIO.new('test'), filename: 'test.pdf')
      expect(bl_house_line.documentos_completos?).to be_truthy
    end
  end

  describe '#required_revalidation_documents' do
    let(:container) { create(:container) }
    let(:bl_house_line) { create(:bl_house_line, container: container) }

    it 'returns only documents required by consolidator entity flags' do
      container.consolidator_entity.update!(
        requires_bl_endosado_documento: true,
        requires_liberacion_documento: false,
        requires_encomienda_documento: true,
        requires_pago_documento: false
      )

      expect(bl_house_line.required_revalidation_documents).to eq([
        :bl_endosado_documento,
        :encomienda_documento
      ])
    end

    it 'falls back to all document fields when no document is required' do
      container.consolidator_entity.update!(
        requires_bl_endosado_documento: false,
        requires_liberacion_documento: false,
        requires_encomienda_documento: false,
        requires_pago_documento: false
      )

      expect(bl_house_line.required_revalidation_documents).to eq(BlHouseLine::DOCUMENT_FIELDS)
    end
  end
end
