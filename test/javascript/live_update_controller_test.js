import { beforeEach, describe, expect, test } from "bun:test"
import LiveUpdateController from "../../app/javascript/controllers/live_update_controller"

// Real-time updates in isolation: what the controller does with a refresh another
// reader's write produced.
//
// `test/system/live_updates_test.rb` proves the browser end of this — that a
// subscription is answered and a page changes without a reload — which is a
// statement about Solid Cable, Turbo, and Chrome together. What it cannot pin down
// is the decision this controller exists to make, because the interesting cases
// are the ones where the page must *not* refresh, and a system test asserting
// "the composer still has my text" is asserting an absence. So the rule is here,
// in the form that can be enumerated: which fields count as unsent work, and what
// happens to the refresh in each case.
describe("live update controller", () => {
  let refreshed
  let controller
  let host

  beforeEach(() => {
    // The controller listens on `document`, so a page-load-free test file would
    // otherwise leave the previous case's listener answering this case's streams.
    // Disconnecting is what Stimulus does on a real navigation.
    controller?.disconnect()

    document.body.innerHTML = ""
    refreshed = 0
    window.Turbo = { session: { refresh: () => { refreshed += 1 } } }

    host = document.createElement("div")
    host.innerHTML = `
      <div class="live-update-notice" data-live-update-target="notice"></div>
      <main id="fixture"></main>
    `
    document.body.append(host)

    controller = new LiveUpdateController()
    controller.element = host.querySelector(".live-update-notice")
    controller.connect()
  })

  // A `<turbo-stream>` element carries its marker in `data-live-update`, and Turbo
  // dispatches `turbo:before-stream-render` at it before acting. The controller cancels
  // that event, so a dispatched-and-inspected event is what a case can assert on.
  function deliverStream({ liveUpdate = "draft_applied", requestId = null } = {}) {
    const stream = document.createElement("turbo-stream")
    stream.setAttribute("action", "refresh")
    if (liveUpdate) stream.setAttribute("data-live-update", liveUpdate)
    if (requestId) stream.setAttribute("request-id", requestId)
    document.body.append(stream)

    const event = new CustomEvent("turbo:before-stream-render", { bubbles: true, cancelable: true, detail: { render: () => {} } })
    stream.dispatchEvent(event)
    stream.remove()
    return event
  }

  function noticeVisible() {
    return controller.element.classList.contains("live-update-notice--visible")
  }

  test("a refresh on a page with nothing unsent is applied", () => {
    const event = deliverStream()

    expect(event.defaultPrevented).toBe(true)
    expect(refreshed).toBe(1)
    expect(noticeVisible()).toBe(false)
  })

  test("a refresh is held while the composer holds unsent text", () => {
    const composer = document.createElement("textarea")
    composer.value = "Is she the heir?"
    document.querySelector("#fixture").append(composer)

    const event = deliverStream()

    expect(event.defaultPrevented).toBe(true)
    expect(refreshed).toBe(0)
    expect(noticeVisible()).toBe(true)
  })

  test("a field the server rendered the same value into is not unsent work", () => {
    const composer = document.createElement("textarea")
    composer.defaultValue = "Is she the heir?"
    composer.value = "Is she the heir?"
    document.querySelector("#fixture").append(composer)

    deliverStream()

    expect(refreshed).toBe(1)
    expect(noticeVisible()).toBe(false)
  })

  test("an emptied field is not unsent work either", () => {
    const notes = document.createElement("textarea")
    notes.defaultValue = ""
    notes.value = ""
    document.querySelector("#fixture").append(notes)

    deliverStream()

    expect(refreshed).toBe(1)
  })

  // A rejected modal editor is work in progress that has no field of its own to
  // compare: the JSON payload lives in the editor's JavaScript, not in a value the
  // server sent. Losing it to a refresh is the case this controller exists for.
  test("an open modal holds the refresh even with no dirty field", () => {
    const modal = document.createElement("div")
    modal.className = "modal show"
    document.body.append(modal)

    deliverStream()

    expect(refreshed).toBe(0)
    expect(noticeVisible()).toBe(true)
  })

  test("a checkbox and a radio do not make every page unsent", () => {
    const form = document.createElement("form")
    form.innerHTML = `
      <input type="checkbox" checked>
      <input type="radio" name="answer" value="mine" checked>
      <input type="hidden" name="authenticity_token" value="token">
    `
    document.querySelector("#fixture").append(form)

    deliverStream()

    expect(refreshed).toBe(1)
    expect(noticeVisible()).toBe(false)
  })

  // The defect this case exists for: the photo editor's zoom slider is a `range`
  // whose value its own controller writes after the page arrives, so it never equals
  // the `value` the server sent. Asking about it would report every list workspace
  // as holding unsent work — every modal editor is in the DOM even while it is
  // closed — and hold every live update in the application.
  test("a range input given its value by a controller is not unsent work", () => {
    const zoom = document.createElement("input")
    zoom.type = "range"
    zoom.defaultValue = ""
    zoom.value = "100"
    document.querySelector("#fixture").append(zoom)

    deliverStream()

    expect(refreshed).toBe(1)
    expect(noticeVisible()).toBe(false)
  })

  // A staged photo is unsent work, and a file input's `defaultValue` is always empty,
  // so any chosen file reads as a change against it.
  test("a staged file counts as unsent work", () => {
    const file = document.createElement("input")
    file.type = "file"
    document.querySelector("#fixture").append(file)

    deliverStream()

    expect(refreshed).toBe(1)
    expect(noticeVisible()).toBe(false)
  })

  test("an input whose value the reader changed counts as unsent work", () => {
    const input = document.createElement("input")
    input.type = "text"
    input.defaultValue = ""
    input.value = "half-written filter"
    document.querySelector("#fixture").append(input)

    deliverStream()

    expect(refreshed).toBe(0)
    expect(noticeVisible()).toBe(true)
  })

  test("the notice's own controls reload and dismiss", () => {
    const composer = document.createElement("textarea")
    composer.value = "Is she the heir?"
    document.querySelector("#fixture").append(composer)
    deliverStream()

    expect(noticeVisible()).toBe(true)

    controller.reload()
    expect(refreshed).toBe(1)

    controller.dismiss()
    expect(noticeVisible()).toBe(false)
  })

  // A stream that is not one of ours is not this controller's business. Turbo
  // broadcasts nothing else today, and a controller that cancelled a refresh it
  // did not recognise would be a controller silently swallowing another feature's
  // updates the day that feature arrives.
  test("a stream without the marker is left to Turbo", () => {
    const event = deliverStream({ liveUpdate: null })

    expect(event.defaultPrevented).toBe(false)
    expect(refreshed).toBe(0)
    expect(noticeVisible()).toBe(false)
  })

  // The page's own echo. A broadcast published inside a request carries that
  // request's id, and Turbo drops a refresh carrying an id the page has just made
  // itself — which is how the person who pressed **Apply changes** is not refreshed
  // underneath the navigation they are already doing. Deciding that here would mean
  // keeping a second list of the browser's recent requests; leaving it to Turbo means
  // this controller only ever answers about other readers.
  test("a broadcast carrying a request id is left to Turbo's own echo check", () => {
    const event = deliverStream({ requestId: "b1946ac9-1a4e-4b1a-9a1c-8f0f5a2b3c4d" })

    expect(event.defaultPrevented).toBe(false)
    expect(refreshed).toBe(0)
    expect(noticeVisible()).toBe(false)
  })

  test("disconnecting stops the controller answering further streams", () => {
    controller.disconnect()

    const event = deliverStream()

    expect(event.defaultPrevented).toBe(false)
  })
})
