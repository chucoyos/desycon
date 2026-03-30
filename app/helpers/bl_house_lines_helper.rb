module BlHouseLinesHelper
  def temporary_service_breakdown_enabled?
    current_user&.admin_or_executive?
  end

  def bl_service_calculation_breakdown(service)
    return nil unless temporary_service_breakdown_enabled?
    return nil if service.blank? || service.service_catalog.blank? || service.bl_house_line.blank?

    code = service.service_catalog.code.to_s
    calculator_result = case code
    when "BL-ENTCAM", "BL-PREVIO", "BL-RECASU"
      BlHouseLines::EntregaAlmacenCamionCalculator.call(
        bl_house_line: service.bl_house_line,
        unit_price: service.service_catalog.amount
      )
    when "BL-ALMA"
      BlHouseLines::StorageChargeCalculator.call(
        bl_house_line: service.bl_house_line,
        desconsolidation_date: service.bl_house_line.container&.fecha_desconsolidacion,
        dispatch_date: service.bl_house_line.fecha_despacho,
        unit_price: service.service_catalog.amount
      )
    else
      nil
    end

    return nil if calculator_result.blank?

    # TEMPORAL DEBUG: bloque de desglose para validar formula y variables en QA.
    # Remover al cerrar validacion operativa y antes de consolidar para produccion.
    calculator_result.breakdown.to_h.merge(
      service_code: code,
      calculated_amount: calculator_result.total,
      persisted_amount: service.amount.to_d,
      delta_vs_persisted: (service.amount.to_d - calculator_result.total.to_d).round(2)
    )
  end

  def bl_service_breakdown_rows(breakdown)
    return [] if breakdown.blank?

    rows = []
    rows << [ "Codigo", breakdown[:service_code] ] if breakdown[:service_code].present?
    rows << [ "Fecha desconsolidacion", breakdown[:fecha_desconsolidacion] ] if breakdown.key?(:fecha_desconsolidacion)
    rows << [ "Fecha despacho", breakdown[:fecha_despacho] ] if breakdown.key?(:fecha_despacho)
    rows << [ "Fecha fin de gracia", breakdown[:fecha_fin_gracia] ] if breakdown.key?(:fecha_fin_gracia)
    rows << [ "Peso (kg input)", breakdown[:peso_kg_input] ] if breakdown.key?(:peso_kg_input)
    rows << [ "Peso (ton para calculo)", breakdown[:peso_ton_input] ] if breakdown.key?(:peso_ton_input)
    rows << [ "Volumen (input)", breakdown[:volumen_input] ] if breakdown.key?(:volumen_input)
    rows << [ "Unidades por peso", breakdown[:weight_units] ] if breakdown.key?(:weight_units)
    rows << [ "Unidades por volumen", breakdown[:volume_units] ] if breakdown.key?(:volume_units)
    rows << [ "Minimo unidades", breakdown[:minimum_units] ] if breakdown.key?(:minimum_units)
    rows << [ "Unidades cobrables", breakdown[:billable_units] ] if breakdown.key?(:billable_units)
    rows << [ "Dias cobrables", breakdown[:billable_days] ] if breakdown.key?(:billable_days)
    rows << [ "Puerto destino", breakdown[:destination_port_code] ] if breakdown[:destination_port_code].present?
    rows << [ "Precio unitario", breakdown[:unit_price] ] if breakdown.key?(:unit_price)
    rows << [ "Multiplicador IMO", breakdown[:imo_multiplier] ] if breakdown.key?(:imo_multiplier)
    rows << [ "Subtotal diario", breakdown[:daily_subtotal] ] if breakdown.key?(:daily_subtotal)
    rows << [ "Formula", breakdown[:formula] ] if breakdown[:formula].present?
    rows << [ "Total calculado", breakdown[:calculated_amount] ] if breakdown.key?(:calculated_amount)
    rows << [ "Total persistido", breakdown[:persisted_amount] ] if breakdown.key?(:persisted_amount)
    rows << [ "Diferencia", breakdown[:delta_vs_persisted] ] if breakdown.key?(:delta_vs_persisted)
    rows
  end

  def bl_house_line_status_badge_class(status)
    case status
    when "activo"
      "bg-indigo-100 text-indigo-800"
    when "bl_original"
      "bg-blue-100 text-blue-800"
    when "documentos_ok"
      "bg-emerald-100 text-emerald-800"
    when "documentos_rechazados"
      "bg-red-100 text-red-800"
    when "despachado"
      "bg-purple-100 text-purple-800"
    when "pendiente_endoso_agente_aduanal"
      "bg-orange-100 text-orange-800"
    when "pendiente_endoso_consignatario"
      "bg-red-100 text-red-800"
    when "finalizado"
      "bg-gray-100 text-gray-800"
    when "instrucciones_pendientes"
      "bg-red-100 text-red-800"
    when "pendiente_pagos_locales"
      "bg-pink-100 text-pink-800"
    when "listo"
      "bg-emerald-100 text-emerald-800"
    when "validar_documentos"
      "bg-yellow-100 text-yellow-800"
    when "revalidado"
      "bg-cyan-100 text-cyan-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  def bl_house_line_status_icon(status)
    case status
    when "activo"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>'.html_safe
    when "bl_original"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/></svg>'.html_safe
    when "documentos_ok"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>'.html_safe
    when "documentos_rechazados"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>'.html_safe
    when "despachado"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/></svg>'.html_safe
    when "pendiente_endoso_agente_aduanal"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/></svg>'.html_safe
    when "pendiente_endoso_consignatario"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>'.html_safe
    when "finalizado"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>'.html_safe
    when "instrucciones_pendientes"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/></svg>'.html_safe
    when "pendiente_pagos_locales"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"/></svg>'.html_safe
    when "listo"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>'.html_safe
    when "validar_documentos"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/></svg>'.html_safe
    when "revalidado"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg>'.html_safe
    else
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>'.html_safe
    end
  end

  def bl_house_line_status_nombre(status)
    return "Desconocido" if status.nil?

    {
      "activo" => "Activo",
      "bl_original" => "BL Original",
      "documentos_ok" => "Documentos OK",
      "documentos_rechazados" => "Documentos Rechazados",
      "despachado" => "Despachado",
      "pendiente_endoso_agente_aduanal" => "Pendiente Endoso Agente Aduanal",
      "pendiente_endoso_consignatario" => "Pendiente Endoso Consignatario",
      "finalizado" => "Finalizado",
      "instrucciones_pendientes" => "Instrucciones Pendientes",
      "pendiente_pagos_locales" => "Pendiente Pagos Locales",
      "validar_documentos" => "Validar Documentos",
      "listo" => "Listo",
      "revalidado" => "Revalidado"
    }[status] || status.humanize
  end
end
