import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
export default class extends Controller {
  static values = {
    url: String,
    frame: String
  }

  async changeAgent(event) {
    const agentId = event.target.value
    const baseUrl = this.urlValue

    if (!agentId || !baseUrl) return

    const url = `${baseUrl}?agent_id=${encodeURIComponent(agentId)}`

    const response = await fetch(url, {
      headers: { Accept: "text/vnd.turbo-stream.html" }
    })

    if (response.ok) {
      const stream = await response.text()
      Turbo.renderStreamMessage(stream)
    }
  }
}
