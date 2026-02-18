module ContainersHelper
  def status_badge_class(status)
    case status
    when "activo"
      "bg-blue-100 text-blue-800 border-blue-200"
    when "bl_revalidado"
      "bg-indigo-100 text-indigo-800 border-indigo-200"
    when "fecha_tentativa_desconsolidacion"
      "bg-amber-100 text-amber-800 border-amber-200"
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
    when "bl_revalidado"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v8m0 0l-3-3m3 3l3-3M5 13l4 4L19 7"/></svg>'.html_safe
    when "fecha_tentativa_desconsolidacion"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>'.html_safe
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
      "bl_revalidado" => "BL Revalidado",
      "fecha_tentativa_desconsolidacion" => "Fecha Tentativa Desconsolidación",
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
      { label: "Cargar Tarja", path: lifecycle_tarja_modal_container_path(container) }
    end
  end
end
