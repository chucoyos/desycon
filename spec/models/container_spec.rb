require 'rails_helper'
require 'securerandom'

RSpec.describe Container, type: :model do
  describe 'associations' do
    it 'belongs to consolidator' do
      container = build(:container)
      expect(container).to respond_to(:consolidator)
    end

    it 'belongs to shipping_line' do
      container = build(:container)
      expect(container).to respond_to(:shipping_line)
    end

    it 'belongs to vessel' do
      container = build(:container)
      expect(container).to respond_to(:vessel)
    end

    it 'has many container_status_histories' do
      container = create(:container)
      expect(container).to respond_to(:container_status_histories)
    end

    it 'has many container_services' do
      container = create(:container)
      expect(container).to respond_to(:container_services)
    end

    it 'has many bl_house_lines' do
      container = create(:container)
      expect(container).to respond_to(:bl_house_lines)
    end

    it 'destroys status histories when destroyed' do
      container = create(:container)
      history = container.container_status_histories.create!(
        status: 'activo',
        fecha_actualizacion: Time.current
      )
      container_id = container.id
      container.destroy
      expect(ContainerStatusHistory.find_by(container_id: container_id)).to be_nil
    end

    it 'destroys services when destroyed' do
      container = create(:container)
      service = container.container_services.create!(
        service_catalog: create(:service_catalog_maniobra)
      )
      container_id = container.id
      container.destroy
      expect(ContainerService.find_by(container_id: container_id)).to be_nil
    end
  end

  describe 'validations' do
    let(:container) { build(:container) }

    it 'is valid with valid attributes' do
      expect(container).to be_valid
    end

    describe 'number' do
      it 'requires number' do
        container.number = nil
        expect(container).not_to be_valid
        expect(container.errors[:number]).to include("no puede estar en blanco")
      end

      it 'validates uniqueness case-insensitively scoped to bl_master' do
        create(:container, number: 'CONU0000001', bl_master: 'BL-ABC')
        container.number = 'conu0000001'
        container.bl_master = 'BL-ABC'
        expect(container).not_to be_valid
      end

      it 'allows same number with different bl_master' do
        create(:container, number: 'CONU0000002', bl_master: 'BL-AAA')
        container.number = 'CONU0000002'
        container.bl_master = 'BL-BBB'
        expect(container).to be_valid
      end

      it 'normalizes number before validation' do
        container = create(:container, number: '  con-u-1234567  ')
        expect(container.number).to eq('CONU1234567')
      end

      it 'enforces 4 letters plus 7 digits format' do
        container.number = 'ABC1234567'
        expect(container).not_to be_valid
        expect(container.errors[:number]).to_not be_empty
      end
    end

    describe 'bl_master' do
      it 'requires bl_master' do
        container.bl_master = nil
        expect(container).not_to be_valid
      end
    end

    describe 'status' do
      it 'requires status' do
        container.status = nil
        expect(container).not_to be_valid
      end

      it 'has default status activo' do
        container = Container.new(
          number: 'TEST0000001',
          consolidator: create(:consolidator),
          shipping_line: create(:shipping_line),
          tipo_maniobra: 'importacion',
          bl_master: 'BL-DEFAULT'
        )
        expect(container.status).to eq('activo')
      end

      it 'validates inclusion in enum values' do
        expect {
          container.status = 'invalid_status'
        }.to raise_error(ArgumentError)
      end
    end

    describe 'tipo_maniobra' do
      it 'requires tipo_maniobra' do
        container.tipo_maniobra = nil
        expect(container).not_to be_valid
      end

      it 'validates inclusion in enum values' do
        expect {
          container.tipo_maniobra = 'invalid_tipo'
        }.to raise_error(ArgumentError)
      end
    end

    it 'requires consolidator_entity' do
      container.consolidator_entity = nil
      expect(container).not_to be_valid
    end

    it 'requires shipping_line' do
      container.shipping_line = nil
      expect(container).not_to be_valid
    end

    it 'requires vessel' do
      container.vessel = nil
      expect(container).not_to be_valid
    end
  end

  describe 'enums' do
    it 'defines status enum with correct values' do
      expect(Container.statuses).to eq({
        'activo' => 'activo',
        'bl_revalidado' => 'bl_revalidado',
        'fecha_tentativa_desconsolidacion' => 'fecha_tentativa_desconsolidacion',
        'cita_transferencia' => 'cita_transferencia',
        'descargado' => 'descargado',
        'desconsolidado' => 'desconsolidado'
      })
    end

    it 'defines tipo_maniobra enum with correct values' do
      expect(Container.tipo_maniobras).to eq({
        'importacion' => 'importacion',
        'exportacion' => 'exportacion'
      })
    end

    it 'provides query methods for status' do
      container = create(:container, status: 'activo')
      expect(container.status_activo?).to be true
      expect(container.status_bl_revalidado?).to be false
    end

    it 'provides query methods for tipo_maniobra' do
      container = create(:container, tipo_maniobra: 'importacion')
      expect(container.tipo_maniobra_importacion?).to be true
      expect(container.tipo_maniobra_exportacion?).to be false
    end
  end

  describe 'callbacks' do
    it 'creates status history after status update' do
      container = create(:container, status: 'activo')

      expect {
        container.update!(status: 'bl_revalidado')
      }.to change { container.container_status_histories.count }.by(1)

      history = container.container_status_histories.last
      expect(history.status).to eq('bl_revalidado')
    end

    it 'does not duplicate status history when using cambiar_status!' do
      container = create(:container, status: 'activo')
      user = create(:user)

      expect {
        container.cambiar_status!('bl_revalidado', user, 'Test')
      }.to change { container.container_status_histories.count }.by(1)
    end

    it 'does not move to fecha_tentativa_desconsolidacion without transferencia' do
      container = create(
        :container,
        status: 'bl_revalidado',
        fecha_revalidacion_bl_master: Time.current
      )

      container.update!(
        fecha_tentativa_desconsolidacion: Date.current + 1.day,
        tentativa_turno: :primer_turno
      )

      expect(container.reload.status).to eq('bl_revalidado')
    end

    it 'moves to fecha_tentativa_desconsolidacion when transferencia exists' do
      container = create(
        :container,
        status: 'cita_transferencia',
        fecha_transferencia: Time.current.change(sec: 0)
      )

      container.update!(
        fecha_tentativa_desconsolidacion: Date.current + 1.day,
        tentativa_turno: :primer_turno
      )

      expect(container.reload.status).to eq('fecha_tentativa_desconsolidacion')
    end
  end

  describe 'scopes' do
    before do
      @container1 = create(:container, status: 'activo', tipo_maniobra: 'importacion')
      @container2 = create(:container, tipo_maniobra: 'exportacion')
      @container2.bl_master_documento.attach(
        io: StringIO.new('test'),
        filename: 'bl.pdf',
        content_type: 'application/pdf'
      )
      @container2.save! # This will trigger auto_set_status_from_fields to set status to bl_revalidado
      @container3 = create(:container, status: 'activo', tipo_maniobra: 'importacion')
    end

    it 'filters by status' do
      results = Container.by_status('activo')
      expect(results).to include(@container1, @container3)
      expect(results).not_to include(@container2)
    end

    it 'filters by tipo_maniobra' do
      results = Container.by_tipo_maniobra('importacion')
      expect(results).to include(@container1, @container3)
      expect(results).not_to include(@container2)
    end

    it 'filters by consolidator' do
      entity = @container1.consolidator_entity
      results = Container.by_consolidator(entity.id)
      expect(results).to include(@container1)
    end

    it 'filters by shipping_line' do
      shipping_line = @container1.shipping_line
      results = Container.by_shipping_line(shipping_line.id)
      expect(results).to include(@container1)
    end

    it 'returns recent containers first' do
      # El scope recent ordena por created_at desc
      # Limpiar contenedores previos de este contexto
      Container.destroy_all

      first_container = create(:container)
      sleep 0.1 # Pequeña pausa para asegurar created_at diferente
      second_container = create(:container)

      expect(Container.recent.first.id).to eq(second_container.id)
      expect(Container.recent.last.id).to eq(first_container.id)
    end

    it 'includes associations with with_associations scope' do
      container = create(:container)
      result = Container.with_associations.find(container.id)

      # Verify associations are preloaded
      expect(result.association(:consolidator_entity).loaded?).to be_truthy
      expect(result.association(:shipping_line).loaded?).to be_truthy
    end
  end

  describe 'instance methods' do
    let(:container) { create(:container, number: 'CONT0000123') }

    describe '#to_s' do
      it 'returns the container number' do
        expect(container.to_s).to eq('CONT0000123')
      end
    end

    describe '#nombre_buque' do
      it 'returns vessel name when present' do
        vessel = create(:vessel)
        container.vessel = vessel
        expect(container.nombre_buque).to eq(vessel.name)
      end

      it 'returns "Sin asignar" when vessel is nil' do
        container.vessel = nil
        expect(container.nombre_buque).to eq('Sin asignar')
      end
    end

    describe '#nombre_linea_naviera' do
      it 'returns shipping line name' do
        expect(container.nombre_linea_naviera).to eq(container.shipping_line.name)
      end
    end

    describe '#nombre_consolidador' do
      it 'returns consolidator entity name' do
        expect(container.nombre_consolidador).to eq(container.consolidator_entity.name)
      end
    end

    describe '#documentos_completos?' do
      it 'returns false when no documents attached' do
        expect(container.documentos_completos?).to be false
      end

      it 'returns false when only bl_master attached' do
        container.bl_master_documento.attach(
          io: StringIO.new('test'),
          filename: 'bl.pdf',
          content_type: 'application/pdf'
        )
        expect(container.documentos_completos?).to be false
      end

      it 'returns false when only tarja attached' do
        container.tarja_documento.attach(
          io: StringIO.new('test'),
          filename: 'tarja.pdf',
          content_type: 'application/pdf'
        )
        expect(container.documentos_completos?).to be false
      end

      it 'returns true when both documents attached' do
        container.bl_master_documento.attach(
          io: StringIO.new('test'),
          filename: 'bl.pdf',
          content_type: 'application/pdf'
        )
        container.tarja_documento.attach(
          io: StringIO.new('test'),
          filename: 'tarja.pdf',
          content_type: 'application/pdf'
        )
        expect(container.documentos_completos?).to be true
      end
    end

    describe '#puede_desconsolidar?' do
      it 'returns false when status is not activo' do
        container.update!(status: 'bl_revalidado')
        expect(container.puede_desconsolidar?).to be false
      end

      it 'returns false when documents incomplete' do
        container.update!(status: 'activo')
        expect(container.puede_desconsolidar?).to be false
      end

      it 'returns true when documents are complete but fecha_desconsolidacion is missing' do
        container.update!(status: 'activo')
        container.bl_master_documento.attach(
          io: StringIO.new('test'),
          filename: 'bl.pdf',
          content_type: 'application/pdf'
        )
        container.tarja_documento.attach(
          io: StringIO.new('test'),
          filename: 'tarja.pdf',
          content_type: 'application/pdf'
        )
        container.reload
        expect(container.status).to eq('bl_revalidado')
        expect(container.puede_desconsolidar?).to be true
      end
    end
      it 'moves to desconsolidado only when documentos are complete and fecha_desconsolidacion is present' do
        container = create(:container, status: 'activo')

        container.bl_master_documento.attach(
          io: StringIO.new('test'),
          filename: 'bl.pdf',
          content_type: 'application/pdf'
        )
        container.tarja_documento.attach(
          io: StringIO.new('test'),
          filename: 'tarja.pdf',
          content_type: 'application/pdf'
        )

        expect(container.reload.status).to eq('bl_revalidado')

        container.update!(fecha_desconsolidacion: Date.current)

        expect(container.reload.status).to eq('desconsolidado')
      end

    describe '#last_status_change' do
      it 'returns the most recent status history' do
        # El container ya tiene un historial inicial creado automáticamente
        new_history = container.container_status_histories.create!(
          status: 'validar_documentos',
          fecha_actualizacion: 1.day.from_now
        )
        container.reload
        expect(container.last_status_change).to eq(new_history)
      end

      it 'returns nil when no history exists' do
        container = Container.new
        expect(container.last_status_change).to be_nil
      end
    end

    describe '#cambiar_status!' do
      let(:user) { create(:user) }

      it 'changes status and creates history' do
        expect {
          container.cambiar_status!('bl_revalidado', user, 'Documentos pendientes')
        }.to change { container.container_status_histories.count }.by(1)

        expect(container.reload.status).to eq('bl_revalidado')

        history = container.container_status_histories.last
        expect(history.status).to eq('bl_revalidado')
        expect(history.observaciones).to eq('Documentos pendientes')
        expect(history.user).to eq(user)
      end

      it 'creates history without user' do
        expect {
          container.cambiar_status!('bl_revalidado', nil, 'Sin usuario')
        }.to change { container.container_status_histories.count }.by(1)
      end

      it 'creates history without observaciones' do
        expect {
          container.cambiar_status!('bl_revalidado', user)
        }.to change { container.container_status_histories.count }.by(1)

        history = container.container_status_histories.last
        expect(history.observaciones).to be_nil
      end

      it 'rolls back on error' do
        allow(container).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)

        expect {
          begin
            container.cambiar_status!('bl_revalidado', user)
          rescue ActiveRecord::RecordInvalid
            # Ignore error for test
          end
        }.not_to change { container.container_status_histories.count }
      end
    end

    describe 'viaje' do
      it 'requires viaje' do
        container.viaje = nil
        expect(container).not_to be_valid
        expect(container.errors[:viaje]).to_not be_empty
      end

      it 'limits viaje length to 50 chars' do
        container.viaje = 'V' * 51
        expect(container).not_to be_valid
        expect(container.errors[:viaje]).to_not be_empty
      end
    end

    describe 'recinto' do
      it 'requires recinto' do
        container.recinto = nil
        expect(container).not_to be_valid
        expect(container.errors[:recinto]).to_not be_empty
      end

      it 'limits recinto length to 100 chars' do
        container.recinto = 'R' * 101
        expect(container).not_to be_valid
        expect(container.errors[:recinto]).to_not be_empty
      end

      context 'when tipo_maniobra is importacion and destination port is mapped' do
        let(:manzanillo) { create(:port, :manzanillo) }

        it 'allows a recinto listed for the destination port' do
          valid_container = build(:container, destination_port: manzanillo, recinto: 'CONTECON', almacen: 'SSA', tipo_maniobra: 'importacion')

          expect(valid_container).to be_valid
        end

        it 'rejects a recinto not listed for the destination port' do
          invalid_container = build(:container, destination_port: manzanillo, recinto: 'FRIMAN', almacen: 'SSA', tipo_maniobra: 'importacion')

          expect(invalid_container).not_to be_valid
          expect(invalid_container.errors[:recinto]).to include('no es válido para el puerto de destino seleccionado')
        end
      end

      it 'allows recinto when destination port has no mapping' do
        unmapped_port = create(:port, name: 'Puerto Nuevo', code: 'MXPNO')
        valid_container = build(:container, destination_port: unmapped_port, recinto: 'FRIMAN', almacen: 'GOLMEX', tipo_maniobra: 'importacion')

        expect(valid_container).to be_valid
      end
    end

    describe 'almacen' do
      it 'permite que almacen quede en blanco' do
        container.almacen = nil
        expect(container).to be_valid
      end

      it 'limits almacen length to 100 chars' do
        container.almacen = 'A' * 101
        expect(container).not_to be_valid
        expect(container.errors[:almacen]).to_not be_empty
      end

      context 'when tipo_maniobra is importacion and destination port is mapped' do
        let(:manzanillo) { create(:port, :manzanillo) }

        it 'allows an almacen listed for the destination port' do
          valid_container = build(:container, destination_port: manzanillo, almacen: 'SSA', recinto: 'CONTECON', tipo_maniobra: 'importacion')

          expect(valid_container).to be_valid
        end

        it 'rejects an almacen not listed for the destination port' do
          invalid_container = build(:container, destination_port: manzanillo, almacen: 'GOLMEX', recinto: 'CONTECON', tipo_maniobra: 'importacion')

          expect(invalid_container).not_to be_valid
          expect(invalid_container.errors[:almacen]).to include('no es válido para el puerto de destino seleccionado')
        end
      end

      it 'allows almacen when destination port has no mapping' do
        unmapped_port = create(:port, name: 'Puerto Nuevo', code: 'MXPNO')
        valid_container = build(:container, destination_port: unmapped_port, almacen: 'GOLMEX', recinto: 'FRIMAN', tipo_maniobra: 'importacion')

        expect(valid_container).to be_valid
      end
    end

    describe 'archivo_nr' do
      it 'requires archivo_nr' do
        container.archivo_nr = nil
        expect(container).not_to be_valid
        expect(container.errors[:archivo_nr]).to_not be_empty
      end

      it 'limits archivo_nr length to 100 chars' do
        container.archivo_nr = 'A' * 101
        expect(container).not_to be_valid
        expect(container.errors[:archivo_nr]).to_not be_empty
      end
    end

    describe 'sello' do
      it 'requires sello' do
        container.sello = nil
        expect(container).not_to be_valid
        expect(container.errors[:sello]).to_not be_empty
      end

      it 'limits sello length to 50 chars' do
        container.sello = 'S' * 51
        expect(container).not_to be_valid
        expect(container.errors[:sello]).to_not be_empty
      end
    end

    describe 'ejecutivo' do
      it 'requires ejecutivo' do
        container.ejecutivo = nil
        expect(container).not_to be_valid
        expect(container.errors[:ejecutivo]).to_not be_empty
      end

      it 'limits ejecutivo length to 50 chars' do
        container.ejecutivo = 'E' * 51
        expect(container).not_to be_valid
        expect(container.errors[:ejecutivo]).to_not be_empty
      end
    end
  end

  describe 'tarja attachment processing' do
    let(:customs_agent) { create(:entity, :customs_agent) }
    let(:container) do
      create(:container, status: 'bl_revalidado')
    end
    let(:packaging) { create(:packaging, nombre: "Empaque Especial #{SecureRandom.hex(3)}") }
    let!(:line_ok) { create(:bl_house_line, container: container, customs_agent: customs_agent, packaging: packaging, status: 'documentos_ok') }
    let!(:line_other) { create(:bl_house_line, container: container, customs_agent: customs_agent, packaging: packaging, status: 'activo') }
    let!(:agent_user) { create(:user, :customs_broker, entity: customs_agent) }

    around do |example|
      previous_user = Current.user
      Current.user = agent_user
      example.run
      Current.user = previous_user
    end

    it 'changes status to activo when only tarja is attached (BL master missing)' do
      expect {
        container.tarja_documento.attach(
          io: StringIO.new('Tarja content'),
          filename: 'tarja.pdf',
          content_type: 'application/pdf'
        )
        container.reload
      }.to change { container.reload.status }.from('bl_revalidado').to('activo')
    end

    it 'does not revalidate BL lines when BL master is missing' do
      container.tarja_documento.attach(
        io: StringIO.new('Tarja content'),
        filename: 'tarja.pdf',
        content_type: 'application/pdf'
      )

      expect(line_ok.reload.status).to eq('documentos_ok')
      expect(line_other.reload.status).to eq('activo')
    end

    it 'does not notify customs agent users when BL master is missing' do
      expect {
        container.tarja_documento.attach(
          io: StringIO.new('Tarja content'),
          filename: 'tarja.pdf',
          content_type: 'application/pdf'
        )
        container.reload
      }.not_to change {
        Notification.where(recipient: agent_user, notifiable: line_ok, action: 'revalidado').count
      }
    end
  end

  describe 'Active Storage attachments' do
    let(:container) { create(:container) }

    it 'can attach bl_master_documento' do
      expect {
        container.bl_master_documento.attach(
          io: StringIO.new('test'),
          filename: 'bl.pdf',
          content_type: 'application/pdf'
        )
      }.to change { container.bl_master_documento.attached? }.from(false).to(true)
    end

    it 'sets fecha_revalidacion_bl_master when bl_master_documento is attached' do
      expect(container.fecha_revalidacion_bl_master).to be_nil

      before_attach = Time.current

      container.bl_master_documento.attach(
        io: StringIO.new('test'),
        filename: 'bl.pdf',
        content_type: 'application/pdf'
      )

      after_attach = Time.current

      expect(container.reload.fecha_revalidacion_bl_master).to be_present
      expect(container.fecha_revalidacion_bl_master).to be >= before_attach
      expect(container.fecha_revalidacion_bl_master).to be <= after_attach
    end

    it 'can attach tarja_documento' do
      expect {
        container.tarja_documento.attach(
          io: StringIO.new('test'),
          filename: 'tarja.pdf',
          content_type: 'application/pdf'
        )
      }.to change { container.tarja_documento.attached? }.from(false).to(true)
    end
  end
end
