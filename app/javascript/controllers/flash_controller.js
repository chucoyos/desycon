import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    type: String,
    message: String
  }

  connect() {
    this.showFlash()
  }

  showFlash() {
    const type = this.typeValue
    const message = this.messageValue
    
    // Crear el contenedor de toast si no existe
    let container = document.getElementById('toast-container')
    if (!container) {
      container = document.createElement('div')
      container.id = 'toast-container'
      container.className = 'toast-top-right'
      document.body.appendChild(container)
    }

    // Crear el toast
    const toast = document.createElement('div')
    toast.className = `toast toast-${type === 'notice' ? 'success' : type === 'alert' ? 'error' : 'info'}`
    toast.setAttribute('aria-live', 'polite')
    
    const iconMap = {
      notice: '✓',
      alert: '✕',
      error: '✕'
    }
    
    const icon = iconMap[type] || 'ℹ'
    
    toast.innerHTML = `
      <button type="button" class="toast-close-button" role="button">×</button>
      <div class="toast-message">${icon} ${message}</div>
    `

    container.appendChild(toast)

    // Animar entrada desde la derecha
    setTimeout(() => {
      toast.style.transform = 'translateX(0)'
      toast.style.opacity = '1'
    }, 10)

    // Función para cerrar el toast
    const closeToast = () => {
      toast.style.transform = 'translateX(400px)'
      toast.style.opacity = '0'
      setTimeout(() => toast.remove(), 300)
    }

    // Agregar evento de cierre
    const closeButton = toast.querySelector('.toast-close-button')
    closeButton.addEventListener('click', closeToast)

    // Auto-remover después de 5 segundos
    setTimeout(closeToast, 5000)
  }
}
