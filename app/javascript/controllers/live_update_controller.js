import { Controller } from "@hotwired/stimulus"

// Another reader's change, delivered over the websocket.
//
// `LiveUpdates` publishes `<turbo-stream action="refresh" data-live-update="...">`
// to three signed streams, and Turbo's own handling of a refresh is to re-request
// the page. That is the right default and the wrong default at the same time: this
// application has unsent work in a composer, in a reviewer's notes, in a
// submission message, in a modal editor's JSON payload, and in the Scenes filter,
// and a refresh throws all of it away without asking. So this controller takes the
// refresh over — it cancels Turbo's own and decides for itself.
//
// The rule it decides by is deliberately one question rather than four: **does
// this page hold anything the reader typed that the server did not send?** A field
// is unsent when its value differs from the value the server rendered into it
// (`defaultValue`), which is the browser's own record of what it was given and
// costs nothing to ask. An open Bootstrap modal counts as unsent for the same
// reason a dirty field does: what is inside it is being edited and has not been
// submitted.
//
// When the answer is no, the refresh is applied. When it is yes, the refresh is
// held and the notice is shown, so the reader decides when their work is worth
// losing — which is the only decision here that is actually theirs.
//
// The controller is attached to a permanently present hidden element rather than
// to the stream source, because there is one of these per page while the streams
// differ per page, and because the notice has to be somewhere on the page to be
// revealed into.

// The input types whose value is something a reader typed or chose into a field the
// server rendered. `textarea` is what `field.type` reports for a textarea.
//
// Two kinds are deliberately absent, and both would otherwise report every page as
// holding unsent work:
//
//   - `range` and `color`, which this application's photo editor writes its value
//     into after the page was rendered — the zoom slider arrives with no value and
//     its controller sets `100` — so their value never matches what the server sent.
//   - `checkbox` and `radio`, whose `value` is the string `"on"` whether or not they
//     are ticked, so comparing it says nothing about whether they are ticked.
//
// `file` is here because a staged photo is exactly the work a refresh discards, and a
// file input's `defaultValue` is always empty, so any chosen file reads as a change.
const TYPED_TYPES = new Set([
  "date",
  "datetime-local",
  "email",
  "file",
  "month",
  "number",
  "password",
  "search",
  "tel",
  "text",
  "textarea",
  "time",
  "url",
  "week",
])

export default class extends Controller {
  connect() {
    this.handleStreamRender = this.handleStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.handleStreamRender)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.handleStreamRender)
  }

  // Turbo asks this question at every `<turbo-stream>` before acting on it, and it
  // is cancelable, which is the whole mechanism: cancelling takes the refresh away
  // from Turbo's own handler and leaves the decision to this controller.
  //
  // **A broadcast that carries a `request-id` is left alone**, because that attribute
  // is Turbo's own answer to "is this the page that caused this?": the browser
  // remembers the ids of the requests it has just made, and a refresh carrying one of
  // them is its own echo. That is how the person who pressed **Apply changes** is
  // kept out of their own refresh, and it is a question about the browser's history
  // of requests rather than about what is typed on the page, so this controller has
  // nothing to add to it.
  handleStreamRender(event) {
    const stream = event.target
    if (!stream?.dataset?.liveUpdate) return
    if (stream.getAttribute("request-id")) return

    event.preventDefault()

    if (this.hasUnsentWork()) {
      this.revealNotice()
    } else {
      this.reload()
    }
  }

  // The notice's own control. This is Turbo's **session** refresh rather than a hard
  // navigation or `Turbo.refresh()`: the public `Turbo` object exposes `visit` but
  // not `refresh`, so a refresh action is reached the way Turbo's own stream handler
  // reaches it. It keeps the history entry and the scroll position, which is what a
  // refresh means everywhere else in this application.
  reload() {
    window.Turbo?.session?.refresh(window.location.href)
  }

  dismiss() {
    this.notice.classList.remove("live-update-notice--visible")
  }

  revealNotice() {
    this.notice.classList.add("live-update-notice--visible")
  }

  hasUnsentWork() {
    return this.hasOpenModal() || this.hasDirtyField()
  }

  // An open modal counts as unsent work for the reason a dirty field does: whatever
  // is inside it is being edited and has not been submitted, and a refresh discards
  // it without asking. The Scenes workspace's filter is deliberately **not** treated
  // as unsent, because it lives in the URL and a refresh keeps it.
  hasOpenModal() {
    return document.querySelector(".modal.show") !== null
  }

  hasDirtyField() {
    return Array.from(document.querySelectorAll("textarea, input")).some((field) => this.isDirty(field))
  }

  // `defaultValue` is the browser's own record of what the server rendered, which is
  // what makes this one question rather than four: the search bar, the modal editors,
  // the composers, and every filter input that came back populated are all answered
  // by the same comparison.
  //
  // The comparison, asked of `TYPED_TYPES` only — see above for the two kinds that
  // are excluded and why. A `select` is never asked about, which is deliberate: the
  // Scenes filter's selects were server-rendered, so their value is their own
  // `defaultValue`, and a filter the reader has changed is a change they have made
  // with the keyboard rather than unsent work.
  isDirty(field) {
    if (!TYPED_TYPES.has(field.type)) return false
    if (field.disabled || field.readOnly) return false

    return field.value !== field.defaultValue
  }

  // The notice is this controller's own element rather than a target inside it: the
  // layout renders one permanently hidden element per page, and there is nothing
  // else in it for a target to be worth addressing.
  get notice() {
    return this.element
  }
}
