module ContainersHelper
  def status_badge_class(status)
    case status
    when "activo"
      "bg-blue-100 text-blue-800 border-blue-200"
    when "en_espera_del_bl_fletado"
      "bg-sky-100 text-sky-800 border-sky-200"
    when "en_proceso_de_pagos_locales"
      "bg-violet-100 text-violet-800 border-violet-200"
    when "en_espera_del_ok_para_revalidar"
      "bg-yellow-100 text-yellow-800 border-yellow-200"
    when "en_proceso_de_revalidacion_ante_la_ln"
      "bg-cyan-100 text-cyan-800 border-cyan-200"
    when "mbl_revalidado_en_espera_del_atraque_de_buque"
      "bg-indigo-100 text-indigo-800 border-indigo-200"
    when "buque_en_operaciones_en_espera_de_descarga"
      "bg-teal-100 text-teal-800 border-teal-200"
    when "en_proceso_de_transferencia_documental"
      "bg-fuchsia-100 text-fuchsia-800 border-fuchsia-200"
    when "detenido_por_aduana"
      "bg-red-100 text-red-800 border-red-200"
    when "bl_revalidado"
      "bg-indigo-100 text-indigo-800 border-indigo-200"
    when "fecha_tentativa_desconsolidacion"
      "bg-amber-100 text-amber-800 border-amber-200"
    when "en_proceso_desconsolidacion"
      "bg-orange-100 text-orange-800 border-orange-200"
    when "cita_transferencia"
      "bg-purple-100 text-purple-800 border-purple-200"
    when "descargado"
      "bg-teal-100 text-teal-800 border-teal-200"
    when "desconsolidado"
      "bg-green-100 text-green-800 border-green-200"
    else
      "bg-gray-100 text-gray-800 border-gray-200"
    end
  end

  def status_icon(status)
    case status
    when "activo"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>'.html_safe
    when "en_espera_del_bl_fletado"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>'.html_safe
    when "en_proceso_de_pagos_locales"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 1.12-3 2.5S10.343 13 12 13s3 1.12 3 2.5S13.657 18 12 18m0-10v10m0-10a3 3 0 013 3M12 8a3 3 0 00-3 3"/></svg>'.html_safe
    when "en_espera_del_ok_para_revalidar"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 10h8M8 14h5M7 3h10a2 2 0 012 2v14l-3-2-3 2-3-2-3 2V5a2 2 0 012-2z"/></svg>'.html_safe
    when "en_proceso_de_revalidacion_ante_la_ln"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>'.html_safe
    when "mbl_revalidado_en_espera_del_atraque_de_buque"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14M5 12l2-4h10l2 4M4 16s1.5 2 4 2 4-2 4-2 1.5 2 4 2 4-2 4-2"/></svg>'.html_safe
    when "buque_en_operaciones_en_espera_de_descarga"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 13h18M5 13l2-4h10l2 4M4 17s1.5 2 4 2 4-2 4-2 1.5 2 4 2 4-2 4-2"/></svg>'.html_safe
    when "en_proceso_de_transferencia_documental"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h10M7 12h10M7 17h6M5 3h14a2 2 0 012 2v14a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2z"/></svg>'.html_safe
    when "detenido_por_aduana"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v4m0 4h.01M5.07 19h13.86c1.54 0 2.5-1.67 1.73-3L13.73 4c-.77-1.33-2.69-1.33-3.46 0L3.34 16c-.77 1.33.19 3 1.73 3z"/></svg>'.html_safe
    when "bl_revalidado"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v8m0 0l-3-3m3 3l3-3M5 13l4 4L19 7"/></svg>'.html_safe
    when "fecha_tentativa_desconsolidacion"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>'.html_safe
    when "en_proceso_desconsolidacion"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6l4 2m6-2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>'.html_safe
    when "cita_transferencia"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8l4 4m0 0l-4 4m4-4H3"/></svg>'.html_safe
    when "descargado"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582c2.797 0 4.196 0 5.305-.481a6 6 0 002.632-2.632C13 4.778 13 3.378 13 0.582V0"/></svg>'.html_safe
    when "desconsolidado"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>'.html_safe
    end
  end

  def tipo_maniobra_badge_class(tipo)
    case tipo
    when "importacion"
      "bg-purple-100 text-purple-800 border-purple-200"
    when "exportacion"
      "bg-orange-100 text-orange-800 border-orange-200"
    else
      "bg-gray-100 text-gray-800 border-gray-200"
    end
  end

  def tipo_maniobra_icon(tipo)
    case tipo
    when "importacion"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4"/></svg>'.html_safe
    when "exportacion"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4"/></svg>'.html_safe
    end
  end

  def status_nombre(status)
    {
      "activo" => "Activo",
      "en_espera_del_bl_fletado" => "En Espera del BL Fletado",
      "en_proceso_de_pagos_locales" => "En Proceso de Pagos Locales",
      "en_espera_del_ok_para_revalidar" => "En Espera del OK para Revalidar",
      "en_proceso_de_revalidacion_ante_la_ln" => "En Proceso de Revalidacion ante la LN",
      "mbl_revalidado_en_espera_del_atraque_de_buque" => "MBL Revalidado, en Espera del Atraque de Buque",
      "buque_en_operaciones_en_espera_de_descarga" => "Buque en Operaciones, en Espera de Descarga",
      "en_proceso_de_transferencia_documental" => "En Proceso de Transferencia Documental",
      "detenido_por_aduana" => "Detenido por Aduana",
      "bl_revalidado" => "BL Revalidado",
      "fecha_tentativa_desconsolidacion" => "Fecha Tentativa de Desconsolidacion",
      "en_proceso_desconsolidacion" => "En Proceso de Desconsolidacion",
      "cita_transferencia" => "Cita de Transferencia",
      "descargado" => "Descargado",
      "desconsolidado" => "Desconsolidado"
    }[status] || status.humanize
  end

  def tipo_maniobra_nombre(tipo)
    {
      "importacion" => "Importación",
      "exportacion" => "Exportación"
    }[tipo] || tipo.humanize
  end

  def recinto_options_for_select(container)
    tipo = container.tipo_maniobra.presence || "importacion"
    options = Container.recinto_options_for_port(port: container.destination_port, tipo_maniobra: tipo)
    options = Container.recinto_union if options.empty?

    pairs = options.map { |recinto| [ recinto, recinto ] }

    if container.recinto.present? && pairs.none? { |(_, value)| value == container.recinto }
      pairs.unshift([ container.recinto, container.recinto ])
    end

    pairs
  end

  def almacen_options_for_select(container)
    tipo = container.tipo_maniobra.presence || "importacion"
    options = Container.almacen_options_for_port(port: container.destination_port, tipo_maniobra: tipo)
    options = Container.almacen_union if options.empty?

    pairs = options.map { |almacen| [ almacen, almacen ] }

    if container.almacen.present? && pairs.none? { |(_, value)| value == container.almacen }
      pairs.unshift([ container.almacen, container.almacen ])
    end

    pairs
  end

  def truncate_filename(filename, max_length: 30)
    return filename if filename.to_s.length <= max_length

    name = filename.to_s
    extension = File.extname(name)
    basename = File.basename(name, extension)

    # Calculate how much space we have for the basename
    available_length = max_length - extension.length - 3 # 3 for "..."

    if available_length > 0
      "#{basename[0...available_length]}...#{extension}"
    else
      "#{name[0...max_length]}..."
    end
  end

  def container_lifecycle_action(container)
    case container.status
    when "activo"
      { label: "Cargar BL Master", path: lifecycle_bl_master_modal_container_path(container) }
    when "bl_revalidado"
      { label: "Fecha Descarga", path: lifecycle_descarga_modal_container_path(container) }
    when "descargado"
      { label: "Cita Transferencia", path: lifecycle_transferencia_modal_container_path(container) }
    when "cita_transferencia"
      { label: "Fecha tentativa", path: lifecycle_tentativa_modal_container_path(container) }
    when "fecha_tentativa_desconsolidacion"
      { label: "Inicio desconsolidación", path: lifecycle_en_proceso_desconsolidacion_modal_container_path(container) }
    when "en_proceso_desconsolidacion"
      { label: "Cargar Tarja", path: lifecycle_tarja_modal_container_path(container) }
    end
  end
end
