import { Controller } from "@hotwired/stimulus"
import "bootstrap"

// Rails' own form plumbing is not part of a model payload, and `_method` is
// translated into the real HTTP verb by this controller.
const NON_PAYLOAD_FIELDS = new Set([ "_method", "authenticity_token", "utf8", "commit" ])
const JSON_RESPONSE = "json"

export default class extends Controller {
  static targets = [ "modal", "title", "form", "submit", "errors" ]
  static values = { createTitle: String, modelParam: String, response: String }

  connect() {
    this.modal = new window.bootstrap.Modal(this.modalTarget)
    this.shown = false
    this.handleShown = () => {
      this.shown = true
      // Bootstrap activates its own focus trap on this event, which focuses the
      // dialog itself. A save rejected while the modal was still opening would
      // lose the summary's focus to it, so the focus is claimed back here.
      if (this.focusSummaryOnShow) {
        this.focusSummaryOnShow = false
        this.errorsTarget?.focus()
        return
      }
      // Otherwise a save rejected during the opening transition keeps its summary
      // focused, instead of the first-field focus of a modal that has only just
      // become visible stealing it back.
      if (this.hasErrorsTarget && !this.errorsTarget.hidden) return
      this.focusFirstField()
    }
    this.modalTarget.addEventListener("shown.bs.modal", this.handleShown)
  }

  disconnect() {
    this.modalTarget?.removeEventListener("shown.bs.modal", this.handleShown)
    this.modal?.dispose()
    this.modal = null
  }

  // A page declares its own mutation contract. "json" means the controller
  // submits the form itself and expects a JSON result; anything else (the HTML
  // redirect/re-render flow used by relations and ownerships) keeps the browser's
  // own submission. The mode is declared explicitly in every modal view and
  // asserted in the controller tests, so a page cannot silently drift back to
  // submitting HTML to a JSON-only endpoint.
  get jsonResponse() {
    return this.responseValue === JSON_RESPONSE
  }

  open(event) {
    event.preventDefault()
    const trigger = event.currentTarget
    const values = this.parseJson(trigger.dataset.modalFormValuesValue, {})

    this.titleTarget.textContent = trigger.dataset.modalFormTitle || this.createTitleValue
    this.formTarget.action = trigger.dataset.modalFormUrl
    this.setMethod(trigger.dataset.modalFormMethod || "post")
    this.formTarget.reset()
    this.clearErrors()
    this.setPending(false)
    this.pageStatus(null)
    this.shown = false
    this.focusSummaryOnShow = false
    this.formTarget.querySelectorAll("select[multiple]").forEach((select) => select.tomselect?.clear(true))

    Object.entries(values).forEach(([name, value]) => {
      const field = this.namedControl(`${this.modelParamValue}[${name}]`)
      if (!field) return

      if (Array.isArray(value) && field.multiple) {
        const selected = value.map(String)
        if (field.tomselect) field.tomselect.setValue(selected, true)
        else Array.from(field.options).forEach((option) => { option.selected = selected.includes(option.value) })
      } else {
        field.value = value
      }
    })

    this.modal.show()
  }

  // The JSON mutation path. Everything below it is the reliability contract:
  // the form is never left pending, a rejected save keeps its input and explains
  // itself, and a successful save refreshes the list so rows and counts come
  // from one server render.
  async save(event) {
    if (!this.jsonResponse) return
    event.preventDefault()
    if (!this.formTarget.reportValidity()) return

    this.clearErrors()
    this.setPending(true)
    this.pageStatus("Saving…")

    const response = await this.request(this.formTarget.action, this.httpMethod(), this.formPayload(this.formTarget))
    if (!response) {
      this.fail("The change could not be sent. Check your connection and try again.")
      return
    }

    if (response.ok) {
      this.pageStatus("Saved. Refreshing the list…")
      this.refresh()
      return
    }

    if (response.status === 422) {
      this.renderErrors(await this.readBody(response))
      return
    }

    this.fail(this.statusMessage(response, "The change could not be saved."))
  }

