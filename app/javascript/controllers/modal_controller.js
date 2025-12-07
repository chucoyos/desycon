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

      // Handle dynamic form loading for edit modals
      if (modalId === 'address-modal') {
        const addressId = event.currentTarget.dataset.addressId
        if (addressId) {
          this.loadAddressForm(addressId)
        }
      }
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

  loadAddressForm(addressId) {
    const container = document.getElementById('edit-address-form-container')
    if (!container) return

    // Get the entity ID from the current URL
    const urlParts = window.location.pathname.split('/')
    const entityId = urlParts[urlParts.indexOf('entities') + 1]

    // Fetch the edit form
    fetch(`/entities/${entityId}/addresses/${addressId}/edit`, {
      headers: {
        'Accept': 'text/html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.text())
    .then(html => {
      container.innerHTML = html
    })
    .catch(error => {
      console.error('Error loading address form:', error)
      container.innerHTML = '<p class="text-red-600">Error al cargar el formulario</p>'
    })
  }
}