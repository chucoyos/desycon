import { Controller } from "@hotwired/stimulus"

// Prevents submitting import forms when no file is selected.
export default class extends Controller {
  static targets = ["fileInput", "submitButton"]

  connect() {
    this.toggleSubmit()
  }

  onFileChange() {
    this.fileInputTarget.setCustomValidity("")
    this.toggleSubmit()
  }

  validate(event) {
    if (this.hasFileInputTarget && this.fileInputTarget.files.length > 0) {
      this.fileInputTarget.setCustomValidity("")
      return
    }

    event.preventDefault()
    this.fileInputTarget.setCustomValidity("Selecciona un archivo XLSX o CSV antes de importar.")
    this.fileInputTarget.reportValidity()
    this.toggleSubmit()
  }

  toggleSubmit() {
    if (!this.hasSubmitButtonTarget || !this.hasFileInputTarget) return

    this.submitButtonTarget.disabled = this.fileInputTarget.files.length === 0
  }
}
