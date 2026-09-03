import { Controller } from "@hotwired/stimulus"
import "bootstrap"

export default class extends Controller {
  static values = { modelParam: String, createUrl: String }

  connect() {
    this.handleOutsideClick = this.handleOutsideClick.bind(this)
    document.addEventListener("pointerdown", this.handleOutsideClick)
  }

  disconnect() {
    document.removeEventListener("pointerdown", this.handleOutsideClick)
  }

  add(event) {
    event.preventDefault()
    const source = event.currentTarget
    const parentNode = source.closest("[data-node-id]")
    const list = parentNode ? this.childList(parentNode) : this.element.querySelector(":scope > .taxonomy-list")
    if (list.querySelector(":scope > .taxonomy-new")) return

    const item = document.createElement("li")
    item.className = "taxonomy-node taxonomy-new"
    item.innerHTML = `<div class="d-flex align-items-center gap-2 border-bottom py-2"><i class="bi bi-grip-vertical text-body-secondary" aria-hidden="true"></i><form class="d-flex flex-grow-1 gap-2" data-action="submit->taxonomy-tree#create"><input class="form-control form-control-sm" name="name" aria-label="New name" required><button type="submit" class="btn btn-sm btn-primary">Save</button><button type="button" class="btn btn-sm btn-outline-secondary" data-action="taxonomy-tree#cancel">Cancel</button></form></div>`
    item.querySelector("form").dataset.url = parentNode?.dataset.createUrl || this.createUrlValue
    item.querySelector("form").dataset.parentId = parentNode?.dataset.nodeId || ""
    list.append(item)
    item.querySelector("input").focus()
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
    modal.innerHTML = `<div class="modal-dialog"><div class="modal-content"><div class="modal-header"><h1 class="modal-title fs-5" id="${titleId}"></h1><button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button></div><form action="${node.dataset.updateUrl}" method="post"><div class="modal-body"><div class="mb-3"><label class="form-label" for="taxonomy-edit-name-${node.dataset.nodeId}">Name</label><input class="form-control" id="taxonomy-edit-name-${node.dataset.nodeId}" name="${this.modelParamValue}[name]" required></div><div><label class="form-label" for="taxonomy-edit-description-${node.dataset.nodeId}">Description</label><textarea class="form-control" id="taxonomy-edit-description-${node.dataset.nodeId}" name="${this.modelParamValue}[description]" rows="4"></textarea></div></div><div class="modal-footer"><button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button><button type="submit" class="btn btn-primary">Save changes</button></div></form></div></div>`
    modal.querySelector(".modal-title").textContent = `Edit ${node.dataset.name}`
    modal.querySelector('[name$="[name]"]').value = node.dataset.name
    modal.querySelector('[name$="[description]"]').value = node.dataset.description || ""
    modal.querySelector("form").addEventListener("submit", (submitEvent) => this.updateDetails(submitEvent, node))
    document.body.append(modal)

    this.modal = new window.bootstrap.Modal(modal)
    modal.addEventListener("hidden.bs.modal", () => {
      this.modal.dispose()
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
    node.querySelector('[data-taxonomy-tree-target="name"]').textContent = data.name
    this.modal.hide()
    window.Turbo.visit(window.location.href)
  }

  cancel(event) {
    event.preventDefault()
    const item = event.currentTarget.closest(".taxonomy-new")
    if (item) item.remove()
    else {
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
    form.closest(".taxonomy-new").replaceWith(this.buildNode(data))
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
    if (response.ok) node.remove()
  }

  async request(url, method, values = {}) {
    const params = {}
    if (values.name !== undefined) params[`${this.modelParamValue}[name]`] = values.name
    if (values.parent_id !== undefined) params[`${this.modelParamValue}[parent_id]`] = values.parent_id

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
      node.append(list)
    }
    return list
  }

  buildNode(data) {
    const node = document.createElement("li")
    node.className = "taxonomy-node"
    node.draggable = true
    node.dataset.taxonomyTreeTarget = "node"
    node.dataset.nodeId = data.id
    node.dataset.updateUrl = data.url
    node.dataset.createUrl = this.createUrlValue
    node.dataset.name = data.name
    node.dataset.description = data.description || ""
    node.innerHTML = `<div class="taxonomy-row d-flex align-items-center gap-2 border-bottom py-2" data-action="dragstart->taxonomy-tree#startDrag dragover->taxonomy-tree#allowDrop drop->taxonomy-tree#moveNode"><i class="bi bi-grip-vertical text-body-secondary" aria-hidden="true"></i><span class="flex-grow-1 text-break" data-taxonomy-tree-target="name"></span><span class="taxonomy-actions d-flex gap-1"><button type="button" class="btn btn-sm btn-outline-secondary" title="Add child" aria-label="Add child" data-action="taxonomy-tree#add"><i class="bi bi-plus-lg" aria-hidden="true"></i></button><button type="button" class="btn btn-sm btn-outline-secondary" title="Edit" aria-label="Edit" data-action="taxonomy-tree#edit"><i class="bi bi-pencil" aria-hidden="true"></i></button><button type="button" class="btn btn-sm btn-outline-danger" title="Delete" aria-label="Delete" data-action="taxonomy-tree#remove"><i class="bi bi-trash" aria-hidden="true"></i></button></span></div>`
    node.querySelector('[data-taxonomy-tree-target="name"]').textContent = data.name
    return node
  }

  restoreName(form, value = form.querySelector("input").value) {
    const name = document.createElement("span")
    name.className = "flex-grow-1 text-break"
    name.setAttribute("role", "button")
    name.tabIndex = 0
    name.dataset.taxonomyTreeTarget = "name"
    name.dataset.action = "click->taxonomy-tree#editName keydown.enter->taxonomy-tree#editName"
    name.textContent = value
    form.replaceWith(name)
  }

  startDrag(event) {
    this.draggedNode = event.currentTarget.closest("[data-node-id]")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.draggedNode.dataset.nodeId)
  }

  allowDrop(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
  }

  async moveNode(event) {
    event.preventDefault()
    const targetNode = event.currentTarget.closest("[data-node-id]")
    if (!this.draggedNode || !targetNode || this.draggedNode === targetNode) return

    const response = await fetch(this.draggedNode.dataset.updateUrl, {
      method: "PATCH",
      headers: {
        "Accept": "text/vnd.turbo-stream.html, text/html",
        "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      },
      body: new URLSearchParams({
        [`${this.modelParamValue}[parent_id]`]: targetNode.dataset.nodeId,
        [`${this.modelParamValue}[position]`]: targetNode.querySelector(":scope > .taxonomy-list")?.children.length || 0
      })
    })

    if (response.ok) window.Turbo.visit(window.location.href)
  }
}