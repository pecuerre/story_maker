import { Controller } from "@hotwired/stimulus"
import "bootstrap"

export default class extends Controller {
  static targets = ["modal", "title", "form"]
  static values = { createTitle: String, modelParam: String }

  connect() {
    this.modal = new window.bootstrap.Modal(this.modalTarget)
  }

  disconnect() {
    this.modal.dispose()
  }

  open(event) {
    event.preventDefault()
    const trigger = event.currentTarget
    const values = JSON.parse(trigger.dataset.modalFormValuesValue || "{}")

    this.titleTarget.textContent = trigger.dataset.modalFormTitle || this.createTitleValue
    this.formTarget.action = trigger.dataset.modalFormUrl
    this.setMethod(trigger.dataset.modalFormMethod || "post")
    this.formTarget.reset()

    Object.entries(values).forEach(([name, value]) => {
      const fieldName = `${this.modelParamValue}[${name}]`
      const field = this.formTarget.elements.namedItem(fieldName) || this.formTarget.elements.namedItem(`${fieldName}[]`)
      if (!field) return

      if (Array.isArray(value) && field.multiple) {
        const selected = value.map(String)
        Array.from(field.options).forEach((option) => { option.selected = selected.includes(option.value) })
      } else {
        field.value = value
      }
    })

    this.modal.show()
  }

  setMethod(method) {
    let methodField = this.formTarget.querySelector("input[name='_method']")
    if (method.toLowerCase() === "post") {
      methodField?.remove()
      this.formTarget.method = "post"
      return
    }

    if (!methodField) {
      methodField = document.createElement("input")
      methodField.type = "hidden"
      methodField.name = "_method"
      this.formTarget.append(methodField)
    }
    methodField.value = method
    this.formTarget.method = "post"
  }
}