  // A JSON-only destroy has no Turbo form to follow, so the row menu issues the
  // request itself and the list is refreshed from the server afterwards. A
  // rejected delete leaves the row alone and says why.
  async destroy(event) {
    if (!this.jsonResponse) return
    event.preventDefault()
    const trigger = event.currentTarget
    const message = trigger.dataset.modalFormConfirm?.trim()
    if (message && !window.confirm(message)) return

    this.closeMenu(trigger)
    trigger.disabled = true
    this.pageStatus("Deleting…")
    const response = await this.request(trigger.dataset.modalFormUrl, "DELETE", new URLSearchParams())
    if (!response) {
      trigger.disabled = false
      this.pageStatus("The record could not be deleted: the request could not be sent. Check your connection and try again.", true)
      return
    }

    if (response.status === 404) {
      this.pageStatus("That record no longer exists. Refreshing the list…")
      this.refresh()
      return
    }

    if (!response.ok) {
      trigger.disabled = false
      this.pageStatus(this.statusMessage(response, "The record could not be deleted."), true)
      return
    }

    this.pageStatus("Deleted. Refreshing the list…")
    this.refresh()
  }

  setMethod(method) {
    let methodField = this.formTarget.querySelector("input[name='_method']")
    if (method.toLowerCase() === "post") {
      methodField?.remove()
      this.formTarget.method = "post"
      return
    }

    if (!methodField) {
      methodField = document.createElement("input")
      methodField.type = "hidden"
      methodField.name = "_method"
      this.formTarget.append(methodField)
    }
    methodField.value = method
    this.formTarget.method = "post"
  }

  httpMethod() {
    const override = this.formTarget.querySelector("input[name='_method']")?.value
    return (override || this.formTarget.method || "post").toUpperCase()
  }

  // The form's own field names are already the scoped parameters the server
  // expects, so they are forwarded verbatim. Two corrections are made on the way:
  // Rails' own hidden plumbing is dropped, and an empty multi-select sends one
  // explicit blank value so clearing the last tag really clears the assignment
  // instead of leaving the stored ids untouched.
  formPayload(form) {
    const params = new URLSearchParams()
    new FormData(form).forEach((value, key) => {
      if (NON_PAYLOAD_FIELDS.has(key)) return
      params.append(key, value)
    })

    form.querySelectorAll("select[multiple]").forEach((select) => {
      if (select.selectedOptions.length > 0) return
      const name = select.name.endsWith("[]") ? select.name : `${select.name}[]`
      params.append(name, "")
    })

    return params
  }

  async request(url, method, params) {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const headers = {
      "Accept": "application/json",
      "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8"
    }
    if (token) headers["X-CSRF-Token"] = token

    try {
      return await window.fetch(url, { method, headers, body: params })
    } catch (_error) {
      return null
    }
  }

  async readBody(response) {
    try {
      return await response.json()
    } catch (_error) {
      return null
    }
  }

  // A 422 carries the model's error hash, keyed by attribute. A record-level
  // ("base") message and an association-scoped message with no matching field
  // both belong in the summary rather than next to an input.
  async renderErrors(payload) {
    this.setPending(false)
    const entries = this.errorEntries(payload)
    if (entries.length === 0) {
      this.fail("The server rejected the change but did not explain why. Nothing was saved.")
      return
    }

    // A modal page that forgot the error region must still report the rejection
    // rather than swallow it; the shared contract test fails the build in that
    // case, and the page-level region carries the message in the meantime.
    if (!this.hasErrorsTarget) {
      this.pageStatus(entries.map(([ , messages ]) => messages.join(" ")).join(" "), true)
      return
    }

    entries.forEach(([attribute, messages]) => this.markInvalid(attribute, messages))
    this.showSummary(entries, "The change could not be saved. Fix the following and try again.")
  }

  errorEntries(payload) {
    const body = payload && typeof payload === "object" ? payload : null
    const errors = body?.errors && typeof body.errors === "object" ? body.errors : body
    if (!errors || typeof errors !== "object") return []

    return Object.entries(errors).map(([attribute, value]) => [ attribute, this.errorMessages(attribute, value) ]).filter(([ , messages ]) => messages.length > 0)
  }

