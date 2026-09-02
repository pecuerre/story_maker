import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { modelParam: String }

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
        [`${this.modelParamValue}[parent_id]`]: targetNode.dataset.nodeId
      })
    })

    if (response.ok) window.Turbo.visit(window.location.href)
  }
}