import { Controller } from "@hotwired/stimulus"
import "tom-select"

// Upgrades a <select> into a searchable picker: a pillbox with a remove control
// for a multi-select, and a single searchable choice for a select-one. The
// server renders the options in the order it wants them searched, so a long
// catalogue is browsable instead of being read in model order.
export default class extends Controller {
  connect() {
    this.tomSelect = new window.TomSelect(this.element, {
      plugins: this.element.multiple ? [ "remove_button" ] : [],
      create: false,
      allowEmptyOption: true
    })
  }

  disconnect() {
    this.tomSelect?.destroy()
  }
}
