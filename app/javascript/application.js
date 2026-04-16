// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import * as ActiveStorage from "@rails/activestorage"
import "controllers"

ActiveStorage.start()

// Load charts as an optional enhancement so core UI interactions (Stimulus)
// keep working even if a chart dependency fails in a given environment.
import("chartkick/highcharts").catch((error) => {
  console.error("Chart adapter failed to load:", error)
})

// Clear revalidation modal before navigation/snapshot to avoid cached flashes
const clearRevalidationModal = () => {
  const frame = document.getElementById('revalidation_modal')
  if (frame) frame.innerHTML = ''
}

document.addEventListener('turbo:before-visit', clearRevalidationModal)
document.addEventListener('turbo:before-cache', clearRevalidationModal)
