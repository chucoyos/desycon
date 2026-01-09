import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "target"]
  static values = {
    param: String
  }

  connect() {
    this.filter()
  }

  filter() {
    const selectedValue = this.sourceTarget.value.toString()
    
    // Reset target select
    this.targetTarget.value = ""
    
    // Show/hide options based on data-group matching selected value
    Array.from(this.targetTarget.options).forEach(option => {
      const group = option.dataset.group
      
      // Always show placeholder (empty value)
      if (!option.value) {
        option.hidden = false
        return
      }
      
      if (group === selectedValue) {
        option.hidden = false
        option.disabled = false
      } else {
        option.hidden = true
        option.disabled = true
      }
    })

    // If current value is now hidden, reset selection
    if (this.targetTarget.selectedOptions[0].hidden) {
        this.targetTarget.value = ""
    }
  }
}
