class RevalidationPdf
  def initialize(bl_house_line)
    @bl_house_line = bl_house_line
  end

  def render
    Prawn::Document.new(page_size: "A4", margin: [ 50, 50, 50, 50 ]) do |pdf|
      # Header
      pdf.font_size 14
      pdf.text "REVALIDACIÓN ELECTRÓNICA", align: :center, style: :bold
      pdf.move_down 10
      pdf.text "FOLIO NÚMERO: #{@bl_house_line.id}", align: :center, style: :bold
      pdf.move_down 10

      # Customs office info
      pdf.font_size 12
      pdf.text "ADUANA DE MANZANILLO", align: :center, style: :bold
      pdf.move_down 10
      pdf.text "C. ADMINISTRADOR DE LA ADUANA MARITIMA DE MANZANILLO", align: :center
      pdf.text "P R E S E N T E.", align: :center
      pdf.move_down 20

      # Legal text
      pdf.font_size 10
      pdf.text "De conformidad con los artículos 36-A Fracción I inciso B, 40 y 41 de la Ley Aduanera vigente, declaramos bajo protesta de decir verdad que #{consolidator_name} ha sido designado como el consignatario de las mercancías amparadas bajo el conocimiento de embarque que se detalla a continuación."
      pdf.move_down 10
      pdf.text "En virtud de lo anterior, y toda vez que diversos Agentes Aduanales o sus representantes debidamente acreditados procederán al retiro de dichas mercancías, por medio de la presente CEDEMOS LOS DERECHOS a la empresa que se menciona al calce, para que proceda con el despacho y el retiro de las mercancías del recinto fiscal autorizado."
      pdf.move_down 20

      # Data table
      pdf.font_size 12
      pdf.text "Datos Generales", style: :bold
      pdf.move_down 10

      data = [
        [ "BL House:", @bl_house_line.blhouse ],
        [ "Cantidad:", @bl_house_line.cantidad ],
        [ "Embalaje:", packaging_name ],
        [ "Contiene:", @bl_house_line.contiene ],
        [ "Peso:", "#{@bl_house_line.peso} KG" ],
        [ "Volumen:", "#{@bl_house_line.volumen} M³" ],
        [ "Agente Aduanal:", customs_agent_name ],
        [ "Patente:", patent_number ],
        [ "Consolidador:", consolidator_name ],
        [ "Estatus:", status_name ],
        [ "Master BL:", master_bl ],
        [ "Linea:", shipping_line_name ],
        [ "Buque:", vessel_name ],
        [ "Viaje:", voyage ],
        [ "Recinto:", almacen_name.presence || terminal_name.presence || "N/A" ]
      ]

      pdf.table(data, width: pdf.bounds.width) do |table|
        table.cells.padding = 8
        table.cells.borders = [ :bottom ]
        table.cells.border_width = 0.5
        table.cells.border_color = "CCCCCC"

        # Header style
        table.columns(0).font_style = :bold
        table.columns(0).background_color = "F5F5F5"
      end

      # Footer
      pdf.move_down 10
      pdf.font_size 8
      pdf.text "Documento generado electrónicamente el #{Time.current.strftime('%d/%m/%Y %H:%M')}", align: :center
    end.render
  end

  private

  def consolidator_name
    container = @bl_house_line.container
    return "N/A" unless container

    container.consolidator_entity&.name || container.consolidator&.name || "N/A"
  end

  def packaging_name
    @bl_house_line.packaging&.nombre || "N/A"
  end

  def customs_agent_name
    @bl_house_line.customs_agent&.name || "N/A"
  end

  def patent_number
    if @bl_house_line.respond_to?(:customs_agent_patent) && @bl_house_line.customs_agent_patent.present?
      @bl_house_line.customs_agent_patent.patent_number
    else
      @bl_house_line.customs_agent&.customs_agent_patents&.first&.patent_number || "N/A"
    end
  end

  def status_name
    I18n.t("activerecord.attributes.bl_house_line.status.#{@bl_house_line.status}", default: @bl_house_line.status.humanize)
  end

  def master_bl
    @bl_house_line.container&.bl_master || "N/A"
  end

  def shipping_line_name
    @bl_house_line.container&.shipping_line&.name || "N/A"
  end

  def vessel_name
    @bl_house_line.container&.vessel&.name || "N/A"
  end

  def voyage
    @bl_house_line.container&.viaje || "N/A"
  end

  def almacen_name
    @bl_house_line.container&.almacen || "N/A"
  end

  def terminal_name
    @bl_house_line.container&.recinto || "N/A"
  end
end
