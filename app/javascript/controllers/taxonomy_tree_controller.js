import { Controller } from "@hotwired/stimulus"
import "bootstrap"
import "tom-select"
import { t } from "i18n"

const FOCUS_STORAGE_KEY = "universe-maker:taxonomy-tree-focus"

// The contrast a tag badge's own text must reach against the background the
// author picked for it: WCAG 2.1 AA for body text. A badge is small text, so the
// 3:1 the same level allows for large text is not the bar here.
//
// A pair below it is **warned about, not refused**. A tag color is the
// author's data and the badge shape still names the tag, so a poor pair is a
// legibility review item rather than a rejected save — the editor says so while
// the author is choosing, and lets them keep what they picked.
const MINIMUM_TEXT_CONTRAST = 4.5

// WCAG 2.1's own definition of relative luminance and of the ratio between two
// colors, rather than an approximation of it: a warning computed by a different
// formula would disagree with every contrast checker the reader might use to
// check it. `null` for anything that is not `#rrggbb`, which is the format
// `HasColor` validates and the one the browser's own color control produces.
function relativeLuminance(color) {
  const channels = color.match(/[0-9a-f]{2}/gi).map((channel) => parseInt(channel, 16) / 255)
  const [ red, green, blue ] = channels.map((channel) =>
    channel <= 0.03928 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4)

  return 0.2126 * red + 0.7152 * green + 0.0722 * blue
}

function contrastRatio(foreground, background) {
  const hex = /^#[0-9a-f]{6}$/i
  if (!hex.test(foreground) || !hex.test(background)) return null

  const lighter = Math.max(relativeLuminance(foreground), relativeLuminance(background))
  const darker = Math.min(relativeLuminance(foreground), relativeLuminance(background))

  return (lighter + 0.05) / (darker + 0.05)
}

// The taxonomy tree's editing surface.
//
// One controller serves all ten taxonomies and the two non-tag hierarchies, so
// nothing here may name a record type: the tree's own status line says "the
// item", and the noun in a record-level error is `shared.taxonomy_tree.record_subject`
// for the same reason — a tree that edits eight different things cannot say which
// one it is talking about.
//
// Every word the controller shows is read through `t()` from the blob the layout
// rendered. That includes the editor modal, which this controller builds in
// `document.body`, and the inline create and rename rows. The two error frames it
// shares with the flat-list editor are keys for the same reason, so a rejected
// save reads the same whichever editor refused it.
//
// The tree's editor also builds the photo control's container, so it passes that
// control the descriptor's own label rather than a word of its own — the same
// bare container `shared/_photo_field` renders, and the same label.
export default class extends Controller {
  static values = { modelParam: String, createUrl: String, createTitle: String, modalFields: String, fieldName: String, editable: Boolean }

  connect() {
    if (!this.editableValue) return

    this.returnFocusTo = null
    this.refreshing = false
    this.handleTurboRender = this.handleTurboRender.bind(this)
    document.addEventListener("turbo:render", this.handleTurboRender)
    this.updateMoveControls()
    this.restorePendingFocus()
  }

  disconnect() {
    if (this.handleTurboRender) document.removeEventListener("turbo:render", this.handleTurboRender)
  }

  // The page's Add button and a row menu's Add child open the same editor. A
  // row trigger supplies the parent; the page trigger starts at the root. The
  // create appends at the end of that parent's siblings, which is the order the
  // old inline create produced.
  add(event) {
    if (!this.editableValue) return
    event.preventDefault()
    if (this.modal) return

    const parentNode = event.currentTarget.closest("[data-node-id]")
    this.openEditor(null, {
      create: true,
      parentId: parentNode?.dataset.nodeId || "",
      trigger: event.currentTarget
    })
  }

  edit(event) {
    if (!this.editableValue) return
    event.preventDefault()
    const node = event.currentTarget.closest("[data-node-id]")
    if (!node) return
    this.openEditor(node, { create: false, trigger: event.currentTarget })
  }

