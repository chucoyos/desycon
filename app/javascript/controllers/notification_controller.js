import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    read: Boolean
  }

  markAsRead(event) {
    if (this.readValue) return

    const csrfToken = document.querySelector("[name='csrf-token']").content

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "text/vnd.turbo-stream.html"
      }
    })
    .then(response => response.text())
    .then(html => {
      if (window.Turbo) {
        window.Turbo.renderStreamMessage(html)
      }
    })
  }
}
