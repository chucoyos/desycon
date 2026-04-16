// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import * as ActiveStorage from "@rails/activestorage"
import "controllers"

ActiveStorage.start()

// Load charts as an optional enhancement so core UI interactions (Stimulus)
// keep working even if chart dependencies fail in a given environment.
Promise.all([import("chartkick"), import("highcharts")])
  .then(([chartkickModule, highchartsModule]) => {
    const chartkick = chartkickModule?.default || chartkickModule?.Chartkick || window.Chartkick
    const highcharts = highchartsModule?.default || highchartsModule?.highcharts || highchartsModule

    if (chartkick?.use && highcharts) {
      chartkick.use(highcharts)
      return
    }

    throw new Error("Unable to initialize Chartkick with Highcharts")
  })
  .catch((error) => {
    console.error("Chart libraries failed to initialize:", error)
  })

// Clear revalidation modal before navigation/snapshot to avoid cached flashes
const clearRevalidationModal = () => {
  const frame = document.getElementById('revalidation_modal')
  if (frame) frame.innerHTML = ''
}

document.addEventListener('turbo:before-visit', clearRevalidationModal)
document.addEventListener('turbo:before-cache', clearRevalidationModal)