  openEditor(node, { create, parentId = "", trigger }) {
    if (this.modal) return

    const modal = this.buildModal(node, { create, parentId })
    document.body.append(modal)
    this.modalElement = modal
    this.modalRecord = node
    this.modalCreate = create
    this.returnFocusTo = this.returnFocusTarget(trigger)
    this.refreshing = false
    this.populateModalFields(modal, node, { create, parentId })
    modal.querySelectorAll("select[multiple]").forEach((select) => {
      new window.TomSelect(select, { plugins: [ "remove_button" ], create: false })
    })

    this.modal = new window.bootstrap.Modal(modal)
    this.openingEditor = true
    this.dismissEditorOnShow = false
    this.deferEditorDismissWhileOpening()
    modal.addEventListener("show.bs.modal", () => this.claimFocusTrap())
    modal.addEventListener("hidden.bs.modal", () => {
      modal.querySelectorAll("select[multiple]").forEach((select) => {
        select.tomselect?.destroy()
      })
      modal.remove()
      this.modal = null
      this.modalElement = null
      this.modalRecord = null
      this.modalCreate = null
      this.restoreFocus()
    }, { once: true })
    modal.addEventListener("shown.bs.modal", () => {
      this.openingEditor = false
      // A dismiss that arrived while the editor was still fading in is honoured
      // here, before any focus is claimed: the editor is on its way out, so
      // nothing inside it is given focus on the way.
      if (this.dismissEditorOnShow) {
        this.dismissEditorOnShow = false
        this.modal.hide()
        return
      }
      // Bootstrap activates its own focus trap on this event, which focuses the
      // dialog. A save rejected while the editor was still opening would lose the
      // error summary to it, so the focus is claimed back.
      const region = modal.querySelector("[data-taxonomy-tree-errors]")
      if (region && !region.hidden) region.focus()
    })
    modal.querySelector("form").addEventListener("submit", (submitEvent) => this.submitDetails(submitEvent))
    this.modal.show()
  }

  // Bootstrap's `hide()` returns without doing anything while the instance is
  // still transitioning in, so a dismiss that lands in that window is dropped
  // with nothing at all to show for it. The editor's `btn-close`, its **Cancel**,
  // Escape, and a backdrop click all resolve to the one instance `edit()` builds,
  // so `hide()` itself is wrapped rather than four triggers being intercepted —
  // the same compensation `modal_form_controller.js` makes for the flat-list
  // editor, which has the identical race.
  deferEditorDismissWhileOpening() {
    const hide = this.modal.hide.bind(this.modal)
    this.modal.hide = () => {
      if (!this.openingEditor) {
        hide()
        return
      }
      this.dismissEditorOnShow = true
    }
  }

  // Bootstrap activates its focus trap only when the opening transition ends,
  // and activation focuses the dialog itself. A reader who reaches into the form
  // during that fade — clicking a select, say — would have focus pulled off the
  // control mid-gesture: the native popup closes and can commit whatever option
  // was under the pointer. Activating the trap as the opening starts makes
  // Bootstrap's own activation a no-op, so nothing takes focus from a field the
  // reader has already claimed. `_focustrap` is the instance field Bootstrap's
  // `Modal` keeps its focus trap on; a build without it keeps the old behaviour.
  claimFocusTrap() {
    this.modal?._focustrap?.activate()
  }

  // The editor is built here and shown programmatically, so Bootstrap's data
  // API is not involved and nothing restores focus after the dialog closes. The
  // control that opened the editor is focused again once the editor has gone;
  // a row menu's Edit item resolves to the menu's own toggle because Bootstrap
  // has already closed that menu, and a save's page refresh leaves the control
  // alone rather than competing with the navigation that replaces it.
  returnFocusTarget(trigger) {
    if (typeof trigger?.closest !== "function") return null
    const menu = trigger.closest(".dropdown-menu")
    if (!menu) return trigger
    return menu.closest(".dropdown")?.querySelector("[data-bs-toggle='dropdown']") || trigger
  }

  restoreFocus() {
    const target = this.returnFocusTo
    this.returnFocusTo = null
    if (!target || this.refreshing) return
    if (!target.isConnected || target.disabled) return
    target.focus()
  }

  buildModal(node, { create = false } = {}) {
    const recordId = node?.dataset.nodeId || "new"
    const titleId = `taxonomy-edit-title-${recordId}`
    const modal = document.createElement("div")
    modal.className = "modal fade"
    modal.tabIndex = -1
    modal.setAttribute("aria-labelledby", titleId)
    modal.setAttribute("aria-hidden", "true")

    const dialog = document.createElement("div")
    // The caller names the dialog's own classes, because a tag taxonomy wants
    // the narrow default while a content record's editor opens wide like the
    // flat-list record editors. No class means the narrow default.
    dialog.className = this.element.dataset.modalDialogClass || "modal-dialog"
    const content = document.createElement("div")
    content.className = "modal-content"
    const header = document.createElement("div")
    header.className = "modal-header"
    const title = document.createElement("h2")
    title.className = "modal-title fs-5"
    title.id = titleId
    title.textContent = create
      ? this.createTitleValue
      : t("shared.taxonomy_tree.edit_title", { name: node.dataset.name || "" })
    const close = this.button("", "btn-close", "button", null, t("shared.form.close"))
    close.setAttribute("data-bs-dismiss", "modal")
    header.append(title, close)

    const form = document.createElement("form")
    form.action = create ? this.createUrlValue : node.dataset.updateUrl
    form.method = "post"
    const body = document.createElement("div")
    body.className = "modal-body"
    // One error region for the editor. It is rendered empty and hidden, and the
    // controller fills it from the server's error hash when a save is rejected.
    const errors = document.createElement("div")
    errors.className = "modal-errors mb-3"
    errors.setAttribute("data-taxonomy-tree-errors", "")
    errors.setAttribute("role", "alert")
    errors.tabIndex = -1
    errors.hidden = true
    body.append(errors, this.modalFields(node, { create }))
    const footer = document.createElement("div")
    footer.className = "modal-footer"
    const cancel = this.button(t("shared.form.cancel"), "btn btn-secondary", "button")
    cancel.setAttribute("data-bs-dismiss", "modal")
    footer.append(cancel, this.button(t("shared.taxonomy_tree.save_changes"), "btn btn-primary", "submit"))
    form.append(body, footer)
    content.append(header, form)
    dialog.append(content)
    modal.append(dialog)
    return modal
  }

