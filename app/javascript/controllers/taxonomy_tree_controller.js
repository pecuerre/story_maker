import { Controller } from "@hotwired/stimulus"
import "bootstrap"
import "tom-select"

export default class extends Controller {
  static values = { modelParam: String, createUrl: String, modalFields: String, fieldName: String }

  connect() {
    this.handleOutsideClick = this.handleOutsideClick.bind(this)
    document.addEventListener("pointerdown", this.handleOutsideClick)
    this.refreshSeparators()
  }

  disconnect() {
    document.removeEventListener("pointerdown", this.handleOutsideClick)
  }

  add(event) {
    event.preventDefault()
    if (this.element.querySelector(".taxonomy-new")) return
    const source = event.currentTarget
    const parentNode = source.closest("[data-node-id]")
    const list = parentNode ? this.childList(parentNode) : this.element.querySelector(":scope > .taxonomy-list")

    const item = this.buildNewItem(parentNode?.dataset.nodeId || "")
    list.append(item)
    item.querySelector("input").focus()
  }

  insertAt(event) {
    event.preventDefault()
    if (this.element.querySelector(".taxonomy-new")) return

    const separator = event.currentTarget.closest(".taxonomy-separator")
    const belowNode = separator.nextElementSibling
    const flatNodes = [...this.element.querySelectorAll(".taxonomy-node")]
    const aboveNode = flatNodes[flatNodes.indexOf(belowNode) - 1]
    if (!aboveNode || !belowNode) return

    const belowParentId = belowNode.parentElement.dataset.dropParentId || ""
    let item
    if (belowParentId === aboveNode.dataset.nodeId) {
      // Below node is above node's first child: insert as the new first child.
      item = this.buildNewItem(aboveNode.dataset.nodeId, 0)
      separator.remove()
      this.childList(aboveNode).prepend(item)
    } else {
      // Otherwise the new node takes the same parent as the node above, right after it.
      const aboveList = aboveNode.parentElement
      const parentId = aboveList.dataset.dropParentId || ""
      const position = [...aboveList.children].filter((el) => el.matches(".taxonomy-node")).indexOf(aboveNode) + 1
      item = this.buildNewItem(parentId, position)
      separator.remove()
      aboveNode.after(item)
    }
    item.querySelector("input").focus()
  }

  buildNewItem(parentId, position) {
    const item = document.createElement("li")
    item.className = "taxonomy-node taxonomy-new"
    item.innerHTML = `<div class="d-flex align-items-center gap-2 border-bottom py-2"><i class="bi bi-grip-vertical text-body-secondary" aria-hidden="true"></i><form class="d-flex flex-grow-1 gap-2" data-action="submit->taxonomy-tree#create"><input class="form-control form-control-sm" name="name" aria-label="New name" required><button type="submit" class="btn btn-sm btn-primary">Save</button><button type="button" class="btn btn-sm btn-outline-secondary" data-action="taxonomy-tree#cancel">Cancel</button></form></div>`
    const form = item.querySelector("form")
    form.dataset.url = this.createUrlValue
    form.dataset.parentId = parentId || ""
    if (position !== undefined) form.dataset.position = position
    return item
  }

  async editName(event) {
    event.preventDefault()
    const node = event.currentTarget.closest("[data-node-id]")
    if (this.inlineEditor && this.inlineEditor !== node) await this.saveInlineEditor()
    if (node.querySelector("input")) return
    const name = node.querySelector('[data-taxonomy-tree-target="name"]')
    const form = document.createElement("form")
    form.className = "d-flex flex-grow-1 gap-2"
    form.dataset.action = "submit->taxonomy-tree#update"
    form.innerHTML = `<input class="form-control form-control-sm" name="name" value="" required><button type="submit" class="btn btn-sm btn-primary">Save</button><button type="button" class="btn btn-sm btn-outline-secondary" data-action="taxonomy-tree#cancel">Cancel</button>`
    form.querySelector("input").value = node.dataset.name
    name.replaceWith(form)
    node.classList.add("is-editing")
    this.inlineEditor = node
    form.querySelector("input").focus()
    form.querySelector("input").select()
  }

