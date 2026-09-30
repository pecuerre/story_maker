import { beforeEach, describe, expect, test } from "bun:test"
import ModalFormController from "../../app/javascript/controllers/modal_form_controller"

// The shared flat-list/HTML-flow modal editor. Every case here is a defect that
// the browser suite once had to discover, expressed as a unit test: the modal
// serializes its own request, attaches the CSRF token, and has to explain a
// rejection in a form the author can act on.
function build(formHtml, { withSummary = true } = {}) {
  const host = document.createElement("div")
  host.innerHTML = `
    <div data-mutation-status hidden class="visually-hidden"></div>
    ${ withSummary ? '<div data-modal-form-target="errors" tabindex="-1" hidden></div>' : "" }
    ${ formHtml }
  `
  document.body.append(host)

  const controller = new ModalFormController()
  controller.modelParamValue = "character"
  controller.responseValue = "json"
  controller.formTarget = host.querySelector("form")
  controller.modalTarget = host.querySelector("[data-modal-form-target='modal']")
  controller.shown = true
  controller.hasErrorsTarget = withSummary
  controller.errorsTarget = host.querySelector("[data-modal-form-target='errors']")
  controller.submitTargets = [ ...host.querySelectorAll("[data-modal-form-target='submit']") ]
  return { controller, host, form: controller.formTarget }
}

// happy-dom's `FormData` does not model a multi-select the way a browser does:
// it repeats no selected option and invents a blank entry for an empty one. The
// cases that depend on that contract stub `FormData` with the real browser
// behavior instead of asserting against the emulation.
function stubFormData(entries) {
  const original = globalThis.FormData
  globalThis.FormData = class {
    forEach(callback) {
      entries.forEach(([ key, value ]) => {
        callback(value, key)
      })
    }
  }
  return () => {
    globalThis.FormData = original
  }
}

function csrfMeta(content) {
  const meta = document.createElement("meta")
  meta.name = "csrf-token"
  meta.content = content
  document.head.append(meta)
  return meta
}

function captureFetch(response = new Response("{}", { status: 200 })) {
  const calls = []
  globalThis.fetch = async (url, options) => {
    calls.push({ url, options })
    if (response instanceof Error) throw response
    return response
  }
  return calls
}

beforeEach(() => {
  document.head.innerHTML = ""
  document.body.innerHTML = ""
  globalThis.fetch = async () => new Response("{}", { status: 200 })
})

describe("modal form request", () => {
  test("sends the page's CSRF token and asks for JSON", async () => {
    const meta = csrfMeta("token-from-meta")
    const calls = captureFetch()
    const { controller } = build('<form data-modal-form-target="form"><input name="character[name]" value="Lisbeth"></form>')

    const params = controller.formPayload(controller.formTarget)
    const response = await controller.request("/u/dark/characters", "POST", params)

    expect(response.ok).toBe(true)
    expect(calls).toHaveLength(1)
    expect(calls[0].url).toBe("/u/dark/characters")
    expect(calls[0].options.method).toBe("POST")
    expect(calls[0].options.headers.Accept).toBe("application/json")
    expect(calls[0].options.headers["Content-Type"]).toBe("application/x-www-form-urlencoded;charset=UTF-8")
    expect(calls[0].options.headers["X-CSRF-Token"]).toBe("token-from-meta")
    expect(calls[0].options.body).toBe(params)
    expect(params.get("character[name]")).toBe("Lisbeth")
    meta.remove()
  })

  test("omits the token header instead of sending an undefined one", async () => {
    const calls = captureFetch()
    const { controller } = build("<form></form>")

    await controller.request("/u/dark/characters", "DELETE", new URLSearchParams())

    expect(calls[0].options.headers["X-CSRF-Token"]).toBeUndefined()
  })

  test("reports a request that never reaches the server", async () => {
    captureFetch(new Error("offline"))
    const { controller } = build("<form></form>")

    expect(await controller.request("/u/dark/characters", "POST", new URLSearchParams())).toBeNull()
  })
})