  modalFields(node, { create }) {
    const fragment = document.createDocumentFragment()
    const excludedParentIds = create
      ? new Set()
      : new Set([ node.dataset.nodeId, ...[ ...node.querySelectorAll("[data-node-id]") ].map((element) => element.dataset.nodeId) ])
    const fields = this.parseJson(this.modalFieldsValue, [])
    // A taxonomy without a background has no pair to judge, and the two
    // non-tag hierarchies this controller also serves have no color at all.
    const colors = fields.filter((field) => field.type === "color").map((field) => field.name)
    const judgesColors = colors.includes("bgcolor") && colors.includes("fgcolor")

    fields.forEach((field) => {
      const id = `taxonomy-edit-${field.name}-${node?.dataset.nodeId || "new"}`
      const name = field.multiple ? `${this.modelParamValue}[${field.name}][]` : `${this.modelParamValue}[${field.name}]`
      const wrapper = document.createElement("div")
      wrapper.className = field.type === "checkbox" ? "mb-3 form-check" : "mb-3"

      if (field.type === "select") {
        const label = this.fieldLabel(field, id)
        const select = document.createElement("select")
        select.className = "form-select"
        select.id = id
        select.name = name
        select.multiple = Boolean(field.multiple)
        select.required = Boolean(field.required)
        const options = field.name === "parent_id" ? (field.options || []).filter(([ value ]) => !excludedParentIds.has(String(value))) : (field.options || [])
        options.forEach(([ value, optionLabel ]) => {
          const option = document.createElement("option")
          option.value = String(value)
          option.textContent = String(optionLabel)
          select.append(option)
        })
        wrapper.append(label, select)
        fragment.append(wrapper)
        return
      }

      if (field.type === "checkbox") {
        const hidden = document.createElement("input")
        hidden.type = "hidden"
        hidden.name = name
        hidden.value = "0"
        const input = document.createElement("input")
        input.className = "form-check-input"
        input.type = "checkbox"
        input.id = id
        input.name = name
        input.value = "1"
        const label = this.fieldLabel(field, id, "form-check-label")
        wrapper.append(hidden, input, label)
        fragment.append(wrapper)
        return
      }

      // The photo editor is a Stimulus controller that builds its own widget, so
      // the taxonomy modal only produces the same bare container the server-side
      // partial produces. There is no second implementation of the control here
      // to drift from the one in `shared/_photo_field`.
      if (field.type === "photo") {
        wrapper.className = "photo-field"
        wrapper.dataset.controller = "photo-crop"
        wrapper.dataset.photoCropFieldValue = `${this.modelParamValue}[photo_data]`
        wrapper.dataset.photoCropRemoveFieldValue = `${this.modelParamValue}[remove_photo]`
        // The stored photo is this node's own value, so the modal shows the row
        // being edited rather than whatever the shared descriptor carries.
        wrapper.dataset.photoCropCurrentUrlValue = this.photoUrlFor(node)
        // The descriptor's own label, which `ModalFields` already resolved for
        // this request. The editor has no word of its own for it, so a taxonomy
        // whose photo field is labelled differently says so here.
        wrapper.dataset.photoCropLabelValue = field.label || t("modal_fields.photo")
        fragment.append(wrapper)
        return
      }

      const label = this.fieldLabel(field, id)
      const input = document.createElement(field.type === "textarea" ? "textarea" : "input")
      input.className = field.type === "color" ? "form-control form-control-color" : "form-control"
      if (field.type !== "textarea") input.type = field.type === "color" ? "color" : "text"
      if (field.type === "textarea") input.rows = 4
      input.id = id
      input.name = name
      input.required = Boolean(field.required)
      input.dataset.taxonomyField = field.name
      wrapper.append(label, input)
      // The two controls are judged as a pair, so the warning rides the second
      // one rather than being a field of its own: it is one sentence about both,
      // and the author reads it while changing either.
      if (field.name === "fgcolor" && judgesColors) wrapper.append(this.contrastNotice())
      fragment.append(wrapper)
    })

    return fragment
  }