  async handleOutsideClick(event) {
    if (!this.inlineEditor || event.target.closest("[data-node-id], .taxonomy-new")) return
    await this.saveInlineEditor()
  }

  async edit(event) {
    event.preventDefault()
    const node = event.currentTarget.closest("[data-node-id]")
    if (this.inlineEditor) await this.saveInlineEditor()
    if (this.modal) return

    const modal = document.createElement("div")
    const titleId = `taxonomy-edit-title-${node.dataset.nodeId}`
    modal.className = "modal fade"
    modal.tabIndex = -1
    modal.setAttribute("aria-labelledby", titleId)
    modal.setAttribute("aria-hidden", "true")
    modal.innerHTML = `<div class="modal-dialog"><div class="modal-content"><div class="modal-header"><h1 class="modal-title fs-5" id="${titleId}"></h1><button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button></div><form action="${node.dataset.updateUrl}" method="post"><div class="modal-body">${this.modalFields(node)}</div><div class="modal-footer"><button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button><button type="submit" class="btn btn-primary">Save changes</button></div></form></div></div>`
    modal.querySelector(".modal-title").textContent = `Edit ${node.dataset.name}`
    this.populateModalFields(modal, node)
    modal.querySelector("form").addEventListener("submit", (submitEvent) => this.updateDetails(submitEvent, node))
    document.body.append(modal)
    modal.querySelectorAll("select[multiple]").forEach((select) => new window.TomSelect(select, { plugins: [ "remove_button" ], create: false }))

    this.modal = new window.bootstrap.Modal(modal)
    modal.addEventListener("hidden.bs.modal", () => {
      this.modal.dispose()
      modal.querySelectorAll("select[multiple]").forEach((select) => select.tomselect?.destroy())
      modal.remove()
      this.modal = null
    }, { once: true })
    this.modal.show()
  }

