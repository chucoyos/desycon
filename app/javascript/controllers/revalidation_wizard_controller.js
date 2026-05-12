import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "stepOne",
    "stepTwo",
    "clientSelect",
    "clientError",
    "progressFill",
    "stepBadgeOne",
    "stepBadgeTwo"
  ]

  connect() {
    this.showStep(1)
  }

  goToDocuments(event) {
    event.preventDefault()
    if (!this.clientValid()) return
    this.showStep(2)
  }

  goToSummary(event) {
    event.preventDefault()
    this.showStep(1)
  }

  close(event) {
    event.preventDefault()
    const frame = this.element.closest("turbo-frame") || document.getElementById("revalidation_modal")
    if (frame) {
      frame.innerHTML = ""
    }
  }

  showStep(step) {
    const isStepOne = step === 1

    this.stepOneTarget.classList.toggle("hidden", !isStepOne)
    this.stepTwoTarget.classList.toggle("hidden", isStepOne)

    if (this.hasProgressFillTarget) {
      this.progressFillTarget.style.width = isStepOne ? "50%" : "100%"
    }

    this.updateBadge(this.stepBadgeOneTarget, isStepOne)
    this.updateBadge(this.stepBadgeTwoTarget, !isStepOne)
  }

  updateBadge(element, active) {
    element.classList.toggle("bg-indigo-600", active)
    element.classList.toggle("text-white", active)
    element.classList.toggle("text-indigo-600", !active)
    element.classList.toggle("bg-indigo-50", !active)
    element.classList.toggle("border", !active)
    element.classList.toggle("border-indigo-200", !active)
  }

  clientValid() {
    if (!this.hasClientSelectTarget) return true

    const clientField = this.clientSelectTarget
    const visibleField = this.resolveVisibleClientField(clientField)
    const fieldForFeedback = visibleField || clientField
    const disabled = clientField.disabled
    const valid = disabled || (clientField.value && clientField.value.trim() !== "")

    if (this.hasClientErrorTarget) {
      this.clientErrorTarget.classList.toggle("hidden", valid)
    }

    fieldForFeedback.classList.toggle("border-red-300", !valid)
    fieldForFeedback.classList.toggle("focus:border-red-500", !valid)
    fieldForFeedback.classList.toggle("focus:ring-red-500", !valid)

    if (!valid) {
      fieldForFeedback.focus()
    }

    return valid
  }

  resolveVisibleClientField(clientField) {
    if (!clientField || clientField.type !== "hidden") return clientField

    const visibleTargetId = clientField.dataset.revalidationWizardVisibleTargetId
    if (!visibleTargetId) return null

    return document.getElementById(visibleTargetId)
  }
}
