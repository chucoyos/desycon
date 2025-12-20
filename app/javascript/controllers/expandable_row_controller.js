import { Controller } from "@hotwired/stimulus"

// Toggles an expandable details row inside a table.
// Guards clicks on links/buttons so primary actions still work.
export default class extends Controller {
  static targets = ["content", "chevron"]

  toggle(event) {
    if (this._shouldIgnore(event)) return

    const isOpen = this.contentTarget.classList.toggle("hidden") === false
    this.element.classList.toggle("bg-indigo-50/40", isOpen)
    this.chevronTargets.forEach((chevron) => {
      chevron.classList.toggle("rotate-90", isOpen)
      chevron.classList.toggle("text-indigo-500", isOpen)
    })
  }

  stop(event) {
    event.stopPropagation()
  }

  _shouldIgnore(event) {
    const interactive = event.target.closest("a, button, input, select, textarea")
    return Boolean(interactive)
  }
}
