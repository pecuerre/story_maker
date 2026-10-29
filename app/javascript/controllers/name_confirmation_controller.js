import { Controller } from "@hotwired/stimulus"

// Keeps the permanent-delete button disabled until the typed name is exactly the
// universe's name. The comparison is deliberate and literal: no trimming, no
// case folding, no Unicode normalization, because the server applies the same
// rule and the reader is being asked to prove they know which universe this is.
//
// This is only the browser half. The form still submits when JavaScript has not
// loaded (the button is rendered enabled), and the server re-compares the value
// against the record it authorized, so disabling the button can never be the
// thing that makes the operation safe.
export default class extends Controller {
  static targets = ["input", "submit"]
  static values = { expected: String }

  connect() {
    this.check()
  }

  check() {
    if (!this.inputTarget || !this.submitTarget) return

    this.submitTarget.disabled = this.inputTarget.value !== this.expectedValue
  }
}
