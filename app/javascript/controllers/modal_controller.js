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
      // For static modals (name and fiscal), reset forms
      if (modalId === 'name-modal' || modalId === 'fiscal-modal') {
        const forms = modal.querySelectorAll('form')
        forms.forEach(form => {
          // Reset the form
          form.reset()

          // Re-enable any disabled submit buttons and restore original text
          const submitButtons = form.querySelectorAll('input[type="submit"], button[type="submit"]')
          submitButtons.forEach(button => {
            button.disabled = false
            // Restore original button text if it was changed by Rails
            if (button.hasAttribute('data-disable-with')) {
              const originalText = button.getAttribute('value') || button.textContent
              button.setAttribute('data-original-value', originalText)
              button.setAttribute('data-original-text', originalText)
              button.removeAttribute('data-disable-with')
            }
          })
        })
      }

      modal.classList.remove('hidden')
      console.log('Modal opened:', modalId)

      // Handle dynamic form loading for edit modals
      if (modalId === 'address-modal') {
        const addressId = event.currentTarget.dataset.addressId
        if (addressId) {
          this.loadAddressForm(addressId)
        }
      } else if (modalId === 'patent-modal') {
        const patentId = event.currentTarget.dataset.patentId
        if (patentId) {
          this.loadPatentForm(patentId)
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

  loadPatentForm(patentId) {
    const container = document.getElementById('edit-patent-form-container')
    if (!container) return

    container.innerHTML = '<p class="text-gray-500 text-center py-4">Cargando formulario...</p>'

    // Get the entity ID from the current URL
    const urlParts = window.location.pathname.split('/')
    const entityId = urlParts[urlParts.indexOf('entities') + 1]

    // Fetch the edit form
    fetch(`/entities/${entityId}/customs_agent_patents/${patentId}/edit`, {
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
      console.error('Error loading patent form:', error)
      container.innerHTML = '<p class="text-red-600">Error al cargar el formulario</p>'
    })
  }
}