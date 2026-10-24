import { beforeEach, describe, expect, test } from "bun:test"
import SceneTurnsController from "../../app/javascript/controllers/scene_turns_controller"

const SPEAKER_CHOICES = [ [ "Ada", 11 ], [ "Bea", 12 ] ]
const TURN = {
  id: 7,
  speaker_id: 11,
  speaker_name: "Ada",
  body: "Hello.",
  parenthetical: "quietly",
  position: 0,
  update_url: "/turns/7",
  move_up_url: "/turns/7/move?direction=up",
  move_down_url: "/turns/7/move?direction=down",
  destroy_url: "/turns/7"
}

function build({ kind = "narration", turns = [], createUrl = "/turns" } = {}) {
  const host = document.createElement("div")
  const form = document.createElement("form")
  const kindSelect = document.createElement("select")
  kindSelect.name = "scene_element[kind]"
  for (const value of [ "narration", "dialogue" ]) {
    const option = document.createElement("option")
    option.value = value
    option.textContent = value
    kindSelect.append(option)
  }
  kindSelect.value = kind
  form.append(kindSelect)

  const turnsList = document.createElement("div")
  const turnsHeading = document.createElement("h3")
  const emptyState = document.createElement("div")
  const saveFirst = document.createElement("p")
  const speakerSelect = document.createElement("select")
  const bodyField = document.createElement("textarea")
  const parentheticalField = document.createElement("input")
  const addButton = document.createElement("button")
  for (const [ target, element ] of [
    [ "kindSelect", kindSelect ], [ "turns", turnsList ], [ "turnsHeading", turnsHeading ], [ "emptyState", emptyState ],
    [ "saveFirst", saveFirst ], [ "speakerSelect", speakerSelect ], [ "bodyField", bodyField ],
    [ "parentheticalField", parentheticalField ], [ "addButton", addButton ]
  ]) {
    element.dataset.sceneTurnsTarget = target
    form.append(element)
  }
  host.append(form)
  document.body.append(host)

  const controller = new SceneTurnsController()
  controller.element = host
  controller.kindSelectTarget = kindSelect
  controller.turnsTarget = turnsList
  controller.turnsHeadingTarget = turnsHeading
  controller.emptyStateTarget = emptyState
  controller.saveFirstTarget = saveFirst
  controller.speakerSelectTarget = speakerSelect
  controller.bodyFieldTarget = bodyField
  controller.parentheticalFieldTarget = parentheticalField
  controller.addButtonTarget = addButton
  controller.speakerChoicesValue = SPEAKER_CHOICES
  controller.connect()
  controller.showTurns({ kind, turns, turns_create_url: createUrl })

  return { controller, host, form, kindSelect, turnsList, turnsHeading, emptyState, saveFirst, speakerSelect, bodyField,
    parentheticalField, addButton }
}

beforeEach(() => {
  document.head.replaceChildren()
  document.body.replaceChildren()
  window.fetch = async () => new Response(JSON.stringify(TURN), { status: 201 })
})

