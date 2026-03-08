import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

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

  open(event) {
    event.preventDefault()
    const modalId = event.currentTarget.dataset.modalId
    const modal = document.getElementById(modalId)

    if (modal) {
      // For static modal (fiscal), reset forms
      if (modalId === 'fiscal-modal') {
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

      // Handle dynamic form loading for edit modals
      if (modalId === 'address-modal') {
        const addressId = event.currentTarget.dataset.addressId
        const context = event.currentTarget.dataset.addressContext
        if (addressId) {
          if (!this.injectAddressFormFromTemplate(addressId, context)) {
            this.loadAddressForm(addressId, context)
          }
        }
      }

      if (modalId === 'new-address-modal') {
        const requestedType = event.currentTarget.dataset.addressTipo
        const typeSelect = modal.querySelector('select[name="address[tipo]"]')
        const title = modal.querySelector('#new-address-modal-title')

        if (typeSelect && requestedType) {
          typeSelect.value = requestedType
        }

        if (title) {
          title.textContent = requestedType === 'sucursal' ? 'Agregar Sucursal' : 'Agregar Domicilio Fiscal'
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

  closeAndSubmit(event) {
    const form = event.currentTarget
    const modal = form.closest('[data-modal-target="modal"]')

    if (modal) {
      modal.classList.add('hidden')
    }

    const submitButton = form.querySelector('input[type="submit"], button[type="submit"]')
    if (submitButton) {
      submitButton.disabled = true
      if (submitButton.tagName.toLowerCase() === 'input') {
        submitButton.value = 'Procesando...'
      } else {
        submitButton.textContent = 'Procesando...'
      }
    }
  }

  // Close modal when clicking on backdrop
  closeOnBackdrop(event) {
    if (event.target === event.currentTarget) {
      event.currentTarget.classList.add('hidden')
    }
  }

  disconnect() {
    document.removeEventListener('keydown', this.escapeHandler)
  }

  injectAddressFormFromTemplate(addressId, context = null) {
    const container = document.getElementById('edit-address-form-container')
    if (!container) return false

    const contextKey = context || 'show'
    const template = document.getElementById(`address-edit-template-${addressId}-${contextKey}`)
    if (!template) return false

    container.innerHTML = template.innerHTML
    return true
  }

  loadAddressForm(addressId, context = null) {
    const container = document.getElementById('edit-address-form-container')
    if (!container) return

    // Get the entity ID from the current URL
    const urlParts = window.location.pathname.split('/')
    const entityId = urlParts[urlParts.indexOf('entities') + 1]

    // Fetch the edit form
    const query = context ? `?context=${encodeURIComponent(context)}` : ""
    fetch(`/entities/${entityId}/addresses/${addressId}/edit${query}`, {
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