import { beforeEach, describe, expect, test } from "bun:test"
import FlashToastController from "../../app/javascript/controllers/flash_toast_controller"

// Auto-dismissing floating toasts for flash messages. The controller reads a
// data attribute on each toast to decide how long it stays, so the tests
// verify the scheduling and the manual-close path without waiting real time.
function build(toasts) {
  const host = document.createElement("div")
  host.innerHTML = `
    <div class="flash-stack" data-controller="flash-toast">
      ${toasts.map((t) => `
        <div class="alert alert-${t.type} alert-dismissible fade show flash-toast"
          role="alert"
          data-flash-toast-type="${t.type}"
          data-flash-toast-delay="${t.delay}">
          ${t.message}
          <button type="button" class="btn-close" data-flash-toast-close aria-label="Close"></button>
        </div>
      `).join("")}
    </div>
  `
  document.body.append(host)

  const container = host.querySelector(".flash-stack")
  const controller = new FlashToastController()
  controller.element = container
  controller.connect()
  return { controller, container, toasts: [...container.querySelectorAll(".flash-toast")] }
}

beforeEach(() => {
  document.body.innerHTML = ""
})

describe("flash toast scheduling", () => {
  test("schedules a success toast with a 4-second delay", () => {
    const { controller } = build([{ type: "success", message: "Saved.", delay: 4000 }])
    expect(controller.timers.size).toBe(1)
  })

  test("schedules an error toast with a 10-second delay", () => {
    const { controller } = build([{ type: "danger", message: "Failed.", delay: 10000 }])
    expect(controller.timers.size).toBe(1)
  })

  test("schedules multiple toasts independently", () => {
    const { controller } = build([
      { type: "success", message: "Saved.", delay: 4000 },
      { type: "danger", message: "Failed.", delay: 10000 }
    ])
    expect(controller.timers.size).toBe(2)
  })
})

describe("flash toast dismiss", () => {
  test("manual close removes the toast and clears its timer", () => {
    const { controller, toasts } = build([{ type: "success", message: "Saved.", delay: 4000 }])
    const toast = toasts[0]
    const closeButton = toast.querySelector("[data-flash-toast-close]")

    closeButton.click()

    expect(toast.isConnected).toBe(false)
    expect(controller.timers.size).toBe(0)
  })

  test("manual close of one toast leaves the other untouched", () => {
    const { controller, toasts } = build([
      { type: "success", message: "Saved.", delay: 4000 },
      { type: "danger", message: "Failed.", delay: 10000 }
    ])
    const closeButton = toasts[0].querySelector("[data-flash-toast-close]")

    closeButton.click()

    expect(toasts[0].isConnected).toBe(false)
    expect(toasts[1].isConnected).toBe(true)
    expect(controller.timers.size).toBe(1)
  })

  test("dismiss removes the toast from the DOM", () => {
    const { controller, toasts } = build([{ type: "danger", message: "Failed.", delay: 10000 }])
    const toast = toasts[0]

    controller.dismiss(toast)

    expect(toast.isConnected).toBe(false)
    expect(controller.timers.size).toBe(0)
  })
})

describe("flash toast disconnect", () => {
  test("disconnect clears all pending timers", () => {
    const { controller } = build([
      { type: "success", message: "Saved.", delay: 4000 },
      { type: "danger", message: "Failed.", delay: 10000 }
    ])
    expect(controller.timers.size).toBe(2)

    controller.disconnect()

    expect(controller.timers.size).toBe(0)
  })
})
