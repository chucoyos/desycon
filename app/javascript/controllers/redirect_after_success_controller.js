import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    if (window.location.pathname.endsWith("/revalidation_approval")) {
      if (typeof Turbo !== 'undefined') {
        Turbo.visit(this.urlValue)
      } else {
        window.location.href = this.urlValue
      }
    }
    // If not on standalone page, do nothing (or we could remove the element)
    // The mere presence of this controller on an empty div inside the turbo frame
    // effectively "closes" the modal by replacing the content with nothing visible.
  }
}