  errorMessages(attribute, value) {
    const raw = Array.isArray(value) ? value : [ value ]
    return raw
      .map((message) => (typeof message === "string" ? message.trim() : ""))
      .filter((message) => message.length > 0)
      .map((message) => this.describe(attribute, message))
  }

  // "can't be blank" on :name reads as "Name can't be blank", and a record-level
  // message reads as "the event must have a title…". A message that does not start
  // with a verb is rendered as the server wrote it.
  describe(attribute, message) {
    if (attribute !== "base") return `${this.labelFor(attribute)} ${message}`
    return /^[a-z]/.test(message) ? `the ${this.recordName()} ${message}` : message
  }

  labelFor(attribute) {
    const field = this.fieldFor(attribute)
    const label = field?.id ? [ ...this.formTarget.querySelectorAll("label[for]") ].find((element) => element.htmlFor === field.id) : null
    return (label?.textContent || attribute).replace(/\s*\*\s*$/, "").trim()
  }

  // An error is keyed by the model attribute, while an association's form field
  // is its foreign key. Both spellings are tried so a `belongs_to` rejection
  // ("cannot be itself" on :before_event) is shown next to the `before_event_id`
  // select that caused it, and an association-scope rejection with no field at
  // all stays in the summary.
  fieldFor(attribute) {
    if (attribute === "base") return null
    for (const candidate of [ attribute, `${attribute}_id`, `${attribute}_ids` ]) {
      const field = this.namedControl(`${this.modelParamValue}[${candidate}]`)
      if (field) return field
    }
    return null
  }

  // A multi-select is rendered with Rails' own hidden companion field, which
  // carries the same name as the select, and the select's own name carries the
  // `[]` array suffix. Both spellings are tried and the visible control always
  // wins over the hidden companion.
  namedControl(name) {
    for (const candidate of [ name, `${name}[]` ]) {
      const field = [ ...this.formTarget.querySelectorAll(`[name='${candidate}']`) ].find((element) => element.type !== "hidden")
      if (field) return field
    }
    return null
  }

  markInvalid(attribute, messages) {
    const field = this.fieldFor(attribute)
    if (!field) return

    this.formTarget.querySelector(`[data-modal-form-error-for='${attribute}']`)?.remove()

    const error = document.createElement("p")
    error.className = "invalid-feedback d-block mb-0"
    error.id = `${field.id || `${this.modelParamValue}-${attribute}`}-error`
    error.dataset.modalFormErrorFor = attribute
    error.textContent = messages.join(" ")

    this.errorHost(field).append(error)
    field.setAttribute("aria-invalid", "true")
    const described = new Set([ ...(field.getAttribute("aria-describedby") || "").split(" ").filter(Boolean), error.id ])
    field.setAttribute("aria-describedby", [ ...described ].join(" "))
    field.dataset.modalFormErrorIds = (field.dataset.modalFormErrorIds || "")
      .split(" ").filter(Boolean).concat(error.id).join(" ")
  }

  errorHost(field) {
    return field.closest(".mb-3, .row, .col-md-6, .col-md-4") || field.parentElement || this.formTarget
  }

  clearErrors() {
    this.formTarget.querySelectorAll("[data-modal-form-error-for]").forEach((element) => element.remove())
    this.formTarget.querySelectorAll("[data-modal-form-error-ids]").forEach((field) => {
      const errorIds = field.dataset.modalFormErrorIds.split(" ").filter(Boolean)
      const described = (field.getAttribute("aria-describedby") || "").split(" ").filter((id) => id && !errorIds.includes(id))
      if (described.length > 0) field.setAttribute("aria-describedby", described.join(" "))
      else field.removeAttribute("aria-describedby")
      field.removeAttribute("aria-invalid")
      delete field.dataset.modalFormErrorIds
    })
  }

  showSummary(entries, heading) {
    if (!this.hasErrorsTarget) return
    const list = document.createElement("ul")
    list.className = "mb-0 ps-3"
    entries.forEach(([ , messages ]) => {
      const item = document.createElement("li")
      item.textContent = messages.join(" ")
      list.append(item)
    })

    this.errorsTarget.replaceChildren(this.buildAlert([ heading ], list))
    this.errorsTarget.hidden = false
    this.focusSummary()
  }