  photoUrlFor(node) {
    const values = this.parseJson(node?.dataset.taxonomyValues, {})
    return values.photo || ""
  }

  // The one sentence the color pair is judged by.
  //
  // It is a `status` region and it is never hidden: a live region that is added
  // to the DOM together with its text is announced in some readers and dropped in
  // others, so the region is in the editor from the start and only its text
  // changes. It is a `status` rather than an `alert` because nothing failed and
  // the save button still works — an alert is a claim that something is wrong.
  contrastNotice() {
    const notice = document.createElement("p")
    notice.className = "small text-warning-emphasis mb-0 mt-1"
    notice.dataset.taxonomyTreeContrast = ""
    notice.setAttribute("role", "status")
    notice.setAttribute("aria-live", "polite")
    return notice
  }

  // The ratio the editor would paint right now. `null` when a control is missing
  // or holds something the rule cannot judge: a browser's own color control only
  // ever holds `#rrggbb`, so this is the guard rather than a state a reader can
  // reach, and it keeps the ratio a number or nothing at all.
  currentContrast(modal) {
    const [ background, foreground ] = [ "bgcolor", "fgcolor" ]
      .map((name) => this.findInput(modal, `${this.modelParamValue}[${name}]`, { type: "color" })?.value)

    return contrastRatio(foreground, background)
  }

  // Attach the warning to both color controls, and read the pair once before the
  // author touches anything. Bound from `populateModalFields` rather than from
  // `buildModal`, because the first reading is the pair the stored tag already
  // had, and `buildModal` runs before any value is in the form.
  bindContrastNotice(modal) {
    const notice = modal.querySelector("[data-taxonomy-tree-contrast]")
    if (!notice) return

    const update = () => {
      const ratio = this.currentContrast(modal)
      // Truncated rather than rounded, so a ratio that is only just under the
      // minimum is never printed as the minimum itself.
      notice.textContent = ratio === null || ratio >= MINIMUM_TEXT_CONTRAST
        ? ""
        : t("shared.taxonomy_tree.low_contrast_colors", {
          ratio: Math.floor(ratio * 10) / 10,
          minimum: MINIMUM_TEXT_CONTRAST.toFixed(1)
        })
    }

    const inputs = [ "bgcolor", "fgcolor" ]
      .map((name) => this.findInput(modal, `${this.modelParamValue}[${name}]`, { type: "color" }))
    inputs.forEach((input) => { input?.addEventListener("input", update) })
    // Once, so a tag that was saved with a poor pair opens with the warning
    // already under the colors rather than only after the author touches one.
    update()
  }

  fieldLabel(field, id, className = "form-label") {
    const label = document.createElement("label")
    label.className = className
    label.htmlFor = id
    label.append(document.createTextNode(field.label || ""))
    if (field.required) {
      const marker = document.createElement("span")
      marker.className = "text-danger"
      marker.setAttribute("aria-hidden", "true")
      // The asterisk is not chrome: it is the marker the stylesheet draws beside
      // a required field, and it is the same mark in every language. The words
      // a screen reader reads in its place are.
      marker.textContent = " *"
      const hidden = document.createElement("span")
      hidden.className = "visually-hidden"
      hidden.textContent = t("shared.taxonomy_tree.required")
      label.append(marker, hidden)
    }
    return label
  }

  populateModalFields(modal, node, { create = false, parentId = "" } = {}) {
    const values = create ? this.createDefaults() : {
      ...this.parseJson(node.dataset.taxonomyValues, {}),
      name: node.dataset.name || "",
      description: node.dataset.description || ""
    }
    if (create) {
      values.parent_id = parentId || ""
    } else if (this.hasFieldNameValue) {
      values[this.fieldNameValue] = this.parseJson(node.dataset.taxonomyFieldValue, null)
    }
    const fields = this.parseJson(this.modalFieldsValue, [])

    fields.forEach((field) => {
      // The photo control reads the URL from the container it was built with and
      // owns its own inputs, so it has no field to fill here.
      if (field.type === "photo") return

      const inputName = field.multiple ? `${this.modelParamValue}[${field.name}][]` : `${this.modelParamValue}[${field.name}]`
      const input = this.findInput(modal, inputName, field)
      if (!input) return
      if (field.type === "checkbox") {
        input.checked = Boolean(values[field.name])
      } else if (field.multiple) {
        const selected = (values[field.name] || []).map(String)
        Array.from(input.options).forEach((option) => { option.selected = selected.includes(option.value) })
      } else {
        input.value = values[field.name] ?? ""
      }

      if (field.required_unless) this.bindConditionalRequirement(modal, field, input)
    })

    const symmetric = this.findInput(modal, `${this.modelParamValue}[symmetric]`, { type: "checkbox" })
    const inverse = this.findInput(modal, `${this.modelParamValue}[inverse]`, {})
    if (symmetric && inverse) {
      const updateInverseRequirement = () => { inverse.required = !symmetric.checked }
      symmetric.addEventListener("change", updateInverseRequirement)
      updateInverseRequirement()
    }

    // Bound after the values are in, because the first reading of the pair is the
    // one the stored tag already had.
    this.bindContrastNotice(modal)
  }

