import { beforeEach, describe, expect, test } from "bun:test"
import TimelineController from "../../app/javascript/controllers/timeline_controller"

// The Timeline view draws its edges itself, so the drawn geometry is the only
// thing a client can get wrong here. Every node is found by id in the
// server-rendered view, which is why an edge whose node is missing must be
// skipped instead of throwing.
function build(edges) {
  const host = document.createElement("div")
  host.innerHTML = `
    <svg data-timeline-target="svg"></svg>
    <div data-timeline-target="track">
      <button id="timeline-event-1">one</button>
      <button id="timeline-event-2">two</button>
    </div>
  `
  document.body.append(host)

  const rect = (left, top, width, height) => ({ left, top, width, height, right: left + width, bottom: top + height })
  host.querySelector("[data-timeline-target='track']").getBoundingClientRect = () => rect(0, 0, 800, 200)
  host.querySelector("#timeline-event-1").getBoundingClientRect = () => rect(100, 20, 40, 40)
  host.querySelector("#timeline-event-2").getBoundingClientRect = () => rect(500, 120, 40, 40)

  const controller = new TimelineController()
  controller.element = host
  controller.edgesValue = edges
  controller.hasSvgTarget = true
  controller.svgTarget = host.querySelector("svg")
  controller.hasTrackTarget = true
  controller.trackTarget = host.querySelector("[data-timeline-target='track']")
  return { controller, host, svg: controller.svgTarget }
}

beforeEach(() => {
  document.body.innerHTML = ""
})

describe("timeline drawing", () => {
  test("a sequence edge is a solid arrow from the first node to the second", () => {
    const { controller, svg } = build([ { from: 1, to: 2, kind: "sequence" } ])

    controller.draw()

    expect(svg.getAttribute("width")).toBe("800")
    expect(svg.getAttribute("height")).toBe("200")
    const line = svg.querySelector("line")
    expect(line.getAttribute("x1")).toBe("120")
    expect(line.getAttribute("y1")).toBe("40")
    expect(line.getAttribute("x2")).toBe("520")
    expect(line.getAttribute("y2")).toBe("140")
    expect(line.getAttribute("class")).toBe("timeline-edge timeline-edge-sequence")
    expect(line.getAttribute("marker-end")).toBe("url(#timeline-arrow-sequence)")
    expect(line.getAttribute("marker-start")).toBeNull()
  })

  test("a simultaneous edge is drawn at both ends", () => {
    const { controller, svg } = build([ { from: 2, to: 1, kind: "simultaneous" } ])

    controller.draw()

    const line = svg.querySelector("line")
    expect(line.getAttribute("class")).toBe("timeline-edge timeline-edge-simultaneous")
    expect(line.getAttribute("marker-start")).toBe("url(#timeline-arrow-simultaneous)")
    expect(line.getAttribute("marker-end")).toBe("url(#timeline-arrow-simultaneous)")
  })

  test("an edge whose node is not on the page is skipped", () => {
    const { controller, svg } = build([
      { from: 1, to: 99, kind: "sequence" },
      { from: 98, to: 2, kind: "sequence" },
      { from: 1, to: 2, kind: "sequence" }
    ])

    controller.draw()

    expect(svg.querySelectorAll("line")).toHaveLength(1)
  })

  test("a redraw replaces the previous edges instead of stacking them", () => {
    const { controller, svg } = build([ { from: 1, to: 2, kind: "sequence" } ])

    controller.draw()
    controller.draw()

    expect(svg.querySelectorAll("line")).toHaveLength(1)
    expect(svg.querySelectorAll("defs")).toHaveLength(1)
  })

  test("the arrow markers are a static string, never interpolated data", () => {
    const { controller } = build([])

    expect(controller.markerDefs()).toContain('<marker id="timeline-arrow-sequence"')
    expect(controller.markerDefs()).toContain('<marker id="timeline-arrow-simultaneous"')
    expect(controller.markerDefs()).not.toContain("${")
  })

  test("a page without the drawn targets draws nothing and does not throw", () => {
    const controller = new TimelineController()
    controller.hasSvgTarget = false
    controller.hasTrackTarget = false

    expect(() => controller.draw()).not.toThrow()
  })
})
