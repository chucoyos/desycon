// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

console.log('Turbo loaded:', typeof window.Turbo)
console.log('Stimulus loaded:', typeof window.Stimulus)

// Ensure Stimulus controllers are connected after Turbo updates
document.addEventListener('turbo:load', () => {
  console.log('Turbo load event - ensuring Stimulus controllers are connected')
  // Stimulus should automatically connect controllers, but let's force a refresh
  if (window.Stimulus) {
    window.Stimulus.application?.start()
  }
})

// Debug Turbo events
document.addEventListener('turbo:submit-start', (event) => {
  console.log('Turbo submit start:', event.detail.formAction)
})

document.addEventListener('turbo:submit-end', (event) => {
  console.log('Turbo submit end:', event.detail.success)
})

document.addEventListener('turbo:before-fetch-request', (event) => {
  console.log('Turbo fetch request:', event.detail.fetchOptions.method, event.detail.url)
})

document.addEventListener('turbo:before-fetch-response', (event) => {
  console.log('Turbo fetch response:', event.detail.fetchResponse.status, event.detail.fetchResponse.contentType)
})

// Debug Turbo stream processing
document.addEventListener('turbo:before-stream-render', (event) => {
  console.log('Turbo stream render:', event.detail.newStream)
})

// Clear revalidation modal before navigation/snapshot to avoid cached flashes
const clearRevalidationModal = () => {
  const frame = document.getElementById('revalidation_modal')
  if (frame) frame.innerHTML = ''
}

document.addEventListener('turbo:before-visit', clearRevalidationModal)
document.addEventListener('turbo:before-cache', clearRevalidationModal)

// Debug form submissions
document.addEventListener('submit', (event) => {
  console.log('Form submitted:', event.target.action, event.target.method)
})

// Debug JavaScript errors
window.addEventListener('error', (event) => {
  console.error('JavaScript error:', event.error, event.message, event.filename, event.lineno)
})

window.addEventListener('unhandledrejection', (event) => {
  console.error('Unhandled promise rejection:', event.reason)
})