  // A create starts from the descriptors' declared defaults rather than an empty
  // form, so a boolean the model defaults to true (a tag's `taggable`) is not
  // silently turned off by the hidden half of its checkbox.
  createDefaults() {
    const values = {}
    this.parseJson(this.modalFieldsValue, []).forEach((field) => {
      if (field.default !== undefined) values[field.name] = field.default
    })
    return values
  }

  findInput(modal, name, field) {
    return [ ...modal.querySelectorAll("[name]") ].find((input) => {
      if (input.name !== name) return false
      if (field.type === "checkbox") return input.type !== "hidden"
      return true
    })
  }

  bindConditionalRequirement(modal, field, input) {
    const condition = field.required_unless
    const controller = this.findInput(modal, `${this.modelParamValue}[${condition.field}]`, { type: condition.value === true ? "checkbox" : "text" })
    if (!controller) return

    const update = () => {
      const current = controller.type === "checkbox" ? controller.checked : controller.value
      input.required = current !== condition.value
    }
    controller.addEventListener("change", update)
    update()
  }

  // A rejected save keeps the editor open and explains itself: a `422` error hash
  // is rendered both in a summary and on the control that caused it, so a failure
  // is never only an announcement. The entered values stay where the author left
  // them, and the modal is not closed. Creation and update share this path
  // because they share every rule except the method, the URL, and what gets
  // focused after the page refreshes.
  async submitDetails(event) {
    event.preventDefault()
    const form = event.currentTarget
    const create = this.modalCreate
    const method = create ? "POST" : "PATCH"
    const url = create ? this.createUrlValue : this.modalRecord.dataset.updateUrl
    const response = await this.request(url, method, this.formValues(form))
    if (!response) return

    if (response.status === 422 && this.modalElement) {
      this.renderFieldErrors(this.modalElement, await this.parseResponse(response))
      return
    }

    if (!response.ok) {
      const fallback = create
        ? t("shared.taxonomy_tree.create_failed")
        : t("shared.taxonomy_tree.update_failed")
      this.announce(await this.mutationMessage(response, fallback), true)
      return
    }

    const recordId = this.modalRecord?.dataset.nodeId
    this.refreshing = true
    this.modal?.hide()
    if (create) {
      const data = await this.parseResponse(response)
      this.refreshAndFocus(data.id, "name")
    } else {
      this.refreshAndFocus(recordId, "name")
    }
  }

  renderFieldErrors(modal, payload) {
    const entries = this.errorEntries(payload)
    if (entries.length === 0) {
      this.announce(t("shared.modal_form.unexplained"), true)
      return
    }

    entries.forEach(([ attribute, messages ]) => {
      this.markFieldInvalid(modal, attribute, messages)
    })

    const list = document.createElement("ul")
    list.className = "mb-0 ps-3"
    entries.forEach(([ , messages ]) => {
      const item = document.createElement("li")
      item.textContent = messages.join(" ")
      list.append(item)
    })

    const alert = document.createElement("div")
    alert.className = "alert alert-danger mb-0"
    alert.setAttribute("role", "alert")
    const heading = document.createElement("p")
    heading.className = "mb-1"
    heading.textContent = t("shared.modal_form.fix_and_retry")
    alert.append(heading, list)

    // The editor is built in `document.body`, outside this controller's element,
    // so its error region is looked up inside the editor rather than as a
    // Stimulus target.
    const region = modal.querySelector("[data-taxonomy-tree-errors]")
    if (!region) return

    region.replaceChildren(alert)
    region.hidden = false
    region.focus()
  }

  // An error is keyed by the model attribute, while an association's form field
  // is its foreign key: the hierarchy scope validation reports on `:parent`, so
  // the `parent_id` selector is where its message belongs.
  fieldFor(modal, attribute) {
    if (attribute === "base") return null
    for (const candidate of [ attribute, `${attribute}_id`, `${attribute}_ids` ]) {
      const field = this.findInput(modal, `${this.modelParamValue}[${candidate}]`, { type: "text" })
      if (field) return field
    }
    return null
  }

