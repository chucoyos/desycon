import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["shippingLine", "vessel"]
  static values = {
    vessels: Array
  }

  connect() {
    this.filterVessels()
  }

  filterVessels() {
    const shippingLineId = this.shippingLineTarget.value
    const vesselSelect = this.vesselTarget
    
    // Guardar la opción seleccionada actualmente
    const currentVesselId = vesselSelect.value
    
    // Limpiar las opciones actuales excepto el prompt
    vesselSelect.innerHTML = '<option value="">Seleccione un buque</option>'
    
    // Si no hay línea naviera seleccionada, deshabilitar el select
    if (!shippingLineId) {
      vesselSelect.disabled = true
      return
    }
    
    vesselSelect.disabled = false
    
    // Filtrar y agregar los buques de la línea naviera seleccionada
    const filteredVessels = this.vesselsValue.filter(vessel => 
      vessel.shipping_line_id.toString() === shippingLineId
    )
    
    filteredVessels.forEach(vessel => {
      const option = document.createElement('option')
      option.value = vessel.id
      option.textContent = vessel.name
      
      // Restaurar la selección si el buque está en la lista filtrada
      if (vessel.id.toString() === currentVesselId) {
        option.selected = true
      }
      
      vesselSelect.appendChild(option)
    })
    
    // Si no hay buques para esta línea naviera
    if (filteredVessels.length === 0) {
      const option = document.createElement('option')
      option.value = ''
      option.textContent = 'No hay buques disponibles'
      option.disabled = true
      vesselSelect.appendChild(option)
    }
  }
}
