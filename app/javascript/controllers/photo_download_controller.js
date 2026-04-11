import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link", "status", "statusText", "spinner"]

  start(event) {
    if (!this.hasLinkTarget) {
      return
    }

    event.preventDefault()

    const url = this.linkTarget.getAttribute("href")
    if (!url) {
      return
    }

    this.disableLink()
    this.startSpinner()
    this.showStatus("Preparando descarga...")
    window.location.assign(url)

    window.clearTimeout(this.finishTimer)
    window.clearTimeout(this.hideTimer)

    this.finishTimer = window.setTimeout(() => {
      this.enableLink()
      this.stopSpinner()
      this.showStatus("Descarga iniciada. Si no comenzó, intenta nuevamente.")
    }, 3500)

    this.hideTimer = window.setTimeout(() => {
      this.hideStatus()
    }, 6500)
  }

  disableLink() {
    this.linkTarget.classList.add("opacity-60", "pointer-events-none")
    this.linkTarget.setAttribute("aria-disabled", "true")
  }

  enableLink() {
    this.linkTarget.classList.remove("opacity-60", "pointer-events-none")
    this.linkTarget.removeAttribute("aria-disabled")
  }

  showStatus(message) {
    if (!this.hasStatusTarget || !this.hasStatusTextTarget) {
      return
    }

    this.statusTarget.classList.remove("hidden")
    this.statusTextTarget.textContent = message
  }

  hideStatus() {
    if (!this.hasStatusTarget) {
      return
    }

    this.statusTarget.classList.add("hidden")
  }

  startSpinner() {
    if (!this.hasSpinnerTarget) {
      return
    }

    this.spinnerTarget.classList.add("animate-spin")
  }

  stopSpinner() {
    if (!this.hasSpinnerTarget) {
      return
    }

    this.spinnerTarget.classList.remove("animate-spin")
  }
}
