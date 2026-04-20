import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    markAsReadUrl: String,
    deleteUrl: String
  }

  markAsRead() {
    if (!this.hasMarkAsReadUrlValue) return

    const csrfToken = document.querySelector("[name='csrf-token']")?.content
    if (!csrfToken) return

    fetch(this.markAsReadUrlValue, {
      method: "PATCH",
      keepalive: true,
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "text/vnd.turbo-stream.html"
      }
    })
  }

  deleteNotification() {
    if (!this.hasDeleteUrlValue) return

    const csrfToken = document.querySelector("[name='csrf-token']").content

    fetch(this.deleteUrlValue, {
      method: "DELETE",
      keepalive: true,
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