  markFieldInvalid(modal, attribute, messages) {
    const field = this.fieldFor(modal, attribute)
    if (!field) return

    const host = field.closest(".mb-3, .form-check") || field.parentElement || modal
    const message = document.createElement("p")
    message.className = "invalid-feedback d-block mb-0"
    message.id = `${field.id}-error`
    message.textContent = messages.join(" ")
    host.append(message)

    field.setAttribute("aria-invalid", "true")
    field.setAttribute("aria-describedby", `${field.getAttribute("aria-describedby") || ""} ${message.id}`.trim())
  }

  // The label of the modal field an error belongs to, taken from the serialized
  // field descriptors so the message reads the way the editor labels the input.
  // A `belongs_to` rejection is keyed by the association (`:parent`) while the
  // descriptor is its foreign key (`parent_id`), so the same spellings
  // `fieldFor` uses to find the control are tried here too. An attribute with no
  // descriptor keeps the name the server used.
  // It is deliberately not named `fieldLabel`, which builds a label element for a
  // dynamic field.
  errorFieldLabel(attribute) {
    const fields = this.parseJson(this.modalFieldsValue, [])
    const candidates = [ attribute, `${attribute}_id`, String(attribute).replace(/_ids?$/, "") ]
    const descriptor = candidates
      .map((name) => fields.find((field) => field.name === name || `${field.name}_id` === name))
      .find(Boolean)
    return String(descriptor?.label || attribute).replace(/\s*\*\s*$/, "").trim()
  }

  // A `{ errors: ... }` envelope is only unwrapped when `errors` really is the
  // message hash, so a body that explains nothing is reported as such instead of
  // being read as an error on an attribute literally called "errors".
  errorEntries(payload) {
    const body = payload && typeof payload === "object" ? payload : null
    if (!body) return []

    const errors = "errors" in body ? body.errors : body
    if (!errors || typeof errors !== "object" || Array.isArray(errors)) return []

    return Object.entries(errors)
      .map(([ attribute, value ]) => {
        const raw = Array.isArray(value) ? value : [ value ]
        const messages = raw
          .map((message) => (typeof message === "string" ? message.trim() : ""))
          .filter((message) => message.length > 0)
          .map((message) => attribute === "base"
            ? t("shared.record_error", { subject: t("shared.taxonomy_tree.record_subject"), message })
            : t("shared.record_message", { label: this.errorFieldLabel(attribute), message }))
        return [ attribute, messages ]
      })
      .filter(([ , messages ]) => messages.length > 0)
  }

  // A single-field path (move, delete) has no summary to render, so the
  // server's own message is announced instead of a generic one.
  async mutationMessage(response, fallback) {
    if (response.status !== 422) return fallback

    const entries = this.errorEntries(await this.parseResponse(response))
    if (entries.length === 0) return fallback
    return entries.map(([ , messages ]) => messages.join(" ")).join(" ")
  }

  async remove(event) {
    if (!this.editableValue) return
    event.preventDefault()
    const node = event.currentTarget.closest("[data-node-id]")
    if (!node) return
    // The server owns the consequence copy when the record has dependents; the
    // generic message stays only as a fallback for an unrendered node.
    const consequence = node.dataset.confirmMessage?.trim()
    if (!window.confirm(consequence || t("shared.taxonomy_tree.delete_confirm", { name: node.dataset.name }))) return

    const nextFocus = this.nextTaxonomyNode(node)?.dataset.nodeId || this.previousTaxonomyNode(node)?.dataset.nodeId
    const response = await this.request(node.dataset.updateUrl, "DELETE")
    if (!response) return
    if (!response.ok) {
      this.announce(await this.mutationMessage(response, t("shared.taxonomy_tree.delete_failed")), true)
      return
    }

    this.refreshAndFocus(nextFocus, "name")
  }

  async move(event) {
    if (!this.editableValue) return
    event.preventDefault()
    const node = event.currentTarget.closest("[data-node-id]")
    const list = node?.parentElement
    if (!node || !list?.matches(".taxonomy-list")) return

    const nodes = this.directNodes(list)
    const index = nodes.indexOf(node)
    const direction = event.currentTarget.dataset.moveDirection
    const target = direction === "up" ? index - 1 : index + 1
    if (target < 0 || target >= nodes.length) return

    const response = await this.request(node.dataset.updateUrl, "PATCH", {
      parent_id: list.dataset.dropParentId || "",
      position: target
    })
    if (!response) return
    if (!response.ok) {
      this.announce(await this.mutationMessage(response, t("shared.taxonomy_tree.move_failed")), true)
      return
    }

    this.refreshAndFocus(node.dataset.nodeId, "name")
  }

