import { beforeEach, describe, expect, test } from "bun:test"
import SceneElementFormController from "../../app/javascript/controllers/scene_element_form_controller"

// Narration keeps its prose in Content and Dialogue keeps it in ordered turns,
// so this controller only decides which control the author is looking at. The
// server refuses a Narration that still has turns.
const DESCRIPTIONS = {
  narration: "Description or action, with no one speaking.",
  dialogue: "A spoken block, written as ordered lines."
}

function build({ kind = "narration" } = {}) {
  const host = document.createElement("div")
  host.innerHTML = `
    <div class="modal">
      <form data-controller="scene-element-form" data-scene-element-form-descriptions-value='${JSON.stringify(DESCRIPTIONS)}'>
        <select data-scene-element-form-target="kind" data-action="change->scene-element-form#sync">
          <option value="narration">Narration</option>
          <option value="dialogue">Dialogue</option>
        </select>
        <div data-scene-element-form-target="kindDescription"></div>
        <div data-scene-element-form-target="body">
          <textarea name="scene_element[body]"></textarea>
        </div>
      </form>
    </div>
  `
  document.body.append(host)

  const form = host.querySelector("form")
  const controller = new SceneElementFormController()
  controller.element = form
  controller.kindTarget = form.querySelector("[data-scene-element-form-target='kind']")
  controller.kindDescriptionTarget = form.querySelector("[data-scene-element-form-target='kindDescription']")
  controller.bodyTarget = form.querySelector("[data-scene-element-form-target='body']")
  controller.descriptionsValue = DESCRIPTIONS
  controller.kindTarget.value = kind
  return { controller, form }
}

beforeEach(() => {
  document.head.innerHTML = ""
  document.body.innerHTML = ""
})

describe("scene element form kind switching", () => {
  test("narration shows Content and describes itself", () => {
    const { controller } = build({ kind: "narration" })

    controller.sync()

    expect(controller.bodyTarget.hidden).toBe(false)
    expect(controller.kindDescriptionTarget.textContent).toBe(DESCRIPTIONS.narration)
  })

  test("dialogue hides Content and describes itself", () => {
    const { controller } = build({ kind: "dialogue" })

    controller.sync()

    expect(controller.bodyTarget.hidden).toBe(true)
    expect(controller.kindDescriptionTarget.textContent).toBe(DESCRIPTIONS.dialogue)
  })

  test("switching kinds shows the control the new kind uses", () => {
    const { controller } = build({ kind: "narration" })

    controller.sync()
    controller.kindTarget.value = "dialogue"
    controller.sync()
    expect(controller.bodyTarget.hidden).toBe(true)

    controller.kindTarget.value = "narration"
    controller.sync()
    expect(controller.bodyTarget.hidden).toBe(false)
  })

  test("an unknown kind still describes itself", () => {
    const { controller } = build({ kind: "narration" })

    controller.kindTarget.value = "aside"
    controller.sync()

    expect(controller.bodyTarget.hidden).toBe(false)
    expect(controller.kindDescriptionTarget.textContent).toBe("")
  })

  test("reopening the modal re-syncs, because the editor fills the kind in between", () => {
    const { controller, form } = build({ kind: "narration" })
    const modal = form.closest(".modal")
    let syncs = 0
    controller.sync = () => { syncs += 1 }
    controller.modal = modal
    controller.handleShown = () => controller.sync()
    controller.connect()
    syncs = 0

    modal.dispatchEvent(new Event("shown.bs.modal"))
    expect(syncs).toBe(1)

    controller.disconnect()
    modal.dispatchEvent(new Event("shown.bs.modal"))
    expect(syncs).toBe(1)
  })
})
