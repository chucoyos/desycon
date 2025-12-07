import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    console.log('Modal controller connected')
  }

  open(event) {
    console.log('Modal open triggered', event.currentTarget.dataset.modalId)
    event.preventDefault()
    const modalId = event.currentTarget.dataset.modalId
    const modal = document.getElementById(modalId)
    if (modal) {
      modal.classList.remove('hidden')
      console.log('Modal opened:', modalId)
    } else {
      console.error('Modal not found:', modalId)
    }
  }

  close(event) {
    event.preventDefault()
    const modal = event.currentTarget.closest('[data-modal-target="modal"]')
    if (modal) {
      modal.classList.add('hidden')
    }
  }

  // Close modal when clicking on backdrop
  closeOnBackdrop(event) {
    if (event.target === event.currentTarget) {
      event.currentTarget.classList.add('hidden')
    }
  }

  // Close modal on escape key
  connect() {
    this.escapeHandler = (event) => {
      if (event.key === 'Escape') {
        this.modalTargets.forEach(modal => {
          modal.classList.add('hidden')
        })
      }
    }
    document.addEventListener('keydown', this.escapeHandler)
  }

  disconnect() {
    document.removeEventListener('keydown', this.escapeHandler)
  }
}