FactoryBot.define do
  factory :container_status_history do
    association :container
    association :user, factory: :user, optional: true
    status { 'activo' }
    fecha_actualizacion { Time.current }
    observaciones { "Status changed to #{status}" }

    trait :validar_documentos do
      status { 'validar_documentos' }
      observaciones { 'Documentos pendientes de revisión' }
    end

    trait :desconsolidado do
      status { 'desconsolidado' }
      observaciones { 'Contenedor desconsolidado exitosamente' }
    end

    trait :with_user do
      association :user
    end
  end
end
