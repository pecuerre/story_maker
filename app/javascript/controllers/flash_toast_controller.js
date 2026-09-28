import { Controller } from "@hotwired/stimulus"

// Auto-dismissing floating toast notifications for flash messages.
//
// Success toasts disappear after 4 seconds; error toasts after 10 seconds.
// A manual close button clears the timer and removes the toast immediately.
// The container is rendered only when flash messages exist, so this controller
// only connects when there is work to do.
export default class extends Controller {
  static values = {
    successDelay: { type: Number, default: 4000 },
    errorDelay: { type: Number, default: 10000 }
  }

  connect() {
    this.timers = new Map()
    this.element.querySelectorAll("[data-flash-toast-type]").forEach((toast) => {
      this.scheduleDismiss(toast)
    })
  }

  disconnect() {
    this.timers.forEach((timer) => {
      clearTimeout(timer)
    })
    this.timers.clear()
  }

  scheduleDismiss(toast) {
    const type = toast.dataset.flashToastType
    const delay = type === "success" ? this.successDelayValue : this.errorDelayValue
    const timer = setTimeout(() => this.dismiss(toast), delay)
    this.timers.set(toast, timer)

    const closeButton = toast.querySelector("[data-flash-toast-close]")
    if (closeButton) {
      closeButton.addEventListener("click", () => this.dismiss(toast))
    }
  }

  dismiss(toast) {
    const timer = this.timers.get(toast)
    if (timer) {
      clearTimeout(timer)
      this.timers.delete(toast)
    }
    toast.remove()
  }
}
