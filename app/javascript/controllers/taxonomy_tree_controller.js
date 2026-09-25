import { Controller } from "@hotwired/stimulus"
import "bootstrap"
import "tom-select"

const FOCUS_STORAGE_KEY = "universe-maker:taxonomy-tree-focus"

export default class extends Controller {
  static values = { modelParam: String, createUrl: String, modalFields: String, fieldName: String, editable: Boolean }

  connect() {
    if (!this.editableValue) return

    this.handleOutsideClick = this.handleOutsideClick.bind(this)
    this.handleTurboRender = this.handleTurboRender.bind(this)
    document.addEventListener("pointerdown", this.handleOutsideClick)
    document.addEventListener("turbo:render", this.handleTurboRender)
    this.emptyStateTemplate = this.element.querySelector("[data-taxonomy-tree-empty]")?.cloneNode(true)
    this.refreshSeparators()
    this.updateMoveControls()
    this.restorePendingFocus()
  }

  disconnect() {
    if (this.handleOutsideClick) document.removeEventListener("pointerdown", this.handleOutsideClick)
    if (this.handleTurboRender) document.removeEventListener("turbo:render", this.handleTurboRender)
  }

  add(event) {
    if (!this.editableValue) return
    event.preventDefault()
    if (this.element.querySelector(".taxonomy-new")) return

    const source = event.currentTarget
    const parentNode = source.closest("[data-node-id]")
    const list = parentNode ? this.childList(parentNode) : this.rootList()
    const parentId = parentNode?.dataset.nodeId || ""
    const position = this.directNodes(list).length
    this.removeEmptyState()

    const item = this.buildNewItem(parentId, position)
    list.append(item)
    this.refreshSeparators()
    item.querySelector("input")?.focus()
  }

  insertAt(event) {
    if (!this.editableValue) return
    event.preventDefault()
    if (this.element.querySelector(".taxonomy-new")) return

    const separator = event.currentTarget.closest(".taxonomy-separator")
    const parentId = separator?.dataset.parentId || ""
    const position = Number(separator?.dataset.position || 0)
    const list = this.listForParent(parentId)
    if (!list) return

    const item = this.buildNewItem(parentId, position)
    const reference = this.directNodes(list)[position]
    list.insertBefore(item, reference || null)
    separator.remove()
    this.refreshSeparators()
    item.querySelector("input")?.focus()
  }

  insertRelative(event) {
    if (!this.editableValue) return
    event.preventDefault()
    if (this.element.querySelector(".taxonomy-new")) return

    const node = event.currentTarget.closest("[data-node-id]")
    const list = node?.parentElement
    if (!node || !list?.matches(".taxonomy-list")) return

    const nodes = this.directNodes(list)
    const index = nodes.indexOf(node)
    const position = index + (event.currentTarget.dataset.insertPosition === "after" ? 1 : 0)
    const item = this.buildNewItem(list.dataset.dropParentId || "", position)
    list.insertBefore(item, nodes[position] || null)
    this.refreshSeparators()
    item.querySelector("input")?.focus()
  }

  buildNewItem(parentId, position) {
    const item = document.createElement("li")
    item.className = "taxonomy-node taxonomy-new"

    const row = document.createElement("div")
    row.className = "taxonomy-row d-flex align-items-center gap-2 border-bottom"
    row.append(this.icon("bi-grip-vertical", "text-body-secondary"))

    const form = document.createElement("form")
    form.className = "taxonomy-create-form d-flex flex-grow-1 gap-2"
    form.addEventListener("submit", (event) => this.create(event))
    form.dataset.url = this.createUrlValue
    form.dataset.parentId = parentId || ""
    if (position !== undefined && position !== null) form.dataset.position = String(position)

    const input = document.createElement("input")
    input.className = "form-control form-control-sm"
    input.name = "name"
    input.setAttribute("aria-label", "New name")
    input.required = true
    const cancel = this.button("Cancel", "btn btn-sm btn-outline-secondary", "button")
    cancel.addEventListener("click", (event) => this.cancel(event))
    form.append(input, this.button("Save", "btn btn-sm btn-primary", "submit"), cancel)

    row.append(form)
    item.append(row)
    return item
  }

