import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["role", "entity"]

  connect() {
    this.filter()
  }

  filter() {
    const selectedRoleOption = this.roleTarget.selectedOptions[0]
    const requiredEntityRoleKind = selectedRoleOption?.dataset.entityRoleKind || ""
    const selectedEntityValue = this.entityTarget.value
    let hasVisibleSelection = selectedEntityValue === ""

    Array.from(this.entityTarget.options).forEach(option => {
      const isPlaceholder = !option.value
      const entityRoleKind = option.dataset.roleKind || ""
      const isMatch = requiredEntityRoleKind !== "" && entityRoleKind === requiredEntityRoleKind

      if (isPlaceholder) {
        option.hidden = false
        option.disabled = false
        return
      }

      option.hidden = !isMatch
      option.disabled = !isMatch

      if (isMatch && option.value === selectedEntityValue) {
        hasVisibleSelection = true
      }
    })

    if (!hasVisibleSelection) {
      this.entityTarget.value = ""
    }
  }
}