describe("modal form payload", () => {
  test("drops Rails' own hidden plumbing", () => {
    const { controller } = build(`
      <form>
        <input type="hidden" name="_method" value="patch">
        <input type="hidden" name="authenticity_token" value="secret-token">
        <input type="hidden" name="utf8" value="&#x2713;">
        <input type="submit" name="commit" value="Save">
        <input name="character[name]" value="Lisbeth">
      </form>
    `)

    expect(controller.formPayload(controller.formTarget).toString()).toBe("character%5Bname%5D=Lisbeth")
  })

  test("sends one explicit blank when a multi-select is cleared", () => {
    const restore = stubFormData([ [ "character[name]", "Lisbeth" ] ])
    const { controller } = build(`
      <form>
        <input name="character[name]" value="Lisbeth">
        <select name="character[character_tag_ids][]" multiple></select>
      </form>
    `)

    const payload = controller.formPayload(controller.formTarget)

    expect(payload.getAll("character[character_tag_ids][]")).toEqual([ "" ])
    restore()
  })

  test("does not double the array suffix of a cleared multi-select", () => {
    const restore = stubFormData([])
    const { controller } = build(`
      <form>
        <select name="character[character_tag_ids][]" multiple></select>
      </form>
    `)

    const payload = controller.formPayload(controller.formTarget)

    expect([ ...payload.keys() ]).toEqual([ "character[character_tag_ids][]" ])
    restore()
  })

  test("leaves a populated multi-select alone", () => {
    const restore = stubFormData([
      [ "character[character_tag_ids][]", "1" ],
      [ "character[character_tag_ids][]", "2" ]
    ])
    const { controller } = build(`
      <form>
        <select name="character[character_tag_ids][]" multiple>
          <option value="1" selected>one</option>
          <option value="2" selected>two</option>
        </select>
      </form>
    `)

    const payload = controller.formPayload(controller.formTarget)

    expect(payload.getAll("character[character_tag_ids][]")).toEqual([ "1", "2" ])
    restore()
  })
})

describe("modal form verb", () => {
  test("uses the form's _method override", () => {
    const { controller } = build('<form method="post"><input type="hidden" name="_method" value="patch"></form>')

    expect(controller.httpMethod()).toBe("PATCH")
  })

  test("falls back to the form's own method", () => {
    const { controller } = build('<form method="post"></form>')
    expect(controller.httpMethod()).toBe("POST")

    const other = build('<form method="delete"></form>')
    expect(other.controller.httpMethod()).toBe("DELETE")
  })

  test("adds a _method field for a non-POST verb and removes it again", () => {
    const { controller, form } = build('<form method="post"></form>')

    controller.setMethod("delete")
    expect(form.method).toBe("post")
    expect(form.querySelector("input[name='_method']").value).toBe("delete")

    controller.setMethod("post")
    expect(form.querySelector("input[name='_method']")).toBeNull()
    expect(form.method).toBe("post")
  })
})

