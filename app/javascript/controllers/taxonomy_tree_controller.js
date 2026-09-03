import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { modelParam: String, createUrl: String }

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

  editName(event) {
    event.preventDefault()
    const node = event.currentTarget.closest("[data-node-id]")
    if (node.querySelector("input")) return
    const name = node.querySelector('[data-taxonomy-tree-target="name"]')
    const form = document.createElement("form")
    form.className = "d-flex flex-grow-1 gap-2"
    form.dataset.action = "submit->taxonomy-tree#update"
    form.innerHTML = `<input class="form-control form-control-sm" name="name" value="" required><button type="submit" class="btn btn-sm btn-primary">Save</button><button type="button" class="btn btn-sm btn-outline-secondary" data-action="taxonomy-tree#cancel">Cancel</button>`
    form.querySelector("input").value = node.dataset.name
    name.replaceWith(form)
    form.querySelector("input").focus()
    form.querySelector("input").select()
  }

  async edit(event) {
    event.preventDefault()
    const node = event.currentTarget.closest("[data-node-id]")
    if (this.dialog) return

    const response = await fetch(node.dataset.editUrl, { headers: { "Accept": "text/html" } })
    if (!response.ok) return
    const page = new DOMParser().parseFromString(await response.text(), "text/html")
    const form = page.querySelector("form")
    if (!form) return

    form.querySelector('[name$="[name]"]')?.closest("div")?.remove()
    form.addEventListener("submit", (submitEvent) => this.updateDetails(submitEvent, node))

    this.dialog = window.document.createElement("dialog")
    this.dialog.className = "taxonomy-edit-dialog"
    this.dialog.innerHTML = `<div class="d-flex justify-content-between align-items-center mb-3"><h2 class="h5 mb-0">Edit ${node.dataset.name}</h2><button type="button" class="btn-close" aria-label="Close"></button></div>`
    this.dialog.append(form)
    const cancel = this.dialog.querySelector(".btn-close")
    cancel.addEventListener("click", () => this.dialog.close())
    window.document.body.append(this.dialog)
    this.dialog.addEventListener("close", () => {
      this.dialog.remove()
      this.dialog = null
    }, { once: true })
    this.dialog.showModal()
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
    this.dialog.close()
    window.Turbo.visit(window.location.href)
  }

  cancel(event) {
    event.preventDefault()
    const item = event.currentTarget.closest(".taxonomy-new")
    if (item) item.remove()
    else this.restoreName(event.currentTarget.closest("form"))
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
    node.innerHTML = `<div class="d-flex align-items-center gap-2 border-bottom py-2" data-action="dragstart->taxonomy-tree#startDrag dragover->taxonomy-tree#allowDrop drop->taxonomy-tree#moveNode"><i class="bi bi-grip-vertical text-body-secondary" aria-hidden="true"></i><span class="flex-grow-1 text-break" data-taxonomy-tree-target="name"></span><span class="taxonomy-actions d-flex gap-1"><button type="button" class="btn btn-sm btn-outline-secondary" title="Add child" aria-label="Add child" data-action="taxonomy-tree#add"><i class="bi bi-plus-lg" aria-hidden="true"></i></button><button type="button" class="btn btn-sm btn-outline-secondary" title="Edit" aria-label="Edit" data-action="taxonomy-tree#edit"><i class="bi bi-pencil" aria-hidden="true"></i></button><button type="button" class="btn btn-sm btn-outline-danger" title="Delete" aria-label="Delete" data-action="taxonomy-tree#remove"><i class="bi bi-trash" aria-hidden="true"></i></button></span></div>`
    node.querySelector('[data-taxonomy-tree-target="name"]').textContent = data.name
    return node
  }

  restoreName(form, value = form.querySelector("input").value) {
    const name = document.createElement("span")
    name.className = "flex-grow-1 text-break"
    name.dataset.taxonomyTreeTarget = "name"
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