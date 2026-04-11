import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit", "status", "statusText", "progressBar"]

  connect() {
    this.uploadProgressById = new Map()
    this.directUploadsStarted = 0
    this.originalSubmitText = this.hasSubmitTarget ? this.submitTarget.value : "Subir fotografías"
  }

  onSubmit() {
    const fileCount = this.hasInputTarget && this.inputTarget.files ? this.inputTarget.files.length : 0

    if (fileCount <= 0) {
      return
    }

    this.disableSubmit("Subiendo fotografías...")
    this.showStatus("Iniciando carga...")
  }

  onSubmitEnd(event) {
    if (event.detail.success) {
      return
    }

    this.enableSubmit()
    this.showStatus("No se pudo completar la carga. Intenta nuevamente.")
  }

  onDirectUploadStart(event) {
    this.directUploadsStarted += 1
    this.uploadProgressById.set(event.detail.id, 0)
    const total = this.totalFiles()
    this.showStatus(`Subiendo ${this.directUploadsStarted} de ${total}...`)
  }

  onDirectUploadProgress(event) {
    this.uploadProgressById.set(event.detail.id, event.detail.progress)
    const progress = this.averageProgress()
    this.updateProgressBar(progress)
    this.showStatus(`Subiendo fotografías... ${progress}%`)
  }

  onDirectUploadEnd(event) {
    this.uploadProgressById.set(event.detail.id, 100)
    const progress = this.averageProgress()
    this.updateProgressBar(progress)

    if (progress >= 100) {
      this.showStatus("Finalizando y guardando fotografías...")
    }
  }

  onDirectUploadError() {
    this.enableSubmit()
    this.showStatus("Ocurrió un error durante la carga. Intenta nuevamente.")
  }

  totalFiles() {
    if (!this.hasInputTarget || !this.inputTarget.files) {
      return 0
    }

    return this.inputTarget.files.length
  }

  averageProgress() {
    if (this.uploadProgressById.size === 0) {
      return 0
    }

    let total = 0
    this.uploadProgressById.forEach((value) => {
      total += value
    })

    return Math.round(total / this.uploadProgressById.size)
  }

  disableSubmit(text) {
    if (!this.hasSubmitTarget) {
      return
    }

    this.submitTarget.disabled = true
    this.submitTarget.classList.add("opacity-60", "cursor-not-allowed")
    this.submitTarget.value = text
  }

  enableSubmit() {
    if (!this.hasSubmitTarget) {
      return
    }

    this.submitTarget.disabled = false
    this.submitTarget.classList.remove("opacity-60", "cursor-not-allowed")
    this.submitTarget.value = this.originalSubmitText
  }

  showStatus(message) {
    if (!this.hasStatusTarget || !this.hasStatusTextTarget) {
      return
    }

    this.statusTarget.classList.remove("hidden")
    this.statusTextTarget.textContent = message
  }

  updateProgressBar(progress) {
    if (!this.hasProgressBarTarget) {
      return
    }

    this.progressBarTarget.style.width = `${progress}%`
  }
}
