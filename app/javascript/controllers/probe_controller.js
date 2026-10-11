import { Controller } from "@hotwired/stimulus"

// Fills the reading box from the roving probe via Home Assistant. Stops short of
// recording: the person still looks at the number and presses Record.
export default class extends Controller {
  static targets = ["value", "source", "status"]
  static values = { url: String }

  async fetch() {
    this.statusTarget.textContent = "Asking Home Assistant…"

    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      const body = await response.json()
      if (!response.ok) throw new Error(body.error)

      this.valueTarget.value = body.value
      this.sourceTarget.value = "zigbee"
      this.statusTarget.textContent = `Probe reported ${body.value}% ${this.ago(body.reported_at)}. Check it's settled, then Record.`
    } catch (error) {
      this.statusTarget.textContent = error.message || "Couldn't reach Home Assistant."
    }
  }

  typed() {
    this.sourceTarget.value = "manual"
    this.statusTarget.textContent = ""
  }

  ago(timestamp) {
    const seconds = Math.max(0, Math.round((Date.now() - new Date(timestamp)) / 1000))
    if (seconds < 60) return `${seconds}s ago`
    if (seconds < 3600) return `${Math.round(seconds / 60)} min ago`
    return `${Math.round(seconds / 3600)} h ago`
  }
}
