import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "target"]
  static values = {
    param: String,
    sourceSelector: String
  }

  connect() {
    this.boundFilter = this.filter.bind(this)
    this.attachExternalListener()
    this.filter()
  }

  disconnect() {
    this.detachExternalListener()
  }

  get sourceElement() {
    if (this.hasSourceTarget) return this.sourceTarget
    if (this.hasSourceSelectorValue) return document.querySelector(this.sourceSelectorValue)
    return null
  }

  attachExternalListener() {
    if (this.hasSourceTarget) return
    if (!this.hasSourceSelectorValue) return

    const el = this.sourceElement
    if (!el) return

    el.addEventListener("change", this.boundFilter)
    this.externalSource = el
  }

  detachExternalListener() {
    if (this.externalSource) {
      this.externalSource.removeEventListener("change", this.boundFilter)
      this.externalSource = null
    }
  }

  filter() {
    const source = this.sourceElement
    const selectedValue = source?.value?.toString() || ""
    const currentValue = this.targetTarget.value
    let hasVisibleSelection = false

    Array.from(this.targetTarget.options).forEach(option => {
      const group = option.dataset.group
      const isPlaceholder = !option.value
      const matchesGroup = !!selectedValue && group === selectedValue

      if (isPlaceholder) {
        option.hidden = false
        option.disabled = false
        hasVisibleSelection ||= currentValue === ""
        return
      }

      option.hidden = !matchesGroup
      option.disabled = !matchesGroup

      if (matchesGroup && option.value === currentValue) {
        hasVisibleSelection = true
      }
    })

    if (!hasVisibleSelection) {
      this.targetTarget.value = ""
    }
  }
}