describe("modal form error rendering", () => {
  const formHtml = `
    <form>
      <div class="mb-3">
        <label for="character_name">Name *</label>
        <input id="character_name" name="character[name]">
      </div>
      <div class="mb-3">
        <label for="character_parent_id">Parent</label>
        <select id="character_parent_id" name="character[parent_id]"></select>
      </div>
      <div class="mb-3">
        <select id="character_character_tag_ids" name="character[character_tag_ids][]" multiple></select>
        <input type="hidden" name="character[character_tag_ids]" value="">
      </div>
    </form>
  `

  test("reads the error hash from a 422 body", () => {
    const { controller } = build(formHtml)

    const entries = controller.errorEntries({ errors: { name: [ " can't be blank" ], base: "must belong to a universe" } })

    expect(entries).toEqual([
      [ "name", [ "Name can't be blank" ] ],
      [ "base", [ "the character must belong to a universe" ] ]
    ])
  })

  test("accepts a bare error hash and drops unusable messages", () => {
    const { controller } = build(formHtml)

    const entries = controller.errorEntries({ name: [ "  is invalid  ", "", null, 3 ], color: [] })

    expect(entries).toEqual([ [ "name", [ "Name is invalid" ] ] ])
  })

  test("a body that carries no usable error hash explains nothing", () => {
    const { controller } = build(formHtml)

    expect(controller.errorEntries(null)).toEqual([])
    expect(controller.errorEntries("<!DOCTYPE html>")).toEqual([])
    expect(controller.errorEntries({ errors: "boom" })).toEqual([])
    expect(controller.errorEntries([ "boom" ])).toEqual([])
  })

  test("resolves an association error to its foreign-key field", () => {
    const { controller } = build(formHtml)

    expect(controller.fieldFor("parent")).toBe(controller.formTarget.querySelector("#character_parent_id"))
    expect(controller.fieldFor("name")).toBe(controller.formTarget.querySelector("#character_name"))
    expect(controller.fieldFor("character_tag_ids")).toBe(controller.formTarget.querySelector("#character_character_tag_ids"))
    expect(controller.fieldFor("base")).toBeNull()
  })

  test("prefers the visible control over Rails' hidden companion field", () => {
    const { controller } = build(formHtml)

    expect(controller.namedControl("character[character_tag_ids]")).toBe(controller.formTarget.querySelector("#character_character_tag_ids"))
  })

  test("marks the offending control and clears it again", () => {
    const { controller, form } = build(formHtml)
    const field = form.querySelector("#character_name")

    controller.markInvalid("name", [ "can't be blank" ])

    const error = form.querySelector("[data-modal-form-error-for='name']")
    expect(error.textContent).toBe("can't be blank")
    expect(error.className).toContain("invalid-feedback")
    expect(field.getAttribute("aria-invalid")).toBe("true")
    expect(field.getAttribute("aria-describedby")).toContain(error.id)

    controller.clearErrors()

    expect(form.querySelector("[data-modal-form-error-for]")).toBeNull()
    expect(field.hasAttribute("aria-invalid")).toBe(false)
    expect(field.hasAttribute("aria-describedby")).toBe(false)
  })

  test("keeps an unrelated description when the error is cleared", () => {
    const { controller, form } = build(formHtml)
    const field = form.querySelector("#character_name")
    field.setAttribute("aria-describedby", "character_name_hint")

    controller.markInvalid("name", [ "can't be blank" ])
    controller.clearErrors()

    expect(field.getAttribute("aria-describedby")).toBe("character_name_hint")
  })

  test("focuses a summary that lists every message", () => {
    const { controller, host } = build(formHtml)

    controller.showSummary([
      [ "name", [ "can't be blank" ] ],
      [ "base", [ "the character must belong to a universe" ] ]
    ], "The change could not be saved. Fix the following and try again.")

    const summary = host.querySelector("[data-modal-form-target='errors']")
    expect(summary.hidden).toBe(false)
    expect(summary.querySelectorAll("li")).toHaveLength(2)
    expect(summary.querySelector("p").textContent).toBe("The change could not be saved. Fix the following and try again.")
    expect(document.activeElement).toBe(summary)
  })

  test("a record-level message is phrased for the model being edited", () => {
    const { controller } = build(formHtml)

    expect(controller.describe("name", "can't be blank")).toBe("Name can't be blank")
    expect(controller.describe("base", "must belong to a universe")).toBe("the character must belong to a universe")
    expect(controller.describe("base", "The universe is closed.")).toBe("The universe is closed.")
  })

  test("an unknown field keeps its attribute name as the label", () => {
    const { controller } = build(formHtml)

    expect(controller.labelFor("nickname")).toBe("nickname")
  })

  test("a page without an error region still reports the rejection", async () => {
    const { controller, host } = build(formHtml, { withSummary: false })
    captureFetch(new Response(JSON.stringify({ errors: { name: [ "can't be blank" ] } }), { status: 422 }))

    await controller.renderErrors({ errors: { name: [ "can't be blank" ] } })

    expect(host.querySelector("[data-mutation-status]").textContent).toBe("Name can't be blank")
  })

  test("a 422 that explains nothing says so instead of claiming success", async () => {
    const { controller, host } = build(formHtml)

    await controller.renderErrors(null)

    expect(host.querySelector("[data-mutation-status]").textContent).toContain("did not explain why")
  })
})