  async updateDetails(event, node) {
    event.preventDefault()
    const form = event.currentTarget
    const response = await fetch(form.action, {
      method: "PATCH",
      headers: { "Accept": "application/json", "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content },
      body: new URLSearchParams(new FormData(form))
    })
    if (!response.ok) return
    const data = await response.json()
    node.dataset.name = data.name
    node.dataset.description = data.description || ""
    node.dataset.taxonomyValues = JSON.stringify(data)
    node.querySelector('[data-taxonomy-tree-target="name"]').innerHTML = this.buildNameContent(data)
    this.modal.hide()
    window.Turbo.visit(window.location.href)
  }

  modalFields(node) {
    // The dragged/edited node cannot become its own parent, nor a descendant of itself.
    const excludedParentIds = new Set([node.dataset.nodeId, ...[...node.querySelectorAll("[data-node-id]")].map((el) => el.dataset.nodeId)])
    return JSON.parse(this.modalFieldsValue || "[]").map((field) => {
      const id = `taxonomy-edit-${field.name}-${node.dataset.nodeId}`
      const name = field.multiple ? `${this.modelParamValue}[${field.name}][]` : `${this.modelParamValue}[${field.name}]`
      const required = field.required || field.required_unless
      const label = `${field.label}${required ? ' <span class="text-danger" aria-hidden="true">*</span><span class="visually-hidden"> (required)</span>' : ""}`
      if (field.type === "select") {
        const fieldOptions = field.name === "parent_id" ? field.options.filter(([value]) => !excludedParentIds.has(String(value))) : field.options
        const options = fieldOptions.map(([value, label]) => `<option value="${value}">${label}</option>`).join("")
        const multipleAttribute = field.multiple ? " multiple" : ""
        return `<div class="mb-3"><label class="form-label" for="${id}">${label}</label><select class="form-select" id="${id}" name="${name}"${multipleAttribute}${field.required ? " required" : ""}>${options}</select></div>`
      }
      if (field.type === "checkbox") return `<div class="mb-3 form-check"><input type="hidden" name="${name}" value="0"><input class="form-check-input" type="checkbox" id="${id}" name="${name}" value="1"><label class="form-check-label" for="${id}">${label}</label></div>`
      if (field.type === "color") return `<div class="mb-3"><label class="form-label" for="${id}">${label}</label><input type="color" class="form-control form-control-color" id="${id}" name="${name}"${field.required ? " required" : ""}></div>`
      const requiredAttribute = field.required ? " required" : ""
      const input = field.type === "textarea" ? `<textarea class="form-control" id="${id}" name="${name}" rows="4"${requiredAttribute}></textarea>` : `<input class="form-control" id="${id}" name="${name}"${requiredAttribute}>`
      return `<div class="mb-3"><label class="form-label" for="${id}">${label}</label>${input}</div>`
    }).join("")
  }

  populateModalFields(modal, node) {
    const values = { name: node.dataset.name, description: node.dataset.description || "", ...JSON.parse(node.dataset.taxonomyValues || "{}") }
    if (this.hasFieldNameValue) values[this.fieldNameValue] = JSON.parse(node.dataset.taxonomyFieldValue || "null")
    JSON.parse(this.modalFieldsValue || "[]").forEach((field) => {
      const selector = field.multiple ? `[name="${this.modelParamValue}[${field.name}][]"]` : `[name="${this.modelParamValue}[${field.name}]"]${field.type === "checkbox" ? ":not([type='hidden'])" : ""}`
      const input = modal.querySelector(selector)
      if (!input) return
      if (field.type === "checkbox") input.checked = Boolean(values[field.name])
      else if (field.multiple) {
        const selected = (values[field.name] || []).map(String)
        Array.from(input.options).forEach((option) => { option.selected = selected.includes(option.value) })
      } else input.value = values[field.name] || ""
    })
    const symmetric = modal.querySelector(`[name="${this.modelParamValue}[symmetric]"]:not([type='hidden'])`)
    const inverse = modal.querySelector(`[name="${this.modelParamValue}[inverse]"]`)
    if (symmetric && inverse) {
      const updateInverseRequirement = () => { inverse.required = !symmetric.checked }
      symmetric.addEventListener("change", updateInverseRequirement)
      updateInverseRequirement()
    }
  }

  cancel(event) {
    event.preventDefault()
    const item = event.currentTarget.closest(".taxonomy-new")
    if (item) {
      item.remove()
      this.refreshSeparators()
    } else {
      const form = event.currentTarget.closest("form")
      this.restoreName(form)
      form.closest("[data-node-id]").classList.remove("is-editing")
      this.inlineEditor = null
    }
  }

  async create(event) {
    event.preventDefault()
    const form = event.currentTarget
    const response = await this.request(form.dataset.url, "POST", { name: form.name.value, parent_id: form.dataset.parentId })
    if (!response.ok) return
    const data = await response.json()

    if (form.dataset.position !== undefined) {
      // Created at the end of its parent's children server-side; reposition then reload to renumber siblings.
      await this.request(data.url, "PATCH", { parent_id: form.dataset.parentId, position: form.dataset.position })
      window.Turbo.visit(window.location.href)
      return
    }

    form.closest(".taxonomy-new").replaceWith(this.buildNode(data))
    this.refreshSeparators()
  }

  async update(event) {
    event.preventDefault()
    const form = event.currentTarget
    const node = form.closest("[data-node-id]")
    const response = await this.request(node.dataset.updateUrl, "PATCH", { name: form.name.value })
    if (!response.ok) return
    const data = await response.json()
    node.dataset.name = data.name
    this.restoreName(form, data.name)
    node.classList.remove("is-editing")
    this.inlineEditor = null
  }

  async saveInlineEditor() {
    const node = this.inlineEditor
    const form = node?.querySelector("form")
    if (!form) {
      this.inlineEditor = null
      return
    }

    const response = await this.request(node.dataset.updateUrl, "PATCH", { name: form.name.value })
    if (!response.ok) return
    const data = await response.json()
    node.dataset.name = data.name
    this.restoreName(form, data.name)
    node.classList.remove("is-editing")
    this.inlineEditor = null
  }

  async remove(event) {
    event.preventDefault()
    const node = event.currentTarget.closest("[data-node-id]")
    if (!window.confirm(`Delete ${node.dataset.name} and its children?`)) return
    const response = await this.request(node.dataset.updateUrl, "DELETE")
    if (response.ok) {
      node.remove()
      this.refreshSeparators()
    }
  }

  async request(url, method, values = {}) {
    const params = {}
    if (values.name !== undefined) params[`${this.modelParamValue}[name]`] = values.name
    if (values.parent_id !== undefined) params[`${this.modelParamValue}[parent_id]`] = values.parent_id
    if (values.position !== undefined) params[`${this.modelParamValue}[position]`] = values.position
    return fetch(url, {
      method,
      headers: { "Accept": "application/json", "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content },
      body: new URLSearchParams(params)
    })
  }

  childList(node) {
    let list = node.querySelector(":scope > .taxonomy-list")
    if (!list) {
      list = document.createElement("ul")
      list.className = "taxonomy-list list-unstyled ms-4"
      list.dataset.action = "dragover->taxonomy-tree#allowDrop drop->taxonomy-tree#drop"
      list.dataset.dropParentId = node.dataset.nodeId
      // Tag lists created to preview a nesting drop so cleanupDrag can remove them if they end up unused.
      if (this.draggedNode) list.dataset.dragPreview = "true"
      node.append(list)
    }
    return list
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
    node.innerHTML = `<div class="taxonomy-row d-flex align-items-center gap-2 border-bottom py-2"><i class="bi bi-grip-vertical text-body-secondary" aria-hidden="true"></i><span class="flex-grow-1 text-break" data-taxonomy-tree-target="name"></span><span class="taxonomy-actions d-flex gap-1"><button type="button" class="btn btn-sm btn-outline-secondary" title="Add child" aria-label="Add child" data-action="taxonomy-tree#add"><i class="bi bi-plus-lg" aria-hidden="true"></i></button><button type="button" class="btn btn-sm btn-outline-secondary" title="Edit" aria-label="Edit" data-action="taxonomy-tree#edit"><i class="bi bi-pencil" aria-hidden="true"></i></button><button type="button" class="btn btn-sm btn-outline-danger" title="Delete" aria-label="Delete" data-action="taxonomy-tree#remove"><i class="bi bi-trash" aria-hidden="true"></i></button></span></div>`
    node.querySelector('[data-taxonomy-tree-target="name"]').innerHTML = this.buildNameContent(data)
    return node
  }

  restoreName(form, value = form.querySelector("input").value) {
    const node = form.closest("[data-node-id]")
    const values = JSON.parse(node?.dataset.taxonomyValues || "{}")
    const name = document.createElement("span")
    name.className = "flex-grow-1 text-break"
    name.setAttribute("role", "button")
    name.tabIndex = 0
    name.dataset.taxonomyTreeTarget = "name"
    name.dataset.action = "click->taxonomy-tree#editName keydown.enter->taxonomy-tree#editName"
    name.innerHTML = this.buildNameContent({ name: value, color: values.color, description: node?.dataset.description })
    form.replaceWith(name)
  }

  escapeHtml(value) {
    const div = document.createElement("div")
    div.textContent = value ?? ""
    return div.innerHTML
  }

  // Renders a node's name as a badge tinted with its own color, plus its description underneath.
  buildNameContent(data) {
    const name = this.escapeHtml(data.name)
    const badge = data.color ? `<span class="badge text-dark" style="background-color: ${this.escapeHtml(data.color)};">${name}</span>` : name
    const description = data.description ? `<div class="small text-body-secondary text-break">${this.escapeHtml(data.description)}</div>` : ""
    return badge + description
  }

  // Separators sit between every pair of adjacently rendered nodes (regardless of nesting depth)
  // and expose a "+" button to insert a new node at that exact position.
  refreshSeparators() {
    this.element.querySelectorAll(".taxonomy-separator").forEach((el) => el.remove())
    const nodes = [...this.element.querySelectorAll(".taxonomy-node")]
    nodes.slice(1).forEach((node) => node.before(this.buildSeparator()))
  }

  buildSeparator() {
    const separator = document.createElement("li")
    separator.className = "taxonomy-separator"
    separator.innerHTML = `<button type="button" class="taxonomy-separator-add" aria-label="Insert item here" data-action="taxonomy-tree#insertAt"><i class="bi bi-plus-lg" aria-hidden="true"></i></button>`
    return separator
  }

  nextTaxonomyNode(node) {
    let el = node.nextElementSibling
    while (el && !el.matches(".taxonomy-node")) el = el.nextElementSibling
    return el
  }

  startDrag(event) {
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

    // Hovering the top/bottom quarter of a node drops as its sibling (before/after); the middle half nests as its child.
    const row = current.querySelector(":scope > .taxonomy-row")
    const rect = row.getBoundingClientRect()
    const offset = (event.clientY - rect.top) / rect.height
    if (offset < 0.25) {
      this.previewMove(current.parentElement, current, "before")
    } else if (offset > 0.75) {
      this.previewMove(current.parentElement, current, "after")
    } else {
      this.previewMove(this.childList(current), null)
    }
  }

  // Physically relocates the dragged node live so the list opens a gap showing exactly where it will land.
  // `position` is "before"/"after" relative to targetNode; omitted means append to the end of `list`.
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

  // Toggles whether the drop would be a no-op (returns to its original spot) or an actual move.
  updateDragIndicator() {
    const node = this.draggedNode
    if (!node) return
    const isNoop = node.parentElement === this.dragOriginalParent && this.nextTaxonomyNode(node) === this.dragOriginalNext
    node.classList.toggle("taxonomy-node--drop-noop", isNoop)
    node.classList.toggle("taxonomy-node--drop-move", !isNoop)
  }

  async drop(event) {
    event.preventDefault()
    event.stopPropagation()
    if (!this.draggedNode) return
    this.dropHandled = true

    const node = this.draggedNode
    const originalParent = this.dragOriginalParent
    const originalNext = this.dragOriginalNext
    const isNoop = node.parentElement === originalParent && this.nextTaxonomyNode(node) === originalNext
    this.cleanupDrag()
    if (isNoop) return

    const parentId = node.parentElement.dataset.dropParentId || ""
    const position = [...node.parentElement.children].filter((el) => el.matches(".taxonomy-node")).indexOf(node)
    const updateUrl = node.getAttribute("data-update-url")
    const restore = () => { if (originalNext) originalNext.before(node); else originalParent.append(node) }
    if (!updateUrl) { restore(); return }

    const response = await this.request(updateUrl, "PATCH", { parent_id: parentId, position })
    if (response.ok) window.Turbo.visit(window.location.href)
    else restore()
  }

  endDrag() {
    if (!this.draggedNode) return
    if (!this.dropHandled) {
      // Drag ended without a valid drop (e.g. released outside the tree) so put the node back.
      if (this.dragOriginalNext) this.dragOriginalNext.before(this.draggedNode)
      else this.dragOriginalParent.append(this.draggedNode)
    }
    this.cleanupDrag()
  }

  cleanupDrag() {
    if (this.draggedNode) this.draggedNode.classList.remove("taxonomy-node--dragging", "taxonomy-node--drop-noop", "taxonomy-node--drop-move")
    this.element.classList.remove("taxonomy-tree--dragging")
    // Remove any child list created solely to preview nesting that ended up empty (drag moved elsewhere or was cancelled).
    this.element.querySelectorAll('.taxonomy-list[data-drag-preview="true"]').forEach((list) => {
      if (list.children.length === 0) list.remove()
      else delete list.dataset.dragPreview
    })
    this.draggedNode = null
    this.dragOriginalParent = null
    this.dragOriginalNext = null
    this.dropHandled = false
  }
}