  async request(url, method, values = {}) {
    const params = new URLSearchParams()
    Object.entries(values).forEach(([name, value]) => {
      if (value === undefined || value === null) return
      if (Array.isArray(value)) {
        value.forEach((item) => {
          params.append(`${this.modelParamValue}[${name}][]`, item)
        })
      } else {
        params.set(`${this.modelParamValue}[${name}]`, value)
      }
    })

    const headers = {
      "Accept": "application/json",
      "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8"
    }
    // A missing meta tag must not become the literal string "undefined", which the
    // server refuses as an invalid token rather than as a missing one.
    const token = document.querySelector("meta[name='csrf-token']")?.content
    if (token) headers["X-CSRF-Token"] = token

    try {
      return await fetch(url, {
        method,
        headers,
        body: new URLSearchParams(params)
      })
    } catch (_error) {
      this.announce(t("shared.taxonomy_tree.network_failed"), true)
      return null
    }
  }

  async parseResponse(response) {
    try {
      return await response.json()
    } catch (_error) {
      this.announce(t("shared.taxonomy_tree.invalid_response"), true)
      return {}
    }
  }

  formValues(form) {
    const values = {}
    new FormData(form).forEach((value, key) => {
      const match = key.match(new RegExp(`^${this.escapeRegExp(this.modelParamValue)}\\[(.+?)\\](\\[\\])?$`))
      if (!match) return
      const name = match[1]
      if (match[2]) values[name] = values[name] || []
      else values[name] = value
      if (Array.isArray(values[name])) values[name].push(value)
    })
    return values
  }

  button(label, className, type, action = null, ariaLabel = null) {
    const button = document.createElement("button")
    button.type = type
    button.className = className
    if (action) button.dataset.action = action
    if (ariaLabel) button.setAttribute("aria-label", ariaLabel)
    button.textContent = label
    return button
  }

  rootList() {
    return this.element.querySelector(":scope > .taxonomy-surface > .taxonomy-list")
  }

  directNodes(list) {
    return [ ...list.children ].filter((element) => element.matches(".taxonomy-node"))
  }

  childList(node) {
    let list = node.querySelector(":scope > .taxonomy-list")
    if (!list) {
      list = document.createElement("ul")
      list.className = "taxonomy-list list-unstyled ms-4 ps-3"
      list.dataset.action = "dragover->taxonomy-tree#allowDrop drop->taxonomy-tree#drop"
      list.dataset.dropParentId = node.dataset.nodeId
      if (this.draggedNode) list.dataset.dragPreview = "true"
      node.append(list)
    }
    return list
  }

  updateMoveControls() {
    this.element.querySelectorAll("[data-node-id]").forEach((node) => {
      const list = node.parentElement
      if (!list?.matches(".taxonomy-list")) return
      const nodes = this.directNodes(list)
      const index = nodes.indexOf(node)
      // Move up/Move down live in the row menu now, so the boundary state is
      // expressed by disabling the menu item instead of a row button.
      const up = node.querySelector('[data-taxonomy-action="move-up"]')
      const down = node.querySelector('[data-taxonomy-action="move-down"]')
      if (up) up.disabled = index <= 0
      if (down) down.disabled = index < 0 || index >= nodes.length - 1
    })
  }

  nextTaxonomyNode(node) {
    let element = node.nextElementSibling
    while (element && !element.matches(".taxonomy-node")) element = element.nextElementSibling
    return element
  }

  previousTaxonomyNode(node) {
    let element = node.previousElementSibling
    while (element && !element.matches(".taxonomy-node")) element = element.previousElementSibling
    return element
  }