describe("modal form status reporting", () => {
  test("each failure status gets its own message", () => {
    const { controller } = build("<form></form>")
    const fallback = "The change could not be saved."

    expect(controller.statusMessage({ status: 403 }, fallback)).toContain("no longer allowed")
    expect(controller.statusMessage({ status: 422 }, fallback)).toContain("rejected the value")
    expect(controller.statusMessage({ status: 500 }, fallback)).toContain("Nothing was changed")
    expect(controller.statusMessage({ status: 406 }, fallback)).toBe(`${fallback} (HTTP 406)`)
  })

  test("a failed delete reports itself on the page, outside any modal", () => {
    const { controller, host } = build("<form></form>", { withSummary: false })
    const region = host.querySelector("[data-mutation-status]")

    controller.fail("The record could not be deleted: the request could not be sent.")

    expect(region.hidden).toBe(false)
    expect(region.classList.contains("visually-hidden")).toBe(false)
    expect(region.querySelector("[role='alert']").textContent).toContain("could not be deleted")
  })

  test("the page status is cleared when the next editor opens", () => {
    const { controller, host } = build("<form></form>", { withSummary: false })
    const region = host.querySelector("[data-mutation-status]")

    controller.pageStatus("Saving…")
    expect(region.textContent).toBe("Saving…")

    controller.pageStatus(null)
    expect(region.hidden).toBe(true)
    expect(region.textContent).toBe("")
  })

  test("the submit button is pending only while the request is in flight", () => {
    const { controller } = build(`
      <form>
        <button data-modal-form-target="submit" type="submit">Save</button>
      </form>
    `)
    const submit = controller.formTarget.querySelector("button")

    controller.setPending(true)
    expect(submit.disabled).toBe(true)
    expect(controller.formTarget.getAttribute("aria-busy")).toBe("true")
    expect(submit.querySelector(".spinner-border")).not.toBeNull()

    controller.setPending(false)
    expect(submit.disabled).toBe(false)
    expect(controller.formTarget.getAttribute("aria-busy")).toBe("false")
    expect(submit.querySelector(".spinner-border")).toBeNull()
  })

  test("the model name reads as words", () => {
    const { controller } = build("<form></form>")

    expect(controller.recordName()).toBe("character")
    controller.modelParamValue = "scene_element"
    expect(controller.recordName()).toBe("scene element")
  })

  test("the JSON mutation mode is the one the page declares", () => {
    const { controller } = build("<form></form>")

    expect(controller.jsonResponse).toBe(true)
    controller.responseValue = "html"
    expect(controller.jsonResponse).toBe(false)
  })

  test("a malformed value falls back instead of throwing", () => {
    const { controller } = build("<form></form>")

    expect(controller.parseJson("{oops", { fallback: true })).toEqual({ fallback: true })
    expect(controller.parseJson(undefined, null)).toBeNull()
  })
})