describe("Scene dialogue turns editor", () => {
  test("opens with ordered, text-only rows and actions using server-scoped URLs", () => {
    const hostileTurn = { ...TURN, speaker_name: "<img src=x>", body: "<script>bad()</script>" }
    const secondTurn = {
      ...TURN,
      id: 8,
      position: 1,
      speaker_id: 12,
      speaker_name: "Bea",
      update_url: "/turns/8",
      move_up_url: "/turns/8/move?direction=up",
      move_down_url: "/turns/8/move?direction=down",
      destroy_url: "/turns/8"
    }
    const { controller, turnsList, turnsHeading } = build({ kind: "dialogue", turns: [ hostileTurn, secondTurn ] })

    expect(turnsList.hidden).toBe(false)
    expect(turnsHeading.hidden).toBe(false)
    expect(turnsList.querySelector(".turn-speaker").textContent).toBe("<img src=x>")
    expect(turnsList.querySelector(".turn-line").textContent).toBe("<script>bad()</script>")
    expect(turnsList.querySelector("img, script")).toBeNull()
    expect(turnsList.querySelector("button[data-modal-form-url='/turns/7/move?direction=up']")).not.toBeNull()
    expect(turnsList.querySelector("button[data-modal-form-url='/turns/7/move?direction=down']")).not.toBeNull()
    expect(turnsList.querySelector("button[data-modal-form-url='/turns/7']")).not.toBeNull()
    expect(turnsList.querySelector(".turn-row:first-child button[data-modal-form-direction='up']").disabled).toBe(true)
    expect(turnsList.querySelector(".turn-row:last-child button[data-modal-form-direction='down']").disabled).toBe(true)

    controller.disconnect()
  })

  test("switching to Dialogue exposes the add workflow, but Narration cannot add a turn", () => {
    const { controller, kindSelect, turnsList, emptyState, saveFirst, addButton, speakerSelect } = build()

    expect(addButton.hidden).toBe(true)
    kindSelect.value = "dialogue"
    kindSelect.dispatchEvent(new Event("change"))

    expect(emptyState.hidden).toBe(false)
    expect(addButton.hidden).toBe(false)
    expect(speakerSelect.options[0].value).toBe("")

    kindSelect.value = "narration"
    kindSelect.dispatchEvent(new Event("change"))
    expect(addButton.hidden).toBe(true)
    expect(speakerSelect.disabled).toBe(true)
    expect(turnsList.hidden).toBe(true)
    expect(saveFirst.hidden).toBe(true)
    controller.disconnect()
  })

  test("switching a Dialogue with turns to Narration keeps its rows available for removal", () => {
    const { controller, kindSelect, turnsList, addButton } = build({ kind: "dialogue", turns: [ TURN ] })

    kindSelect.value = "narration"
    kindSelect.dispatchEvent(new Event("change"))

    expect(turnsList.hidden).toBe(false)
    expect(turnsList.querySelector(".turn-line").textContent).toBe("Hello.")
    expect(addButton.hidden).toBe(true)
    controller.disconnect()
  })

  test("a new Dialogue must be saved before turns can be attached", () => {
    const { controller, kindSelect, addButton, saveFirst } = build({ createUrl: "" })

    kindSelect.value = "dialogue"
    kindSelect.dispatchEvent(new Event("change"))

    expect(saveFirst.hidden).toBe(false)
    expect(addButton.hidden).toBe(true)
    controller.disconnect()
  })

  test("posts the selected speaker's turn and refreshes from the persisted element", async () => {
    const { controller, speakerSelect, bodyField, parentheticalField, turnsList, emptyState } = build({ kind: "dialogue" })
    const visits = []
    window.Turbo = { visit: (...args) => visits.push(args) }
    speakerSelect.value = "12"
    bodyField.value = "Welcome."
    parentheticalField.value = "smiling"
    window.fetch = async (url, options) => {
      expect(url).toBe("/turns")
      expect(options.method).toBe("POST")
      expect(new URLSearchParams(options.body).get("scene_dialogue_turn[speaker_id]")).toBe("12")
      expect(new URLSearchParams(options.body).get("scene_dialogue_turn[body]")).toBe("Welcome.")
      return new Response(JSON.stringify({ ...TURN, speaker_id: 12, speaker_name: "Bea", body: "Welcome.", parenthetical: "smiling" }), { status: 201 })
    }

    expect(await controller.create()).toBe(true)
    expect(turnsList.childElementCount).toBe(0)
    expect(bodyField.value).toBe("Welcome.")
    expect(parentheticalField.value).toBe("smiling")
    expect(speakerSelect.value).toBe("12")
    expect(emptyState.hidden).toBe(false)
    expect(visits).toEqual([ [ window.location.href, { action: "replace" } ] ])
    delete window.Turbo
    controller.disconnect()
  })

  test("requires an explicit speaker choice instead of silently selecting the first character", async () => {
    const { controller, speakerSelect, turnsList } = build({ kind: "dialogue" })
    let requested = false
    window.fetch = async () => { requested = true }

    expect(speakerSelect.value).toBe("")
    expect(await controller.create()).toBe(false)
    expect(requested).toBe(false)
    expect(controller.element.querySelector(".turn-error").textContent).toBe("Choose a speaker for this turn.")
    expect(turnsList.childElementCount).toBe(0)
    controller.disconnect()
  })

  test("refreshes a remembered draft receipt instead of rendering it as a saved turn", async () => {
    const { controller, speakerSelect, bodyField, turnsList } = build({ kind: "dialogue" })
    const visits = []
    window.Turbo = { visit: (...args) => visits.push(args) }
    speakerSelect.value = "11"
    bodyField.value = "Remember this."
    window.fetch = async () => new Response(JSON.stringify({ draft: true, change: { action: "create" } }), { status: 202 })

    expect(await controller.create()).toBe(true)
    expect(turnsList.childElementCount).toBe(0)
    expect(visits).toEqual([ [ window.location.href, { action: "replace" } ] ])
    delete window.Turbo
    controller.disconnect()
  })

  test("edits speaker, line, and delivery note in place", async () => {
    const { controller, turnsList } = build({ kind: "dialogue", turns: [ TURN ] })
    const visits = []
    window.Turbo = { visit: (...args) => visits.push(args) }
    const editButton = turnsList.querySelector("button[data-action='scene-turns#edit']")
    controller.edit({ currentTarget: editButton })
    const speaker = turnsList.querySelector("select[name='speaker_id']")
    const line = turnsList.querySelector("textarea[name='body']")
    const parenthetical = turnsList.querySelector("input[name='parenthetical']")
    speaker.value = "12"
    line.value = "Goodbye."
    parenthetical.value = "gently"
    window.fetch = async (url, options) => {
      expect(url).toBe("/turns/7")
      expect(options.method).toBe("PATCH")
      const params = new URLSearchParams(options.body)
      expect(params.get("scene_dialogue_turn[speaker_id]")).toBe("12")
      expect(params.get("scene_dialogue_turn[body]")).toBe("Goodbye.")
      expect(params.get("scene_dialogue_turn[parenthetical]")).toBe("gently")
      return new Response(JSON.stringify({ ...TURN, speaker_id: 12, speaker_name: "Bea", body: "Goodbye.", parenthetical: "gently" }), { status: 200 })
    }

    expect(await controller.save({ currentTarget: turnsList.querySelector("button[data-action='scene-turns#save']") })).toBe(true)
    expect(turnsList.querySelector("select[name='speaker_id']").value).toBe("12")
    expect(turnsList.querySelector("textarea[name='body']").value).toBe("Goodbye.")
    expect(turnsList.querySelector("input[name='parenthetical']").value).toBe("gently")
    expect(visits).toEqual([ [ window.location.href, { action: "replace" } ] ])
    delete window.Turbo
    controller.disconnect()
  })

  test("shows a server validation message and clears the pending state on refusal", async () => {
    const { controller, speakerSelect, addButton, host } = build({ kind: "dialogue" })
    speakerSelect.value = "11"
    window.fetch = async () => new Response(JSON.stringify({ errors: { speaker: [ "must belong to the scene's universe" ] } }), { status: 422 })

    expect(await controller.create()).toBe(false)
    expect(host.getAttribute("aria-busy")).toBe("false")
    expect(addButton.disabled).toBe(false)
    expect(host.querySelector(".turn-error[role='alert']").textContent).toBe("must belong to the scene's universe")
    controller.disconnect()
  })
})
