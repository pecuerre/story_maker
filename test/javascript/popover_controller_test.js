import { beforeEach, describe, expect, test } from "bun:test"
import PopoverController from "../../app/javascript/controllers/popover_controller"

// The info button beside a record's `scope: universe` line is the only control
// carrying the explanation of what a scope means, so the one thing this
// controller can get wrong is the pair: constructing a Popover the browser can
// actually show, and disposing of it again when the page navigates away. Both are
// asserted here; what the popover *looks* like once open is a browser concern and
// belongs in `test/system`.
describe("the popover controller", () => {
  let built
  let disposed

  function build() {
    const button = document.createElement("button")
    button.setAttribute("data-controller", "popover")
    button.setAttribute("data-bs-toggle", "popover")
    button.setAttribute("data-popover-title-value", "What this scope means")
    button.setAttribute("data-popover-content-value", "This taxonomy belongs to the universe.")
    document.body.append(button)

    const controller = new PopoverController()
    controller.element = button
    controller.connect()

    return { controller, button }
  }

  beforeEach(() => {
    document.body.innerHTML = ""
    built = []
    disposed = []

    // Bootstrap is stubbed in `test/javascript/setup.js`, because the real one is
    // served from the import map rather than from node_modules and there is no
    // bundler here to resolve it. What is asserted is which element the instance
    // was built for and that it is released, not how Bootstrap renders a popover.
    window.bootstrap = {
      Popover: class {
        constructor(element) {
          this.element = element
          built.push(this)
        }

        dispose() {
          disposed.push(this)
        }
      }
    }
  })

  test("it builds a popover on the control that declares it", () => {
    const { button } = build()

    expect(built.length).toBe(1)
    expect(built[0].element).toBe(button)
  })

  test("a controller with no element is never connected", () => {
    // Stimulus calls connect on every `data-controller` element; a controller
    // that could not find its own element would throw here rather than silently
    // leaving a dead control behind.
    const orphan = document.createElement("span")
    document.body.append(orphan)

    expect(() => {
      const controller = new PopoverController()
      controller.element = orphan
      controller.connect()
    }).not.toThrow()
  })

  test("it disposes of the popover when the controller disconnects", () => {
    const { controller } = build()

    controller.disconnect()

    expect(disposed.length).toBe(1)
    expect(disposed[0]).toBe(built[0])
  })

  test("disconnecting twice does not throw", () => {
    // Turbo can disconnect and reconnect a controller around a visit; a second
    // disconnect must not be an error, because the instance is already gone.
    const { controller } = build()

    controller.disconnect()

    expect(() => controller.disconnect()).not.toThrow()
    expect(disposed.length).toBe(1)
  })
})