describe("modal form move", () => {
  function moveButton(direction, url = "/u/dark/s/1/scenes/2/elements/3/move?direction=down", disabled = false) {
    const host = document.createElement("div")
    host.innerHTML = `
      <div data-mutation-status hidden class="visually-hidden"></div>
      <div class="dropdown"><button class="btn dropdown-toggle" data-bs-toggle="dropdown" type="button"></button></div>
      <button type="button" data-modal-form-direction="${direction}" data-modal-form-url="${url}" ${disabled ? "disabled" : ""}></button>
    `
    document.body.append(host)
    return host.querySelector("button[data-modal-form-direction]")
  }

  test("sends the move as a PATCH with the page's token and then refreshes", async () => {
    const meta = csrfMeta("token-from-meta")
    const calls = captureFetch(new Response("{}", { status: 200 }))
    let refreshed = 0
    globalThis.Turbo = { visit: () => { refreshed += 1 } }
    const { controller, host } = build("<form></form>")
    const trigger = moveButton("down")
    controller.closeMenu = () => {}
    controller.modalTarget = host.querySelector(".dropdown")

    await controller.move({ preventDefault() {}, currentTarget: trigger })

    expect(calls).toHaveLength(1)
    expect(calls[0].options.method).toBe("PATCH")
    expect(calls[0].options.headers["X-CSRF-Token"]).toBe("token-from-meta")
    expect(calls[0].url).toContain("/elements/3/move?direction=down")
    expect(refreshed).toBe(1)
    delete globalThis.Turbo
    meta.remove()
  })

  test("a disabled control is not a move the controller performs", async () => {
    const calls = captureFetch()
    const { controller } = build("<form></form>")
    const trigger = moveButton("up", undefined, true)
    controller.closeMenu = () => {}

    await controller.move({ preventDefault() {}, currentTarget: trigger })

    expect(calls).toHaveLength(0)
  })

  test("a rejected move reports the server's own message, not a generic one", async () => {
    captureFetch(new Response(JSON.stringify({ errors: { character_ids: [ "is required for a dialogue element" ] } }), { status: 422 }))
    const { controller, host } = build("<form></form>", { withSummary: false })
    const trigger = moveButton("down")
    controller.closeMenu = () => {}
    controller.modalTarget = host.querySelector(".dropdown")

    await controller.move({ preventDefault() {}, currentTarget: trigger })

    const region = host.querySelector("[data-mutation-status]")
    expect(region.hidden).toBe(false)
    expect(region.textContent).toContain("is required for a dialogue element")
    // The row stays where it is, and the control comes back so the author can
    // try again.
    expect(trigger.disabled).toBe(false)
  })

  test("a move that never reached the server says so and re-enables the control", async () => {
    captureFetch(new Error("offline"))
    const { controller, host } = build("<form></form>", { withSummary: false })
    const trigger = moveButton("down")
    controller.closeMenu = () => {}
    controller.modalTarget = host.querySelector(".dropdown")

    await controller.move({ preventDefault() {}, currentTarget: trigger })

    expect(host.querySelector("[data-mutation-status]").textContent).toContain("could not be sent")
    expect(trigger.disabled).toBe(false)
  })

  test("a row that is already gone refreshes instead of reporting a failure", async () => {
    captureFetch(new Response("{}", { status: 404 }))
    let refreshed = 0
    globalThis.Turbo = { visit: () => { refreshed += 1 } }
    const { controller, host } = build("<form></form>", { withSummary: false })
    const trigger = moveButton("down")
    controller.closeMenu = () => {}
    controller.modalTarget = host.querySelector(".dropdown")

    await controller.move({ preventDefault() {}, currentTarget: trigger })

    expect(refreshed).toBe(1)
    expect(host.querySelector("[data-mutation-status]").textContent).toContain("no longer exists")
    delete globalThis.Turbo
  })
})

describe("modal form open", () => {
  test("fills a multi-select through Tom Select when the editor has one", () => {
    const { controller, form } = build(`
      <form>
        <input id="character_name" name="character[name]">
        <select id="character_character_tag_ids" name="character[character_tag_ids][]" multiple>
          <option value="1">one</option>
          <option value="2">two</option>
        </select>
      </form>
    `)
    const select = form.querySelector("select")
    const cleared = []
    select.tomselect = {
      clear: (silent) => cleared.push(silent),
      setValue: (values) => { select.dataset.selected = values.join(",") }
    }
    controller.createTitleValue = "Add character"
    controller.titleTarget = document.createElement("h5")
    controller.modal = { show: () => { controller.modalShown = true } }

    controller.open({
      preventDefault() {},
      currentTarget: {
        dataset: {
          modalFormTitle: "Edit character",
          modalFormUrl: "/u/dark/characters/1",
          modalFormMethod: "patch",
          modalFormValuesValue: JSON.stringify({ name: "Lisbeth", character_tag_ids: [ "2" ] })
        }
      }
    })

    expect(controller.titleTarget.textContent).toBe("Edit character")
    expect(form.action).toContain("/u/dark/characters/1")
    expect(form.querySelector("input[name='_method']").value).toBe("patch")
    expect(cleared).toEqual([ true ])
    expect(select.dataset.selected).toBe("2")
    expect(form.querySelector("#character_name").value).toBe("Lisbeth")
    expect(controller.modalShown).toBe(true)
  })
})

