import { beforeEach, describe, expect, test } from "bun:test"
import NarrativeChartController from "../../app/javascript/controllers/narrative_chart_controller"

// The Narrative order chart. The server draws every bar, line, and detail card;
// this controller only lifts the Scene under the pointer or the keyboard out of
// the field. It must never move a bar, and leaving the chart must keep the last
// Scene's facts instead of blanking the panel.
function build() {
  const host = document.createElement("div")
  host.innerHTML = `
    <div data-controller="narrative-chart">
      <a data-narrative-chart-scene="1"></a>
      <a data-narrative-chart-scene="1" tabindex="-1"></a>
      <a data-narrative-chart-scene="2"></a>
      <line data-narrative-chart-edge="1"></line>
      <line data-narrative-chart-edge="2"></line>
      <div data-narrative-chart-detail="1"></div>
      <div data-narrative-chart-detail="2" hidden></div>
    </div>
  `
  document.body.append(host)

  const root = host.querySelector("[data-controller]")
  const controller = new NarrativeChartController()
  controller.element = root

  return { controller, root }
}

const nodes = (root, id) =>
  [ ...root.querySelectorAll(`[data-narrative-chart-scene="${id}"]`) ]
const edge = (root, id) =>
  root.querySelector(`[data-narrative-chart-edge="${id}"]`)
const detail = (root, id) =>
  root.querySelector(`[data-narrative-chart-detail="${id}"]`)
const active = (element) => element.classList.contains("is-active")
const muted = (element) => element.classList.contains("is-muted")

beforeEach(() => {
  document.body.innerHTML = ""
})

describe("highlighting one scene", () => {
  test("both of a scene's bars and its own connector stand out", () => {
    const { controller, root } = build()

    controller.highlight({ currentTarget: nodes(root, "1")[0] })

    expect(nodes(root, "1").every(active)).toBe(true)
    expect(nodes(root, "2").some(active)).toBe(false)
    expect(active(edge(root, "1"))).toBe(true)
    expect(active(edge(root, "2"))).toBe(false)
    expect(muted(edge(root, "2"))).toBe(true)
    expect(muted(edge(root, "1"))).toBe(false)
  })

  test("the highlighted scene's facts replace the shown card", () => {
    const { controller, root } = build()

    expect(detail(root, "1").hidden).toBe(false)
    expect(detail(root, "2").hidden).toBe(true)

    controller.highlight({ currentTarget: nodes(root, "2")[0] })

    expect(detail(root, "1").hidden).toBe(true)
    expect(detail(root, "2").hidden).toBe(false)
  })

  test("a right-hand bar highlights the same scene", () => {
    const { controller, root } = build()

    controller.highlight({ currentTarget: nodes(root, "1")[1] })

    expect(nodes(root, "1").every(active)).toBe(true)
    expect(active(edge(root, "1"))).toBe(true)
    expect(detail(root, "1").hidden).toBe(false)
  })
})

describe("returning to the resting state", () => {
  test("leaving clears the highlight but keeps the last facts", () => {
    const { controller, root } = build()

    controller.highlight({ currentTarget: nodes(root, "2")[0] })
    controller.clear({ type: "pointerleave" })

    expect(nodes(root, "2").some(active)).toBe(false)
    expect(active(edge(root, "2"))).toBe(false)
    expect(muted(edge(root, "1"))).toBe(false)
    expect(muted(edge(root, "2"))).toBe(false)
    expect(detail(root, "2").hidden).toBe(false)
  })

  test("focus moving inside the chart does not clear the highlight", () => {
    const { controller, root } = build()

    controller.highlight({ currentTarget: nodes(root, "1")[0] })
    controller.clear({
      type: "focusout",
      relatedTarget: nodes(root, "2")[0]
    })

    expect(nodes(root, "1").every(active)).toBe(true)
  })

  test("focus leaving the chart clears the highlight", () => {
    const { controller, root } = build()

    controller.highlight({ currentTarget: nodes(root, "1")[0] })
    controller.clear({ type: "focusout", relatedTarget: document.body })

    expect(nodes(root, "1").some(active)).toBe(false)
  })
})
