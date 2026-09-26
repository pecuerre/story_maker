import { beforeEach, describe, expect, test } from "bun:test"
import SceneElementFormController from "../../app/javascript/controllers/scene_element_form_controller"

// Narration cannot keep speakers and a Dialogue must name at least one, so the
// speaker picker and the "remove the speakers" confirmation are the same decision
// seen from two sides. This controller only decides which of them the author is
// looking at; the server is what refuses an unconfirmed change.
const DESCRIPTIONS = {
  narration: "Description or action, with no one speaking.",
  dialogue: "A spoken block. Name everyone who speaks in it."
}

function build({ kind = "narration", selected = [] } = {}) {
  const options = selected.map((value) => `<option value="${value}" selected>Character ${value}</option>`).join("")
  const host = document.createElement("div")
  host.innerHTML = `
    <div class="modal">
      <form data-controller="scene-element-form" data-scene-element-form-descriptions-value='${JSON.stringify(DESCRIPTIONS)}'>
        <select data-scene-element-form-target="kind" data-action="change->scene-element-form#sync">
          <option value="narration">Narration</option>
          <option value="dialogue">Dialogue</option>
        </select>
        <div data-scene-element-form-target="kindDescription"></div>
        <fieldset data-scene-element-form-target="speakers">
          <select multiple data-scene-element-form-target="speakerPicker">
            <option value="1">Character 1</option>
            <option value="2">Character 2</option>
            ${options}
          </select>
        </fieldset>
        <div data-scene-element-form-target="removeSpeakers" hidden>
          <input type="checkbox" id="scene_element_remove_speakers" name="scene_element[remove_speakers]" value="1" />
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
  controller.speakersTarget = form.querySelector("[data-scene-element-form-target='speakers']")
  controller.speakerPickerTarget = form.querySelector("[data-scene-element-form-target='speakerPicker']")
  controller.removeSpeakersTarget = form.querySelector("[data-scene-element-form-target='removeSpeakers']")
  controller.descriptionsValue = DESCRIPTIONS
  controller.kindTarget.value = kind
  return { controller, form }
}

beforeEach(() => {
  document.head.innerHTML = ""
  document.body.innerHTML = ""
})

describe("scene element form kind switching", () => {
  test("narration hides the speaker picker and offers no confirmation", () => {
    const { controller } = build({ kind: "narration" })

    controller.sync()

    expect(controller.speakersTarget.hidden).toBe(true)
    expect(controller.removeSpeakersTarget.hidden).toBe(true)
    expect(controller.kindDescriptionTarget.textContent).toBe(DESCRIPTIONS.narration)
  })

  test("dialogue shows the speaker picker and still offers no confirmation", () => {
    const { controller } = build({ kind: "dialogue" })

    controller.sync()

    expect(controller.speakersTarget.hidden).toBe(false)
    expect(controller.removeSpeakersTarget.hidden).toBe(true)
    expect(controller.kindDescriptionTarget.textContent).toBe(DESCRIPTIONS.dialogue)
  })

  test("switching a dialogue with speakers to narration asks for the confirmation", () => {
    const { controller, form } = build({ kind: "dialogue", selected: [ "1", "2" ] })

    controller.sync()
    controller.kindTarget.value = "narration"
    controller.sync()

    expect(controller.speakersTarget.hidden).toBe(true)
    expect(controller.removeSpeakersTarget.hidden).toBe(false)
    expect(form.querySelector("#scene_element_remove_speakers")).not.toBeNull()
  })

  test("narration with nothing selected offers no confirmation to give", () => {
    const { controller } = build({ kind: "narration" })

    controller.sync()

    expect(controller.removeSpeakersTarget.hidden).toBe(true)
  })

  test("the hidden picker keeps its selection so the server can see it", () => {
    const { controller } = build({ kind: "dialogue", selected: [ "1" ] })
    controller.sync()
    controller.kindTarget.value = "narration"
    controller.sync()

    // Hiding is not disabling: a disabled control would drop the value from the
    // payload, and the server could no longer tell that there is something to
    // confirm.
    expect(controller.speakerPickerTarget.disabled).toBe(false)
    expect([ ...controller.speakerPickerTarget.selectedOptions ].map((option) => option.value)).toEqual([ "1" ])
  })

  test("an unknown kind still describes itself and hides the picker", () => {
    const { controller } = build({ kind: "narration" })

    controller.kindTarget.value = "aside"
    controller.sync()

    expect(controller.speakersTarget.hidden).toBe(true)
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