  async editName(event) {
    if (!this.editableValue) return
    event.preventDefault()
    const node = event.currentTarget.closest("[data-node-id]")
    if (!node || node.querySelector("input")) return
    if (this.inlineEditor && this.inlineEditor !== node) await this.saveInlineEditor()
    if (this.modal) return

    const name = node.querySelector('[data-taxonomy-tree-target="name"]')
    const form = document.createElement("form")
    form.className = "taxonomy-update-form d-flex flex-grow-1 gap-2"
    form.addEventListener("submit", (event) => this.update(event))

    const input = document.createElement("input")
    input.className = "form-control form-control-sm"
    input.name = "name"
    input.value = node.dataset.name || ""
    input.required = true
    const cancel = this.button("Cancel", "btn btn-sm btn-outline-secondary", "button")
    cancel.addEventListener("click", (event) => this.cancel(event))
    form.append(input, this.button("Save", "btn btn-sm btn-primary", "submit"), cancel)

    name.replaceWith(form)
    node.classList.add("is-editing")
    this.inlineEditor = node
    input.focus()
    input.select()
  }

  async handleOutsideClick(event) {
    if (!this.inlineEditor || event.target.closest("[data-node-id], .taxonomy-new")) return
    await this.saveInlineEditor()
  }

  async edit(event) {
    if (!this.editableValue) return
    event.preventDefault()
    const node = event.currentTarget.closest("[data-node-id]")
    if (!node) return
    if (this.inlineEditor) await this.saveInlineEditor()
    if (this.modal) return

    const modal = this.buildModal(node)
    document.body.append(modal)
    this.populateModalFields(modal, node)
    modal.querySelectorAll("select[multiple]").forEach((select) => new window.TomSelect(select, { plugins: [ "remove_button" ], create: false }))

    this.modal = new window.bootstrap.Modal(modal)
    modal.addEventListener("hidden.bs.modal", () => {
      modal.querySelectorAll("select[multiple]").forEach((select) => select.tomselect?.destroy())
      modal.remove()
      this.modal = null
    }, { once: true })
    modal.querySelector("form").addEventListener("submit", (submitEvent) => this.updateDetails(submitEvent, node))
    this.modal.show()
  }

  buildModal(node) {
    const titleId = `taxonomy-edit-title-${node.dataset.nodeId}`
    const modal = document.createElement("div")
    modal.className = "modal fade"
    modal.tabIndex = -1
    modal.setAttribute("aria-labelledby", titleId)
    modal.setAttribute("aria-hidden", "true")

    const dialog = document.createElement("div")
    dialog.className = "modal-dialog"
    const content = document.createElement("div")
    content.className = "modal-content"
    const header = document.createElement("div")
    header.className = "modal-header"
    const title = document.createElement("h2")
    title.className = "modal-title fs-5"
    title.id = titleId
    title.textContent = `Edit ${node.dataset.name || "item"}`
    const close = this.button("", "btn-close", "button", null, "Close")
    close.setAttribute("data-bs-dismiss", "modal")
    header.append(title, close)

    const form = document.createElement("form")
    form.action = node.dataset.updateUrl
    form.method = "post"
    const body = document.createElement("div")
    body.className = "modal-body"
    body.append(this.modalFields(node))
    const footer = document.createElement("div")
    footer.className = "modal-footer"
    const cancel = this.button("Cancel", "btn btn-secondary", "button")
    cancel.setAttribute("data-bs-dismiss", "modal")
    footer.append(cancel, this.button("Save changes", "btn btn-primary", "submit"))
    form.append(body, footer)
    content.append(header, form)
    dialog.append(content)
    modal.append(dialog)
    return modal
  }

