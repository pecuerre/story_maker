import { Controller } from "@hotwired/stimulus"
import "bootstrap"

// Draws arrows between event nodes on the Timeline view: a solid arrow for
// "happens before/after" relations, and a dashed double-headed line for
// events marked as happening at the same time. Each node also shows a
// Bootstrap popover with event details on hover.
export default class extends Controller {
  static targets = ["svg", "track", "node"]
  static values = { edges: Array }

  connect() {
    this.redraw = this.draw.bind(this)
    window.addEventListener("resize", this.redraw)

    if (this.hasTrackTarget && "ResizeObserver" in window) {
      this.resizeObserver = new ResizeObserver(this.redraw)
      this.resizeObserver.observe(this.trackTarget)
    }

    this.popovers = this.nodeTargets.map((node) => new window.bootstrap.Popover(node))

    requestAnimationFrame(this.redraw)
  }

  disconnect() {
    window.removeEventListener("resize", this.redraw)
    this.resizeObserver?.disconnect()
    this.popovers?.forEach((popover) => popover.dispose())
  }

  draw() {
    if (!this.hasSvgTarget || !this.hasTrackTarget) return

    const svg = this.svgTarget
    const trackRect = this.trackTarget.getBoundingClientRect()

    svg.setAttribute("width", trackRect.width)
    svg.setAttribute("height", trackRect.height)
    svg.innerHTML = this.markerDefs()

    this.edgesValue.forEach((edge) => {
      const fromEl = document.getElementById(`timeline-event-${edge.from}`)
      const toEl = document.getElementById(`timeline-event-${edge.to}`)
      if (!fromEl || !toEl) return

      const fromRect = fromEl.getBoundingClientRect()
      const toRect = toEl.getBoundingClientRect()

      const x1 = fromRect.left + fromRect.width / 2 - trackRect.left
      const y1 = fromRect.top + fromRect.height / 2 - trackRect.top
      const x2 = toRect.left + toRect.width / 2 - trackRect.left
      const y2 = toRect.top + toRect.height / 2 - trackRect.top

      svg.appendChild(this.buildLine(x1, y1, x2, y2, edge.kind))
    })
  }

  buildLine(x1, y1, x2, y2, kind) {
    const line = document.createElementNS("http://www.w3.org/2000/svg", "line")
    line.setAttribute("x1", x1)
    line.setAttribute("y1", y1)
    line.setAttribute("x2", x2)
    line.setAttribute("y2", y2)

    if (kind === "simultaneous") {
      line.setAttribute("class", "timeline-edge timeline-edge-simultaneous")
      line.setAttribute("marker-start", "url(#timeline-arrow-simultaneous)")
      line.setAttribute("marker-end", "url(#timeline-arrow-simultaneous)")
    } else {
      line.setAttribute("class", "timeline-edge timeline-edge-sequence")
      line.setAttribute("marker-end", "url(#timeline-arrow-sequence)")
    }

    return line
  }

  markerDefs() {
    return `
      <defs>
        <marker id="timeline-arrow-sequence" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
          <path d="M 0 0 L 10 5 L 0 10 z" class="timeline-arrow-head timeline-arrow-head-sequence"></path>
        </marker>
        <marker id="timeline-arrow-simultaneous" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
          <path d="M 0 0 L 10 5 L 0 10 z" class="timeline-arrow-head timeline-arrow-head-simultaneous"></path>
        </marker>
      </defs>
    `
  }
}
