import { Controller } from "@hotwired/stimulus"

// The Narrative order chart. The server draws both columns, every bar, and every
// connector, so the picture is complete before this controller connects. It only
// says which Scene is under the pointer or the keyboard: that Scene's two bars and
// its connector stand out of the dimmed field and its facts appear in the detail
// panel. A bar never moves, and no text is built here.
//
// Leaving the chart returns the lines to their quiet resting state and keeps the
// last Scene's facts in the panel, so the panel does not flicker back to an
// arbitrary Scene while the pointer crosses the gap between the columns.
export default class extends Controller {
  highlight(event) {
    this.activate(event.currentTarget.dataset.narrativeChartScene)
  }

  clear(event) {
    // Focus moving inside the chart (from one bar to the next) is not leaving it.
    if (event.type === "focusout" && this.element.contains(event.relatedTarget)) {
      return
    }

    this.deactivate()
  }

  activate(sceneId) {
    this.each("[data-narrative-chart-scene]", (element) => {
      element.classList.toggle(
        "is-active",
        element.dataset.narrativeChartScene === sceneId
      )
    })

    this.each("[data-narrative-chart-edge]", (element) => {
      const active = element.dataset.narrativeChartEdge === sceneId
      element.classList.toggle("is-active", active)
      element.classList.toggle("is-muted", !active)
    })

    this.each("[data-narrative-chart-detail]", (element) => {
      element.hidden = element.dataset.narrativeChartDetail !== sceneId
    })
  }

  deactivate() {
    this.each("[data-narrative-chart-scene]", (element) => {
      element.classList.remove("is-active")
    })

    this.each("[data-narrative-chart-edge]", (element) => {
      element.classList.remove("is-active")
      element.classList.remove("is-muted")
    })
  }

  each(selector, callback) {
    this.element.querySelectorAll(selector).forEach(callback)
  }
}
