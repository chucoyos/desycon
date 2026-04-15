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
        title: "Registro de Pagos en Global DYC",
        description: "Te explicamos el procedimiento para enviar tus comprobantes de pago.",
        video_id: "2cqTxOh3n_4",
        duration: "Video 2"
      },
      {
        title: "Cómo preparar tu flujo de trabajo",
        description: "Guía rápida para entender el proceso operativo dentro de la plataforma.",
        video_id: "Mj6YrvsIXD8",
        duration: "Video 3"
      },
      {
        title: "Buenas prácticas de seguimiento",
        description: "Recomendaciones para mantener trazabilidad y control en cada etapa.",
        video_id: "Ffo18-zaJCI",
        duration: "Video 4"
      }
    ]
  end
end
