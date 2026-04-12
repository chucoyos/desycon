import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link", "readyLink", "status", "statusText", "spinner"]

  connect() {
    this.pollTimer = null
    this.activeUrl = null
  }

  disconnect() {
    this.clearTimers()
  }

  start(event) {
    if (!this.hasLinkTarget) {
      return
    }

    event.preventDefault()

    const url = this.linkTarget.getAttribute("href")
    if (!url) {
      return
    }

    this.activeUrl = url
    this.disableLink()
    this.startSpinner()
    this.showStatus("Preparando descarga en segundo plano...")

    this.requestDownload()
  }

  async requestDownload() {
    if (!this.activeUrl) {
      return
    }

    try {
      const response = await fetch(this.jsonUrl(this.activeUrl), {
        headers: {
          Accept: "application/json"
        }
      })

      if (!response.ok) {
        throw new Error("No se pudo preparar la descarga")
      }

      const payload = await response.json()
      this.handleDownloadPayload(payload)
    } catch (_error) {
      this.stopSpinner()
      this.enableLink()
      this.showStatus("No se pudo preparar la descarga. Intenta nuevamente.")
      this.hideStatusLater(5000)
    }
  }

  handleDownloadPayload(payload) {
    const status = payload.status

    if (status === "completed" && payload.download_url) {
      this.showStatus("ZIP listo. Iniciando descarga...")
      this.stopSpinner()
      this.showReadyLink(payload.download_url)
      this.clearTimers()
      window.location.assign(payload.download_url)
      this.hideStatusLater(4000)
      return
    }

    if (status === "failed" || status === "invalid") {
      this.stopSpinner()
      this.enableLink()
      this.showStatus(payload.message || "No se pudo generar el ZIP.")
      this.hideStatusLater(6000)
      return
    }

    this.showStatus(payload.message || "Preparando descarga...")
    this.schedulePoll()
  }

  showReadyLink(downloadUrl) {
    if (this.hasLinkTarget) {
      this.linkTarget.hidden = true
      this.linkTarget.classList.remove("opacity-60", "pointer-events-none")
      this.linkTarget.removeAttribute("aria-disabled")
    }

    if (this.hasReadyLinkTarget) {
      this.readyLinkTarget.hidden = false
      this.readyLinkTarget.setAttribute("href", downloadUrl)
    }
  }

  schedulePoll() {
    this.clearTimers()
    this.pollTimer = window.setTimeout(() => {
      this.requestDownload()
    }, 2000)
  }

  hideStatusLater(delayMs) {
    this.clearTimers()
    this.hideTimer = window.setTimeout(() => {
      this.hideStatus()
    }, delayMs)
  }

  clearTimers() {
    window.clearTimeout(this.pollTimer)
    window.clearTimeout(this.hideTimer)
    this.pollTimer = null
    this.hideTimer = null
  }

  jsonUrl(url) {
    const parsed = new URL(url, window.location.origin)
    parsed.searchParams.set("format", "json")
    return parsed.toString()
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