  startDrag(event) {
    if (!this.editableValue) return
    event.stopPropagation()
    this.draggedNode = event.currentTarget
    this.dragOriginalParent = this.draggedNode.parentElement
    this.dragOriginalNext = this.nextTaxonomyNode(this.draggedNode)
    this.dropHandled = false
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.draggedNode.dataset.nodeId)
    this.element.classList.add("taxonomy-tree--dragging")
    this.draggedNode.classList.add("taxonomy-node--dragging")
    requestAnimationFrame(() => this.updateDragIndicator())
  }

  allowDrop(event) {
    if (!this.editableValue) return
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    if (!this.draggedNode) return
    event.stopPropagation()

    const current = event.currentTarget
    if (current.matches(".taxonomy-list")) {
      this.previewMove(current, null)
      return
    }
    if (!current.matches("[data-node-id]") || current === this.draggedNode || this.draggedNode.contains(current)) return

    const row = current.querySelector(":scope > .taxonomy-row")
    const rect = row.getBoundingClientRect()
    const offset = (event.clientY - rect.top) / rect.height
    if (offset < 0.25) this.previewMove(current.parentElement, current, "before")
    else if (offset > 0.75) this.previewMove(current.parentElement, current, "after")
    else this.previewMove(this.childList(current), null)
  }

  previewMove(list, targetNode, position) {
    if (targetNode) {
      if (position === "after") {
        if (targetNode.nextElementSibling !== this.draggedNode) targetNode.after(this.draggedNode)
      } else if (targetNode.previousElementSibling !== this.draggedNode) {
        targetNode.before(this.draggedNode)
      }
    } else if (list.lastElementChild !== this.draggedNode) {
      list.append(this.draggedNode)
    }
    this.updateDragIndicator()
  }

  updateDragIndicator() {
    const node = this.draggedNode
    if (!node) return
    const noop = node.parentElement === this.dragOriginalParent && this.nextTaxonomyNode(node) === this.dragOriginalNext
    node.classList.toggle("taxonomy-node--drop-noop", noop)
    node.classList.toggle("taxonomy-node--drop-move", !noop)
  }

  async drop(event) {
    if (!this.editableValue) return
    event.preventDefault()
    event.stopPropagation()
    if (!this.draggedNode) return
    this.dropHandled = true

    const node = this.draggedNode
    const originalParent = this.dragOriginalParent
    const originalNext = this.dragOriginalNext
    const noop = node.parentElement === originalParent && this.nextTaxonomyNode(node) === originalNext
    this.cleanupDrag()
    if (noop) return

    const parentId = node.parentElement.dataset.dropParentId || ""
    const position = this.directNodes(node.parentElement).indexOf(node)
    const updateUrl = node.dataset.updateUrl
    const restore = () => {
      if (originalNext) originalNext.before(node)
      else originalParent.append(node)
        this.updateMoveControls()
    }
    if (!updateUrl) {
      restore()
      return
    }

    const response = await this.request(updateUrl, "PATCH", { parent_id: parentId, position })
    if (response?.ok) {
      this.refreshAndFocus(node.dataset.nodeId, "name")
      return
    }

    restore()
    if (!response) return
    this.announce(await this.mutationMessage(response, t("shared.taxonomy_tree.move_failed")), true)
  }

  endDrag() {
    if (!this.editableValue || !this.draggedNode) return
    if (!this.dropHandled) {
      if (this.dragOriginalNext) this.dragOriginalNext.before(this.draggedNode)
      else this.dragOriginalParent.append(this.draggedNode)
        this.updateMoveControls()
    }
    this.cleanupDrag()
  }

  cleanupDrag() {
    if (this.draggedNode) this.draggedNode.classList.remove("taxonomy-node--dragging", "taxonomy-node--drop-noop", "taxonomy-node--drop-move")
    this.element.classList.remove("taxonomy-tree--dragging")
    this.element.querySelectorAll('.taxonomy-list[data-drag-preview="true"]').forEach((list) => {
      if (list.children.length === 0) list.remove()
      else delete list.dataset.dragPreview
    })
    this.draggedNode = null
    this.dragOriginalParent = null
    this.dragOriginalNext = null
    this.dropHandled = false
  }

  refreshAndFocus(nodeId, target = "name") {
    this.storePendingFocus(nodeId, target)
    this.announce(t("shared.taxonomy_tree.saved_refresh"))
    if (window.Turbo?.visit) window.Turbo.visit(window.location.href, { action: "replace" })
    else window.location.reload()
  }

  storePendingFocus(nodeId, target) {
    try {
      sessionStorage.setItem(FOCUS_STORAGE_KEY, JSON.stringify({ nodeId, target }))
    } catch (_error) {
      // Focus restoration is an enhancement; a blocked storage API must not break a save.
    }
  }

  restorePendingFocus() {
    let pending
    try {
      pending = JSON.parse(sessionStorage.getItem(FOCUS_STORAGE_KEY) || "null")
      sessionStorage.removeItem(FOCUS_STORAGE_KEY)
    } catch (_error) {
      return
    }
    if (!pending) return

    requestAnimationFrame(() => {
      const node = [ ...this.element.querySelectorAll("[data-node-id]") ].find((element) => element.dataset.nodeId === String(pending.nodeId))
      const target = node?.querySelector(`[data-taxonomy-tree-target="${pending.target || "name"}"]`)
      if (target) target.focus()
      else this.element.querySelector('[data-action="taxonomy-tree#add"]')?.focus()
    })
  }

  handleTurboRender() {
    this.restorePendingFocus()
  }

  announce(message, error = false) {
    const status = this.element.querySelector("[data-taxonomy-tree-status]")
    if (!status) return
    status.textContent = message
    status.classList.toggle("text-danger", error)
    status.classList.toggle("visually-hidden", !error)
  }

  parseJson(value, fallback) {
    try {
      return JSON.parse(value || "")
    } catch (_error) {
      return fallback
    }
  }

  escapeRegExp(value) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  }
}
