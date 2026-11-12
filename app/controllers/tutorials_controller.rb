class TutorialsController < ApplicationController
  before_action :authenticate_user!

  def index
    @videos = [
      {
        title: "Solicitando Revalidación",
        description: "Enviar una solicitud de revalidación es más sencillo que nunca.",
        video_id: "jnvhU0_Jmmk",
        duration: "Video 1"
      },
      {
        title: "Cómo solicitar revalidaciones y servicios",
        description: "Aprende paso a paso a solicitar revalidaciones y coordinar servicios como previos, etiquetado, emplaye y maniobras.",
        video_id: "7l8pZE-4S1E",
        duration: "Video 2"
      },
      {
        title: "Registro de Pagos en Global DYC",
        description: "Te explicamos el procedimiento para enviar tus comprobantes de pago.",
        video_id: "2cqTxOh3n_4",
        duration: "Video 3"
      },
      {
        title: "Cómo preparar tu flujo de trabajo",
        description: "Guía rápida para entender el proceso operativo dentro de la plataforma.",
        video_id: "Mj6YrvsIXD8",
        duration: "Video 4"
      },
      {
        title: "Buenas prácticas de seguimiento",
        description: "Recomendaciones para mantener trazabilidad y control en cada etapa.",
        video_id: "Ffo18-zaJCI",
        duration: "Video 5"
      }
    ]
  end
end
