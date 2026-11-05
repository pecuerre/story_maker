import { Controller } from "@hotwired/stimulus"

// The two Scene Element kinds write their prose in different places: a Narration
// keeps it in Content, while a Dialogue keeps it in its ordered turns. This
// controller only shows the control the chosen kind uses; the server is what
// enforces that a Narration cannot keep turns, and the turn editor refuses to
// add one until the element is a saved Dialogue.
//
// A modal that has not opened yet is left in the state the server rendered, so
// the page is correct without scripting.
export default class extends Controller {
  static targets = [ "kind", "kindDescription", "body" ]
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

    this.bodyTarget.hidden = dialogue
    this.kindDescriptionTarget.textContent = this.descriptionsValue[kind] || ""
  }
}