// Bootstrap's own dialog is not what these cases are about, and happy-dom has no
// transition: the stub is the instance contract the controller uses, so what is
// exercised is the controller's own deferral and not a fade.
function stubBootstrapModal() {
  const hidden = []
  class FakeModal {
    show() {}
    hide() { hidden.push(true) }
  }
  globalThis.window.bootstrap = { Modal: FakeModal }
  return hidden
}

function openEditor(controller, dataset = {}) {
  controller.titleTarget = document.createElement("h5")
  controller.open({
    preventDefault() {},
    currentTarget: {
      dataset: {
        modalFormTitle: "Edit character",
        modalFormUrl: "/u/dark/characters/1",
        modalFormMethod: "patch",
        modalFormValuesValue: "{}",
        ...dataset
      }
    }
  })
}

function finishedOpening(controller) {
  controller.modalTarget.dispatchEvent(new Event("shown.bs.modal"))
}

// A dismiss that lands while the dialog is still fading in used to be dropped
// without a word: Bootstrap's `hide()` returns while the instance is transitioning
// in, and the `btn-close` button, the footer's **Cancel**, Escape, and a backdrop
// click all resolve to that one instance. It reaches every modal workspace and it
// is invisible to a pointer user who waits a fraction of a second, but it takes
// the first Escape a keyboard user presses away with nothing at all.
describe("modal form dismiss", () => {
  function connectedEditor() {
    const built = build('<div class="modal fade" data-modal-form-target="modal"><form data-modal-form-target="form"></form></div>')
    built.hidden = stubBootstrapModal()
    built.controller.connect()
    return built
  }

  test("a dismiss that lands while the dialog is opening is honoured once it has opened", () => {
    const { controller, hidden } = connectedEditor()

    openEditor(controller)
    controller.modal.hide()
    expect(hidden).toHaveLength(0)

    finishedOpening(controller)
    expect(hidden).toHaveLength(1)
  })

  test("a dismiss after the dialog has opened closes it at once", () => {
    const { controller, hidden } = connectedEditor()

    openEditor(controller)
    finishedOpening(controller)
    controller.modal.hide()

    expect(hidden).toHaveLength(1)
  })

  test("the open that replaces the row supersedes a dismiss it never delivered", () => {
    const { controller, hidden } = connectedEditor()

    openEditor(controller)
    controller.modal.hide()
    openEditor(controller, { modalFormUrl: "/u/dark/characters/2" })
    finishedOpening(controller)

    expect(hidden).toHaveLength(0)
  })

  test("an open that does not show the dialog again leaves it dismissable", () => {
    const { controller, hidden } = connectedEditor()

    openEditor(controller)
    finishedOpening(controller)
    // Bootstrap's `show()` returns without doing anything while the dialog is
    // already open, so no `shown.bs.modal` follows this open. A dismiss deferred
    // into a window that can never close would leave the dialog undismissable.
    openEditor(controller)
    controller.modal.hide()

    expect(hidden).toHaveLength(1)
  })

  test("a dismissal lets the next open defer its own dismiss again", () => {
    const { controller, hidden } = connectedEditor()

    openEditor(controller)
    finishedOpening(controller)
    controller.modal.hide()
    controller.modalTarget.dispatchEvent(new Event("hidden.bs.modal"))

    // The second open is the row after the dismissed one, and it is dismissed the
    // same way. A dialog that is still on the page is not shown again, so the
    // controller has to know this one is gone before it opens the window again.
    openEditor(controller, { modalFormUrl: "/u/dark/characters/2" })
    controller.modal.hide()
    expect(hidden).toHaveLength(1)

    finishedOpening(controller)
    expect(hidden).toHaveLength(2)
  })

  test("a deferred dismiss gives nothing inside the closing dialog focus", () => {
    const { controller, hidden } = connectedEditor()
    let focused = 0
    controller.focusFirstField = () => { focused += 1 }

    openEditor(controller)
    controller.modal.hide()
    finishedOpening(controller)

    expect(hidden).toHaveLength(1)
    expect(focused).toBe(0)
  })
})

