module EntitiesHelper
  ENTITY_SCOPE_LABELS = {
    "entity" => "Entidad",
    "fiscal_profile" => "Perfil fiscal",
    "email_recipients" => "Destinatarios",
    "addresses" => "Domicilios"
  }.freeze

  ENTITY_FIELD_LABELS = {
    "name" => "Nombre",
    "role_kind" => "Rol",
    "customs_agent_id" => "Agente aduanal",
    "patent_number" => "Patente",
    "enforce_overdue_payment_rule" => "Regla de adeudo vencido",
    "requires_bl_endosado_documento" => "Requiere BL endosado",
    "requires_liberacion_documento" => "Requiere liberacion",
    "requires_encomienda_documento" => "Requiere encomienda",
    "requires_pago_documento" => "Requiere pago"
  }.freeze

  FISCAL_FIELD_LABELS = {
    "rfc" => "RFC",
    "razon_social" => "Razon social",
    "regimen" => "Regimen",
    "uso_cfdi" => "Uso CFDI",
    "forma_pago" => "Forma de pago",
    "metodo_pago" => "Metodo de pago"
  }.freeze

  EMAIL_RECIPIENT_FIELD_LABELS = {
    "email" => "Correo",
    "position" => "Posicion",
    "active" => "Activo",
    "primary_recipient" => "Principal"
  }.freeze

  ADDRESS_FIELD_LABELS = {
    "tipo" => "Tipo",
    "calle" => "Calle",
    "numero_exterior" => "Numero exterior",
    "numero_interior" => "Numero interior",
    "colonia" => "Colonia",
    "municipio" => "Municipio",
    "localidad" => "Localidad",
    "estado" => "Estado",
    "codigo_postal" => "Codigo postal",
    "pais" => "Pais",
    "email" => "Correo"
  }.freeze

  ADDRESS_DIFF_FIELDS = ADDRESS_FIELD_LABELS.keys.freeze

  def entity_event_change_rows(field_path, values)
    return address_event_change_rows(values) if field_path.to_s == "addresses"

    values_hash = values.is_a?(Hash) ? values : {}

    [ {
      label: entity_event_field_label(field_path),
      before: values_hash["before"],
      after: values_hash["after"]
    } ]
  end

  def entity_event_value_for_display(value)
    case value
    when nil, ""
      "(vacio)"
    when true
      "Si"
    when false
      "No"
    when Hash, Array
      value.to_json
    else
      value
    end
  end

  private

  def entity_event_field_label(field_path)
    parts = field_path.to_s.split(".")
    return field_path.to_s.humanize if parts.empty?

    scope = parts[0]
    field = parts[1]

    scope_label = ENTITY_SCOPE_LABELS[scope] || scope.to_s.humanize
    field_label = scoped_field_label(scope, field)

    return scope_label if field_label.blank?

    "#{scope_label} - #{field_label}"
  end

  def scoped_field_label(scope, field)
    return nil if field.blank?

    case scope
    when "entity"
      ENTITY_FIELD_LABELS[field] || field.to_s.humanize
    when "fiscal_profile"
      FISCAL_FIELD_LABELS[field] || field.to_s.humanize
    when "email_recipients"
      EMAIL_RECIPIENT_FIELD_LABELS[field] || field.to_s.humanize
    else
      field.to_s.humanize
    end
  end

  def address_event_change_rows(values)
    values_hash = values.is_a?(Hash) ? values : {}
    before_map = normalize_addresses_for_diff(values_hash["before"])
    after_map = normalize_addresses_for_diff(values_hash["after"])

    rows = []

    (before_map.keys | after_map.keys).sort.each do |address_id|
      before_address = before_map[address_id]
      after_address = after_map[address_id]
      address_label = "Domicilio"

      if before_address.nil?
        rows << {
          label: "#{address_label} (agregado)",
          before: nil,
          after: address_summary(after_address)
        }
        next
      end

      if after_address.nil?
        rows << {
          label: "#{address_label} (eliminado)",
          before: address_summary(before_address),
          after: nil
        }
        next
      end

      ADDRESS_DIFF_FIELDS.each do |field|
        before_value = before_address[field]
        after_value = after_address[field]
        next if before_value == after_value

        rows << {
          label: "#{address_label} - #{ADDRESS_FIELD_LABELS[field]}",
          before: before_value,
          after: after_value
        }
      end
    end

    rows.presence || [ {
      label: "Domicilios",
      before: values_hash["before"],
      after: values_hash["after"]
    } ]
  end

  def normalize_addresses_for_diff(value)
    Array(value).each_with_object({}) do |raw_address, acc|
      next unless raw_address.is_a?(Hash)

      address = raw_address.deep_stringify_keys
      address_id = address["id"]
      next if address_id.blank?

      acc[address_id.to_i] = address
    end
  end

  def address_summary(address)
    return "(vacio)" unless address.is_a?(Hash)

    [
      address["tipo"],
      address["calle"],
      address["numero_exterior"],
      address["numero_interior"],
      address["colonia"],
      address["municipio"],
      address["estado"],
      address["codigo_postal"],
      address["pais"],
      address["email"]
    ].compact_blank.join(", ")
  end
end
