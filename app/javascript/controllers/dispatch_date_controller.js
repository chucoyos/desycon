import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "date"]

  connect() {
    this.toggle()
  }

  onStatusChange() {
    this.toggle()
  }

  toggle() {
    const status = this.hasStatusTarget ? this.statusTarget.value : null
    const shouldEnable = status === "despachado"
    const dateField = this.dateTarget

    // Respect forced disabled (e.g., customs agent readonly)
    if (dateField.dataset.forceDisabled === "true") {
      dateField.disabled = true
      return
    }

    dateField.disabled = !shouldEnable
    if (!shouldEnable) {
      dateField.value = ""
    }
  }
}
