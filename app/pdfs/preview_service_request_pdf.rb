require "prawn"
require "prawn/table"

class PreviewServiceRequestPdf
  def initialize(service_request)
    @request = service_request
    @line = service_request.bl_house_line
    @container = @line.container
  end

  def render
    Prawn::Document.new(page_size: "LETTER", margin: [ 32, 32, 48, 32 ]) do |pdf|
      pdf.font "Helvetica"
      pdf.fill_color "24354B"
      pdf.image Rails.root.join("app/assets/images/logoDyC.jpeg"), fit: [ 112, 48 ]
      pdf.move_down 6
      pdf.text "PAPELETA DE PREVIO", size: 16, style: :bold
      pdf.text "Detalle de solicitud de servicio", size: 10
      pdf.move_down 10

      approval = @request.events.includes(:actor).find_by(action: "approved")
      details = [
        [ "Recinto fiscalizado", @container.recinto ],
        [ "Almacén", @container.almacen ],
        [ "Folio de solicitud", @request.id ],
        [ "Estatus", BlHouseLineServiceRequest::STATUS_LABELS.fetch(@request.status) ],
        [ "Fecha de servicio", date(@request.scheduled_date) ],
        [ "Horario", @request.scheduled_time&.strftime("%H:%M") ],
        [ "Fecha de solicitud", datetime(@request.created_at) ],
        [ "Usuario solicitante", @request.requester.email ],
        [ "Fecha de autorización", datetime(approval&.created_at) ],
        [ "Usuario autorizador", approval&.actor&.email ]
      ]
      details_table(pdf, details)

      section(pdf, "Datos de la operación logística")
      voyage = @container.voyage
      details_table(pdf, [
        [ "Agencia aduanal", @request.customs_agent.name ],
        [ "Cliente / importador", @line.client&.name ],
        [ "Buque", @container.vessel&.name ],
        [ "Viaje", voyage&.viaje ],
        [ "Fecha de arribo", datetime(voyage&.ata) ],
        [ "Arribo estimado", datetime(voyage&.eta) ],
        [ "Línea naviera", @container.shipping_line&.name ],
        [ "Inicio de operaciones", datetime(voyage&.inicio_operacion) ],
        [ "Término de operaciones", datetime(voyage&.fin_operacion) ],
        [ "HBL", @line.blhouse ],
        [ "Master BL", @container.bl_master ],
        [ "Contenedor", @container.number ],
        [ "Tipo de trámite", @container.tipo_maniobra&.humanize ],
        [ "Referencia interna", @line.internal_reference ]
      ])

      section(pdf, "Servicios solicitados")
      requests = [ @request ] + @request.preview_complements.to_a
      rows = requests.map do |request|
        quantity = request.bl_house_line_service&.quantity unless request.status == "pending"
        [ quantity.to_s, safe(request.service_catalog.code), safe(request.service_catalog.name) ]
      end
      pdf.table([ [ "Cantidad", "Código / Clave", "Descripción del servicio" ] ] + rows,
        header: true, width: pdf.bounds.width, column_widths: [ 60, 110, pdf.bounds.width - 170 ],
        cell_style: { size: 8, padding: 6, border_color: "CBD5E1", overflow: :shrink_to_fit }) do |table|
        table.row(0).background_color = "E8EEF5"
        table.row(0).font_style = :bold
      end

      section(pdf, "Detalle de la mercancía / partida")
      columns = [
        [ "Partida", @line.partida, 35 ],
        [ "HBL / BL", @line.blhouse, 75 ],
        [ "Mercancía", @line.contiene, 110 ],
        [ "Marca", @line.marcas, 60 ],
        [ "Embalaje", @line.packaging&.nombre, 60 ],
        [ "Bultos", @line.cantidad, 40 ],
        [ "Peso (kg)", @line.peso, 55 ],
        [ "Volumen (m³)", @line.volumen, 55 ],
        [ "Clase IMO", imo_value(@line.clase_imo), 45 ],
        [ "Tipo IMO", imo_value(@line.tipo_imo), 45 ]
      ].select { |_, value, _| value.present? }
      total_width = columns.sum { |_, _, width| width }
      pdf.table([ columns.map { |label, _, _| safe(label) }, columns.map { |_, value, _| safe(value) } ],
        header: true, width: pdf.bounds.width,
        column_widths: columns.map { |_, _, width| pdf.bounds.width * width / total_width },
        cell_style: { size: 7, padding: 4, border_color: "CBD5E1", overflow: :shrink_to_fit }) do |table|
        table.row(0).background_color = "E8EEF5"
        table.row(0).font_style = :bold
      end

      pdf.number_pages "Desycon · Todos los derechos reservados · Página <page> de <total>",
        at: [ 0, -20 ], width: pdf.bounds.width, align: :center, size: 8, color: "64748B"
    end.render
  end

  private

  def section(pdf, title)
    pdf.move_down 14
    pdf.text safe(title), size: 10, style: :bold
    pdf.move_down 5
  end

  def details_table(pdf, details)
    rows = details.select { |_, value| value.present? }.each_slice(2).map do |pair|
      pair.flat_map { |label, value| [ safe(label), safe(value) ] }.fill("", pair.size * 2...4)
    end
    return if rows.empty?

    pdf.table(rows, width: pdf.bounds.width, column_widths: [ 100, 174, 100, pdf.bounds.width - 374 ],
      cell_style: { size: 8, padding: 5, border_color: "E2E8F0", overflow: :shrink_to_fit }) do |table|
      table.columns(0).font_style = :bold
      table.columns(2).font_style = :bold
    end
  end

  def date(value)
    I18n.l(value, format: :default) if value.present?
  end

  def datetime(value)
    I18n.l(value, format: :short) if value.present?
  end

  def imo_value(value)
    value if value.present? && value != "0"
  end

  def safe(value)
    value.to_s.unicode_normalize(:nfkc).encode("Windows-1252", undef: :replace, invalid: :replace, replace: "?").encode("UTF-8")
  end
end
