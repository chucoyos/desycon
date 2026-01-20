FactoryBot.define do
  factory :container do
    sequence(:number) { |n| "CONT#{n.to_s.rjust(7, '0')}" }
    status { 'activo' }
    tipo_maniobra { 'importacion' }
    container_type { 'estandar' }
    size_ft { 'ft40' }
    association :shipping_line
    association :port
    association :vessel

    # Use NEW consolidator_entity association (Entity with consolidator role)
    # The old consolidator association will be removed in future migrations
    after(:build) do |container|
      if container.consolidator_entity.nil?
        # Create entity with consolidator role
        entity = FactoryBot.create(:entity, :consolidator)
        container.consolidator_entity = entity
      end
      # Leave consolidator_id as nil - it's for the old architecture
      container.consolidator_id = nil
    end

    bl_master { "BL-#{rand(1000..9999)}" }
    fecha_arribo { Date.today + rand(7..30).days }
    viaje { "V#{rand(100..999)}" }
    recinto { %w[SSA FRIMAN].sample }
    archivo_nr { "NR-#{rand(1000..9999)}" }
    sello { "SEAL#{rand(10000..99999)}" }
    cont_key { "KEY#{rand(1000..9999)}" }

    trait :with_vessel do
      association :vessel
    end

    trait :validar_documentos do
      status { 'validar_documentos' }
    end

    trait :desconsolidado do
      status { 'desconsolidado' }
    end

    trait :exportacion do
      tipo_maniobra { 'exportacion' }
    end

    trait :with_documents do
      after(:create) do |container|
        container.bl_master_documento.attach(
          io: StringIO.new('BL Master content'),
          filename: 'bl_master.pdf',
          content_type: 'application/pdf'
        )
        container.tarja_documento.attach(
          io: StringIO.new('Tarja content'),
          filename: 'tarja.pdf',
          content_type: 'application/pdf'
        )
      end
    end

    trait :with_services do
      after(:create) do |container|
        create_list(:container_service, 2, container: container)
      end
    end

    trait :with_status_history do
      after(:create) do |container|
        create_list(:container_status_history, 3, container: container)
      end
    end

    trait :complete do
      with_vessel
      with_documents
      with_services
      with_status_history
    end
  end
end
