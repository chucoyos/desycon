import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "step1", "step2" ]
  static values = { initialStep: Number, returnUrl: String }

  connect() {
    this.showStep(this.hasInitialStepValue ? this.initialStepValue : 1)
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

  next(event) {
    event.preventDefault()
    this.showStep(2)
  }

  back(event) {
    event.preventDefault()
    this.showStep(1)
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
        if (disabled) {
            input.setAttribute("disabled", "disabled")
        } else {
            input.removeAttribute("disabled")
        }
    })
  }
}
