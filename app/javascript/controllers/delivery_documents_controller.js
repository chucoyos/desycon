import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "panel", "input"]
  static values = { catalogId: Number }

  connect() {
    this.toggle()
  }

  toggle() {
    const show = this.hasCatalogIdValue && Number(this.selectTarget.value) === this.catalogIdValue
    this.panelTarget.classList.toggle("hidden", !show)
    this.inputTarget.required = show
    this.inputTarget.disabled = !show
  }
}