// The Event editor's three temporal selects are the one place a record must not
// be offered as one of its own references. The server cannot do it — one modal
// form serves every row — so the control declares it and the row's id travels on
// the trigger. The server-rendered list is kept so the next row gets its own
// option back; that restoration is the whole correctness risk here.
describe("modal form self-reference exclusion", () => {
  const formHtml = `
    <form>
      <select id="event_before_event_id" name="event[before_event_id]" data-modal-form-exclude-self="true">
        <option value="">None</option>
        <option value="1">The beginning</option>
        <option value="2">The end</option>
      </select>
      <select id="event_start_datetime" name="event[start_datetime]">
        <option value="">None</option>
        <option value="1">The beginning</option>
      </select>
    </form>
  `

  function openEditor(controller, dataset = {}) {
    controller.titleTarget = document.createElement("h5")
    controller.modal = { show: () => {} }

    controller.open({
      preventDefault() {},
      currentTarget: {
        dataset: {
          modalFormTitle: "Edit event",
          modalFormUrl: "/u/dark/events/1",
          modalFormMethod: "patch",
          modalFormValuesValue: "{}",
          ...dataset
        }
      }
    })
  }

  function optionValues(form, id) {
    return [ ...form.querySelector(`#${id}`).options ].map((option) => option.value)
  }

  test("drops the edited record's own option and keeps every other one", () => {
    const { controller, form } = build(formHtml)

    openEditor(controller, { modalFormRecordId: "1" })

    // The blank "None" option is never the record, so it survives.
    expect(optionValues(form, "event_before_event_id")).toEqual([ "", "2" ])
    // Rebuilding the list instead of detaching one option loses which option is
    // selected, and a create then submits a temporal reference nobody chose.
    expect(form.querySelector("#event_before_event_id").value).toBe("")
  })

  test("leaves a select that does not declare the exclusion alone", () => {
    const { controller, form } = build(formHtml)

    openEditor(controller, { modalFormRecordId: "1" })

    expect(optionValues(form, "event_start_datetime")).toEqual([ "", "1" ])
  })

  test("restores the removed option when another row opens the same form", () => {
    const { controller, form } = build(formHtml)

    openEditor(controller, { modalFormRecordId: "1" })
    openEditor(controller, { modalFormUrl: "/u/dark/events/2", modalFormRecordId: "2" })

    expect(optionValues(form, "event_before_event_id")).toEqual([ "", "1" ])
  })

  test("a create trigger offers every option, because there is no record yet", () => {
    const { controller, form } = build(formHtml)

    openEditor(controller, { modalFormUrl: "/u/dark/events", modalFormMethod: "post" })

    expect(optionValues(form, "event_before_event_id")).toEqual([ "", "1", "2" ])
  })

  test("a create trigger after an edit restores the option the edit removed", () => {
    const { controller, form } = build(formHtml)

    openEditor(controller, { modalFormRecordId: "1" })
    openEditor(controller, { modalFormUrl: "/u/dark/events", modalFormMethod: "post" })

    expect(optionValues(form, "event_before_event_id")).toEqual([ "", "1", "2" ])
  })
})
