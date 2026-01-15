import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "step1", "step2", "validation", "continueButton" ]
  static values = { initialStep: Number, returnUrl: String }

  connect() {
    this.showStep(this.hasInitialStepValue ? this.initialStepValue : 1)
    this.updateContinueState()
  }

  close(event) {
    if (event) event.preventDefault()
    
    // If we are on the standalone page (URL matches the wizard logic), redirect.
    // Otherwise just remove the modal.
    if (window.location.pathname.endsWith("/revalidation_approval")) {
        const url = this.hasReturnUrlValue ? this.returnUrlValue : "/"
        if (typeof Turbo !== 'undefined') {
            Turbo.visit(url)
        } else {
            window.location.href = url
        }
    } else {
        this.element.remove()
    }
  }

  handleNext(event) {
    event.preventDefault()
    if (!this.allValidated()) {
      return
    }
    this.showStep(2)
  }

  back(event) {
    event.preventDefault()
    this.showStep(1)
  }

  confirmReject(event) {
    const message = "¿Confirmas que deseas marcar la revalidación con instrucciones pendientes? Esto notificará al agente para corregir.";
    if (!window.confirm(message)) {
        event.preventDefault()
        event.stopPropagation()
    }
  }

  showStep(step) {
    const isStep1 = (step === 1)
    
    this.step1Target.classList.toggle("hidden", !isStep1)
    this.step2Target.classList.toggle("hidden", isStep1)
    
    // Disable inputs in hidden steps to prevent browser validation blocking submission
    // and to avoid sending irrelevant data
    this.toggleInputs(this.step1Target, !isStep1)
    this.toggleInputs(this.step2Target, isStep1)
  }

  toggleInputs(container, disabled) {
    const inputs = container.querySelectorAll("input, select, textarea, button[type='submit']")
    inputs.forEach(input => {
      // Keep hidden inputs and validation checkboxes enabled so their values are submitted
      if (input.type === "hidden") return
      if (input.name && input.name.endsWith("_validated]")) return

      if (disabled) {
        input.setAttribute("disabled", "disabled")
      } else {
        input.removeAttribute("disabled")
      }
    })
  }

  updateContinueState() {
    if (!this.hasContinueButtonTarget) return
    const enabled = this.allValidated()
    this.continueButtonTarget.toggleAttribute("disabled", !enabled)
    this.continueButtonTarget.classList.toggle("opacity-60", !enabled)
    this.continueButtonTarget.classList.toggle("cursor-not-allowed", !enabled)
  }

  allValidated() {
    if (!this.hasValidationTarget) return true
    const boxes = this.validationTargets
    if (!boxes.length) return true
    return boxes.every(cb => cb.checked)
  }
}
