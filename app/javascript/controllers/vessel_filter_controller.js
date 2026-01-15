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
    const vesselSelect = this.vesselTarget
    const currentVesselId = vesselSelect.value

    vesselSelect.innerHTML = '<option value="">Seleccione un buque</option>'
    vesselSelect.disabled = false

    const list = this.vesselsValue || []

    list.forEach(vessel => {
      const option = document.createElement('option')
      option.value = vessel.id
      option.textContent = vessel.name
      if (vessel.id.toString() === currentVesselId) {
        option.selected = true
      }
      vesselSelect.appendChild(option)
    })
  }
}
