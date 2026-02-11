import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typeSelect", "destinationSelect"]

  connect() {
    this.filter()
  }

  filter() {
    const voyageType = this.typeSelectTarget.value
    const isArrival = voyageType === "arribo"
    const allowed = ["manzanillo", "altamira", "veracruz", "lazaro cardenas"]

    const currentValue = this.destinationSelectTarget.value
    let hasVisibleSelection = false

    Array.from(this.destinationSelectTarget.options).forEach(option => {
      const isPlaceholder = !option.value

      if (isPlaceholder) {
        option.hidden = false
        option.disabled = false
        hasVisibleSelection ||= currentValue === ""
        return
      }

      if (!isArrival) {
        option.hidden = false
        option.disabled = false
        hasVisibleSelection ||= option.value === currentValue
        return
      }

      const rawName = option.dataset.portName || option.textContent || ""
      const normalized = rawName
        .toLowerCase()
        .normalize("NFD")
        .replace(/\p{Diacritic}/gu, "")
        .trim()

      const matches = allowed.includes(normalized)
      option.hidden = !matches
      option.disabled = !matches

      if (matches && option.value === currentValue) {
        hasVisibleSelection = true
      }
    })

    if (!hasVisibleSelection) {
      this.destinationSelectTarget.value = ""
    }
  }
}
