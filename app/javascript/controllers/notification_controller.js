import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String
  }

  deleteNotification(event) {
    const csrfToken = document.querySelector("[name='csrf-token']").content

    fetch(this.urlValue, {
      method: "DELETE",
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
