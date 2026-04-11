import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame"]
  static values = { src: String }

  connect() {
    this.load()
  }

  load() {
    if (!this.element.open) return
    if (!this.hasFrameTarget) return
    if (this.frameTarget.getAttribute("src")) return
    if (!this.srcValue) return

    this.frameTarget.setAttribute("src", this.srcValue)
  }
}