  modalFields(node) {
    const fragment = document.createDocumentFragment()
    const excludedParentIds = new Set([ node.dataset.nodeId, ...[ ...node.querySelectorAll("[data-node-id]") ].map((element) => element.dataset.nodeId) ])
    const fields = this.parseJson(this.modalFieldsValue, [])

    fields.forEach((field) => {
      const id = `taxonomy-edit-${field.name}-${node.dataset.nodeId}`
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
      fragment.append(wrapper)
    })

    return fragment
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
      marker.textContent = " *"
      const hidden = document.createElement("span")
      hidden.className = "visually-hidden"
      hidden.textContent = " (required)"
      label.append(marker, hidden)
    }
    return label
  }

  populateModalFields(modal, node) {
    const values = {
      ...this.parseJson(node.dataset.taxonomyValues, {}),
      name: node.dataset.name || "",
      description: node.dataset.description || ""
    }
    if (this.hasFieldNameValue) values[this.fieldNameValue] = this.parseJson(node.dataset.taxonomyFieldValue, null)
    const fields = this.parseJson(this.modalFieldsValue, [])

    fields.forEach((field) => {
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

  async updateDetails(event, node) {
    event.preventDefault()
    const form = event.currentTarget
    const response = await this.request(form.action, "PATCH", this.formValues(form))
    if (!response || !response.ok) {
      this.announce("The changes could not be saved.", true)
      return
    }

    this.modal?.hide()
    this.refreshAndFocus(node.dataset.nodeId, "name")
  }

  cancel(event) {
    event.preventDefault()
    const item = event.currentTarget.closest(".taxonomy-new")
    if (item) {
      const list = item.parentElement
      item.remove()
      this.cleanupNewList(list)
      this.restoreEmptyState()
      this.refreshSeparators()
      this.focusAfterCancel(list)
      return
    }

    const form = event.currentTarget.closest("form")
    const node = form?.closest("[data-node-id]")
    if (!form || !node) return
    this.restoreName(form)
    node.classList.remove("is-editing")
    this.inlineEditor = null
    form.querySelector('[data-taxonomy-tree-target="name"]')?.focus()
  }

  async create(event) {
    if (!this.editableValue) return
    event.preventDefault()
    const form = event.currentTarget
    const values = { name: form.querySelector("[name='name']")?.value || "", parent_id: form.dataset.parentId }
    if (form.dataset.position !== undefined) values.position = Number(form.dataset.position)

    const response = await this.request(form.dataset.url, "POST", values)
    if (!response || !response.ok) {
      this.announce("The item could not be created.", true)
      return
    }

    const data = await this.parseResponse(response)
    this.refreshAndFocus(data.id, "name")
  }

  async update(event) {
    if (!this.editableValue) return
    event.preventDefault()
    const form = event.currentTarget
    const node = form.closest("[data-node-id]")
    const response = await this.request(node.dataset.updateUrl, "PATCH", { name: form.querySelector("[name='name']")?.value || "" })
    if (!response || !response.ok) {
      this.announce("The name could not be saved.", true)
      return
    }

    this.refreshAndFocus(node.dataset.nodeId, "name")
  }

  async saveInlineEditor() {
    if (!this.editableValue) return
    const node = this.inlineEditor
    const form = node?.querySelector("form")
    if (!form) {
      this.inlineEditor = null
      return
    }

    const response = await this.request(node.dataset.updateUrl, "PATCH", { name: form.querySelector("[name='name']")?.value || "" })
    if (!response || !response.ok) {
      this.announce("The name could not be saved.", true)
      return
    }

    this.refreshAndFocus(node.dataset.nodeId, "name")
  }

  async remove(event) {
    if (!this.editableValue) return
    event.preventDefault()
    const node = event.currentTarget.closest("[data-node-id]")
    if (!node) return
    // The server owns the consequence copy when the record has dependents; the
    // generic message stays only as a fallback for an unrendered node.
    const consequence = node.dataset.confirmMessage?.trim()
    if (!window.confirm(consequence || `Delete ${node.dataset.name} and its children?`)) return

    const nextFocus = this.nextTaxonomyNode(node)?.dataset.nodeId || this.previousTaxonomyNode(node)?.dataset.nodeId
    const response = await this.request(node.dataset.updateUrl, "DELETE")
    if (!response || !response.ok) {
      this.announce("The item could not be deleted.", true)
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
    if (!response || !response.ok) {
      this.announce("The item could not be moved.", true)
      return
    }

    this.refreshAndFocus(node.dataset.nodeId, "name")
  }

  async request(url, method, values = {}) {
    const params = new URLSearchParams()
    Object.entries(values).forEach(([name, value]) => {
      if (value === undefined || value === null) return
      if (Array.isArray(value)) {
        value.forEach((item) => params.append(`${this.modelParamValue}[${name}][]`, item))
      } else {
        params.set(`${this.modelParamValue}[${name}]`, value)
      }
    })

    const token = document.querySelector("meta[name='csrf-token']")?.content
    try {
      return await fetch(url, {
        method,
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
          "X-CSRF-Token": token
        },
        body: new URLSearchParams(params)
      })
    } catch (_error) {
      this.announce("The network request failed. Please try again.", true)
      return null
    }
  }

  async parseResponse(response) {
    try {
      return await response.json()
    } catch (_error) {
      this.announce("The server returned an invalid response.", true)
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

  buildNode(data) {
    const node = document.createElement("li")
    node.className = "taxonomy-node"
    node.draggable = true
    node.dataset.taxonomyTreeTarget = "node"
    node.dataset.action = "dragstart->taxonomy-tree#startDrag dragover->taxonomy-tree#allowDrop drop->taxonomy-tree#drop dragend->taxonomy-tree#endDrag"
    node.dataset.nodeId = data.id
    node.dataset.updateUrl = data.url
    node.dataset.createUrl = this.createUrlValue
    node.dataset.name = data.name
    node.dataset.description = data.description || ""
    node.dataset.taxonomyValues = JSON.stringify(data)
    if (this.hasFieldNameValue) node.dataset.taxonomyFieldValue = JSON.stringify(data[this.fieldNameValue] ?? null)

    const row = document.createElement("div")
    row.className = "taxonomy-row d-flex align-items-center gap-2 border-bottom"
    row.append(this.icon("bi-grip-vertical", "text-body-secondary"), this.buildNameTrigger(data, true), this.buildActions(data, true))
    node.append(row)
    return node
  }

  buildNameTrigger(data, editable) {
    const trigger = document.createElement(editable ? "button" : "span")
    trigger.className = editable ? "taxonomy-name-trigger flex-grow-1 text-break" : "flex-grow-1 text-break"
    if (editable) {
      trigger.type = "button"
      trigger.dataset.taxonomyTreeTarget = "name"
      trigger.dataset.action = "click->taxonomy-tree#editName"
      trigger.setAttribute("aria-label", `Rename ${data.name}`)
    }
    trigger.append(this.buildNameContent(data))
    return trigger
  }

  buildActions(data, editable) {
    const actions = document.createElement("span")
    actions.className = "taxonomy-actions d-flex align-items-center gap-1"
    if (!editable) return actions

    const add = this.iconButton("bi-plus-lg", "Add child", "taxonomy-tree#add")
    add.dataset.taxonomyAction = "add-child"
    const up = this.iconButton("bi-arrow-up", "Move up", "taxonomy-tree#move")
    up.dataset.moveDirection = "up"
    up.dataset.taxonomyAction = "move-up"
    const down = this.iconButton("bi-arrow-down", "Move down", "taxonomy-tree#move")
    down.dataset.moveDirection = "down"
    down.dataset.taxonomyAction = "move-down"
    actions.append(add, up, down)

    const dropdown = document.createElement("div")
    dropdown.className = "dropdown"
    const toggle = this.iconButton("bi-three-dots", `Actions for ${data.name}`)
    toggle.id = `taxonomy-${data.id}-actions`
    toggle.dataset.bsToggle = "dropdown"
    toggle.setAttribute("aria-expanded", "false")
    const menu = document.createElement("ul")
    menu.className = "dropdown-menu dropdown-menu-end"
    menu.setAttribute("aria-labelledby", toggle.id)
    menu.append(
      this.menuItem("Edit", "bi-pencil", "taxonomy-tree#edit", ""),
      this.menuItem("Insert before", "bi-plus-lg", "taxonomy-tree#insertRelative", "before"),
      this.menuItem("Insert after", "bi-plus-lg", "taxonomy-tree#insertRelative", "after")
    )
    const divider = document.createElement("li")
    divider.className = "dropdown-divider"
    const remove = this.menuItem("Delete", "bi-trash", "taxonomy-tree#remove", "", "text-danger")
    menu.append(divider, remove)
    dropdown.append(toggle, menu)
    actions.append(dropdown)
    return actions
  }

  menuItem(label, icon, action, insertPosition = "", className = "") {
    const item = document.createElement("li")
    const button = document.createElement("button")
    button.type = "button"
    button.className = `dropdown-item ${className}`.trim()
    button.dataset.action = action
    if (insertPosition) button.dataset.insertPosition = insertPosition
    button.append(this.icon(icon, "me-2"), document.createTextNode(label))
    item.append(button)
    return item
  }

  iconButton(icon, label, action = null) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "btn btn-sm btn-light border"
    button.title = label
    button.setAttribute("aria-label", label)
    if (action) button.dataset.action = action
    button.append(this.icon(icon))
    return button
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

  icon(name, className = "") {
    const icon = document.createElement("i")
    icon.className = `bi ${name} ${className}`.trim()
    icon.setAttribute("aria-hidden", "true")
    return icon
  }

  buildNameContent(data) {
    const fragment = document.createDocumentFragment()
    if (this.safeColor(data.bgcolor)) {
      const badge = document.createElement("span")
      badge.className = "badge rounded-pill taxonomy-tag text-dark"
      badge.style.backgroundColor = data.bgcolor
      if (this.safeColor(data.fgcolor)) badge.style.color = data.fgcolor
      badge.textContent = data.name
      fragment.append(badge)
    } else {
      const title = document.createElement("span")
      title.className = "entity-title"
      title.textContent = data.name
      fragment.append(title)
    }

    if (data.description) {
      const description = document.createElement("span")
      description.className = "entity-description d-block"
      description.textContent = data.description
      fragment.append(description)
    }
    return fragment
  }

  safeColor(value) {
    return typeof value === "string" && /^#[0-9a-f]{6}$/i.test(value)
  }

  restoreName(form) {
    const node = form.closest("[data-node-id]")
    if (!node) return
    const values = this.parseJson(node.dataset.taxonomyValues, {})
    const trigger = this.buildNameTrigger({ ...values, name: form.querySelector("input")?.value || node.dataset.name, description: node.dataset.description }, true)
    form.replaceWith(trigger)
    this.updateMoveControls()
    trigger.focus()
  }

  rootList() {
    return this.element.querySelector(":scope > .taxonomy-surface > .taxonomy-list")
  }

  listForParent(parentId) {
    if (!parentId) return this.rootList()
    return [ ...this.element.querySelectorAll(".taxonomy-list") ].find((list) => list.dataset.dropParentId === String(parentId))
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
      list.dataset.newList = "true"
      if (this.draggedNode) list.dataset.dragPreview = "true"
      node.append(list)
    }
    return list
  }

  cleanupNewList(list) {
    if (!list || list === this.rootList() || this.directNodes(list).length > 0) return
    if (list.dataset.newList === "true" || list.dataset.dragPreview === "true") list.remove()
  }

  removeEmptyState() {
    this.element.querySelector("[data-taxonomy-tree-empty]")?.remove()
  }

  restoreEmptyState() {
    if (this.element.querySelector("[data-node-id]") || !this.emptyStateTemplate) return
    this.element.querySelector(".taxonomy-surface")?.prepend(this.emptyStateTemplate.cloneNode(true))
  }

  focusAfterCancel(list) {
    const node = list?.closest("[data-node-id]")?.querySelector('[data-taxonomy-tree-target="name"]')
    if (node) node.focus()
    else this.element.querySelector('[data-action="taxonomy-tree#add"]')?.focus()
  }

  refreshSeparators() {
    if (!this.editableValue) return
    this.element.querySelectorAll(".taxonomy-separator").forEach((element) => element.remove())
    const root = this.rootList()
    if (!root) return
    const lists = [ root, ...root.querySelectorAll(".taxonomy-list") ]
    lists.forEach((list) => {
      const nodes = this.directNodes(list)
      if (nodes.length === 0) return
      list.insertBefore(this.buildSeparator(list, 0), nodes[0])
      nodes.slice(1).forEach((node, index) => list.insertBefore(this.buildSeparator(list, index + 1), node))
      list.append(this.buildSeparator(list, nodes.length))
    })
  }

  buildSeparator(list, position) {
    const separator = document.createElement("li")
    separator.className = "taxonomy-separator"
    separator.dataset.parentId = list.dataset.dropParentId || ""
    separator.dataset.position = String(position)
    const button = this.iconButton("bi-plus-lg", `Insert item at position ${position + 1}`, "taxonomy-tree#insertAt")
    button.className = "taxonomy-separator-add"
    separator.append(button)
    return separator
  }

  updateMoveControls() {
    this.element.querySelectorAll("[data-node-id]").forEach((node) => {
      const list = node.parentElement
      if (!list?.matches(".taxonomy-list")) return
      const nodes = this.directNodes(list)
      const index = nodes.indexOf(node)
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
      this.refreshSeparators()
      this.updateMoveControls()
    }
    if (!updateUrl) {
      restore()
      return
    }

    const response = await this.request(updateUrl, "PATCH", { parent_id: parentId, position })
    if (response?.ok) this.refreshAndFocus(node.dataset.nodeId, "name")
    else {
      restore()
      this.announce("The item could not be moved.", true)
    }
  }

  endDrag() {
    if (!this.editableValue || !this.draggedNode) return
    if (!this.dropHandled) {
      if (this.dragOriginalNext) this.dragOriginalNext.before(this.draggedNode)
      else this.dragOriginalParent.append(this.draggedNode)
      this.refreshSeparators()
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
    this.announce("Saved. Refreshing the taxonomy…")
    if (window.Turbo?.visit) window.Turbo.visit(window.location.href, { action: "replace" })
    else window.location.href = window.location.href
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
