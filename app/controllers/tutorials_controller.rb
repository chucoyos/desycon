class TutorialsController < ApplicationController
  before_action :authenticate_user!

  def index
    @videos = [
      {
        title: "Cómo preparar tu flujo de trabajo",
        description: "Guía rápida para entender el proceso operativo dentro de la plataforma.",
        video_id: "Mj6YrvsIXD8",
        duration: "Video 1"
      },
      {
        title: "Buenas prácticas de seguimiento",
        description: "Recomendaciones para mantener trazabilidad y control en cada etapa.",
        video_id: "Ffo18-zaJCI",
        duration: "Video 2"
      }
    ]
  end
end
