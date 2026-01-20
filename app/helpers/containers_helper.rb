module ContainersHelper
  def status_badge_class(status)
    case status
    when "activo"
      "bg-blue-100 text-blue-800 border-blue-200"
    when "validar_documentos"
      "bg-yellow-100 text-yellow-800 border-yellow-200"
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
    when "validar_documentos"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/></svg>'.html_safe
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
      "validar_documentos" => "Validar Documentos",
      "desconsolidado" => "Desconsolidado"
    }[status] || status.humanize
  end

  def tipo_maniobra_nombre(tipo)
    {
      "importacion" => "Importación",
      "exportacion" => "Exportación"
    }[tipo] || tipo.humanize
  end

  def container_type_nombre(tipo)
    {
      "estandar" => "Estándar",
      "high_cube" => "High Cube",
      "otro" => "Otro"
    }[tipo] || tipo.to_s.humanize
  end

  def container_type_badge_class(tipo)
    case tipo
    when "estandar"
      "bg-sky-100 text-sky-800 border-sky-200"
    when "high_cube"
      "bg-indigo-100 text-indigo-800 border-indigo-200"
    when "otro"
      "bg-gray-100 text-gray-800 border-gray-200"
    else
      "bg-gray-100 text-gray-800 border-gray-200"
    end
  end

  def size_ft_label(size_ft)
    value = Container.size_fts[size_ft] || size_ft

    {
      "20" => "20 ft",
      "40" => "40 ft"
    }[value.to_s] || value.to_s
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
end
