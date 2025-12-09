module BlHouseLinesHelper
  def status_badge_class(status)
    case status
    when "activo"
      "bg-green-100 text-green-800"
    when "bl_original"
      "bg-blue-100 text-blue-800"
    when "documentos_ok"
      "bg-yellow-100 text-yellow-800"
    when "despachado"
      "bg-purple-100 text-purple-800"
    when "pendiente_endoso_agente_aduanal"
      "bg-orange-100 text-orange-800"
    when "pendiente_endoso_consignatario"
      "bg-red-100 text-red-800"
    when "finalizado"
      "bg-gray-100 text-gray-800"
    when "instrucciones_pendientes"
      "bg-indigo-100 text-indigo-800"
    when "pendiente_pagos_locales"
      "bg-pink-100 text-pink-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end
end
