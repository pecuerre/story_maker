import { Controller } from "@hotwired/stimulus"
import "tom-select"

// Upgrades a <select multiple> into a searchable pillbox (tags + narrowing search), à la Select2.
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
