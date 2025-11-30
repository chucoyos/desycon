import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    // Close dropdown when clicking outside
    this.boundClose = this.closeOnClickOutside.bind(this)
    // Close dropdown before Turbo navigation
    this.boundBeforeVisit = this.close.bind(this)
    document.addEventListener('turbo:before-visit', this.boundBeforeVisit)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    if (this.menuTarget.classList.contains('hidden')) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove('hidden')
    document.addEventListener('click', this.boundClose)
  }

  close() {
    this.menuTarget.classList.add('hidden')
    document.removeEventListener('click', this.boundClose)
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  disconnect() {
    document.removeEventListener('click', this.boundClose)
    document.removeEventListener('turbo:before-visit', this.boundBeforeVisit)
  }
}
