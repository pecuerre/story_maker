import { Controller } from "@hotwired/stimulus"
import "bootstrap"

// A Bootstrap popover on a control that is not otherwise interactive: the info
// button beside a record's `scope: universe` line, which explains what a scope
// means without putting the explanation on the card itself.
//
// The title and the content are Stimulus values rather than literals because the
// application ships two locales and the browser must show the same words the
// server rendered (see docs/features/i18n.md). The trigger set is the Timeline's:
// `hover focus click`, because a touch pointer never hovers.
//
// This is a thin wrapper on purpose. Bootstrap's Popover already reads its own
// `data-bs-*` attributes; the only reason a controller exists at all is that
// something has to call the constructor and dispose of the instance on the way
// out, which is what Stimulus' connect/disconnect pair gives us for free.
export default class extends Controller {
  static values = { title: String, content: String, placement: { default: "top" } }

  connect() {
    // The values are passed as options rather than left to Bootstrap's own
    // `data-bs-*` lookup, so the copy reaches the popover from the Stimulus value
    // the view rendered rather than from a second copy of it on the element.
    this.popover = new window.bootstrap.Popover(this.element, {
      title: this.titleValue,
      content: this.contentValue,
      placement: this.placementValue
    })
  }

  disconnect() {
    // The reference is cleared as well as disposed, so a second disconnect is a
    // no-op rather than a second `dispose()` on an instance Bootstrap has already
    // released. Turbo can disconnect and reconnect a controller around a visit, and
    // nothing about that pair is guaranteed to be balanced.
    this.popover?.dispose()
    this.popover = null
  }
}