  // Disabling a focused submit button makes the browser move focus off it in a
  // later task, and the modal's own focus guard then pulls focus back to the
  // dialog. Focus is therefore applied again on the next macrotask, and again
  // when the modal finishes opening, so the reason a save was refused is the
  // thing the author is really left on. Repeating a focus call that already held
  // is a no-op.
  focusSummary() {
    if (!this.hasErrorsTarget) return
    this.errorsTarget.focus()
    setTimeout(() => this.errorsTarget.focus(), 0)
    if (!this.shown) this.focusSummaryOnShow = true
  }

  fail(message) {
    this.setPending(false)
    if (this.hasErrorsTarget && this.modalTarget?.classList.contains("show")) {
      this.showSummary([ [ "base", [ message ] ] ], "")
      return
    }
    this.pageStatus(message, true)
  }

  setPending(pending) {
    this.formTarget.setAttribute("aria-busy", pending ? "true" : "false")
    this.submitTargets.forEach((button) => {
      // A disabled control cannot keep focus, and the browser's fallback lands on
      // the document, which the modal's focus guard then corrects. Letting go of
      // the button explicitly keeps that churn out of the focus path.
      if (pending && document.activeElement === button) button.blur()
      button.disabled = pending
      const spinner = button.querySelector(".spinner-border")
      if (pending && !spinner) {
        const indicator = document.createElement("span")
        indicator.className = "spinner-border spinner-border-sm me-1"
        indicator.setAttribute("aria-hidden", "true")
        button.prepend(indicator)
      }
      spinner?.remove()
    })
  }

  buildAlert(paragraphs, list) {
    const alert = document.createElement("div")
    alert.className = "alert alert-danger mb-0"
    alert.setAttribute("role", "alert")
    paragraphs.filter((text) => text).forEach((text) => {
      const paragraph = document.createElement("p")
      paragraph.className = "mb-1"
      paragraph.textContent = text
      alert.append(paragraph)
    })
    if (list) alert.append(list)
    return alert
  }

  // The page-level live region sits outside every modal, so a failed delete or a
  // failed request that never reached a form still reports itself. A message
  // replaces the previous one instead of stacking, and the refreshed page starts
  // empty again.
  pageStatus(message, error = false) {
    const region = document.querySelector("[data-mutation-status]")
    if (!region) return
    if (message === null || message === undefined) {
      region.replaceChildren()
      region.hidden = true
      region.classList.add("visually-hidden")
      return
    }

    region.hidden = false
    region.classList.toggle("visually-hidden", !error)
    if (error) {
      region.replaceChildren(this.buildAlert([ message ]))
      region.focus()
    } else {
      region.textContent = message
    }
  }

  statusMessage(response, fallback) {
    if (response.status === 403) return `${fallback} You are no longer allowed to do that; reload the page and sign in again.`
    if (response.status === 422) return `${fallback} The server rejected the value.`
    if (response.status >= 500) return "The server could not complete the request. Nothing was changed; try again."
    return `${fallback} (HTTP ${response.status})`
  }

  closeMenu(trigger) {
    const toggle = trigger.closest(".dropdown")?.querySelector("[data-bs-toggle='dropdown']")
    if (!toggle) return
    window.bootstrap.Dropdown.getOrCreateInstance(toggle).hide()
  }

  focusFirstField() {
    const field = this.formTarget.querySelector("input:not([type='hidden']):not([disabled]), select:not([disabled]), textarea:not([disabled])")
    if (!field) return
    field.focus()
    if (field.type === "text") field.select()
  }

  recordName() {
    return this.modelParamValue.replace(/[_-]+/g, " ")
  }

  refresh() {
    if (window.Turbo?.visit) window.Turbo.visit(window.location.href, { action: "replace" })
    else window.location.href = window.location.href
  }

  parseJson(value, fallback) {
    try {
      return JSON.parse(value || "")
    } catch (_error) {
      return fallback
    }
  }
}
