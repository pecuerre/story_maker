import { Controller } from "@hotwired/stimulus"

// Narration cannot keep speakers and a Dialogue must name at least one, so the
// speaker picker and the confirmation that removes speakers are the same
// decision seen from two sides. This controller only shows which of them
// applies: the server is what enforces the rule, and it refuses a Narration
// that still has speakers unless the request carries the explicit confirmation.
//
// The picker is hidden rather than disabled, so a hidden selection is still
// submitted and the server can see that there is something to confirm. A modal
// that has not opened yet is left in the state the server rendered, so the page
// is correct without scripting.
export default class extends Controller {
  static targets = [ "kind", "kindDescription", "speakers", "speakerPicker", "removeSpeakers" ]
  static values = { descriptions: Object }

  connect() {
    this.modal = this.element.closest(".modal")
    this.handleShown = () => this.sync()
    this.modal?.addEventListener("shown.bs.modal", this.handleShown)
    this.sync()
  }

  disconnect() {
    this.modal?.removeEventListener("shown.bs.modal", this.handleShown)
  }

  sync() {
    const kind = this.kindTarget.value
    const dialogue = kind === "dialogue"
    const hasSpeakers = [ ...this.speakerPickerTarget.selectedOptions ].length > 0

    this.speakersTarget.hidden = !dialogue
    // Only offered when switching a Dialogue that has speakers to Narration:
    // without speakers there is nothing to confirm.
    this.removeSpeakersTarget.hidden = dialogue || !hasSpeakers
    this.kindDescriptionTarget.textContent = this.descriptionsValue[kind] || ""
  }
}
