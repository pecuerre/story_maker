import { Controller } from "@hotwired/stimulus"
import { t } from "i18n"

// Dialogue turns inside the Scene Details Elements modal. The modal's JSON
// payload carries the stored turns (`scene_element_fields_json`), and this
// controller renders them as an ordered list. Turn mutations use the same-URL
// refresh contract as the shared modal form, so derived participation
// and every other server-rendered surface stay in sync.
//
// Every row is built with DOM APIs: `innerHTML` is never used.
export default class extends Controller {
  static targets = [
    "turns", "turnsHeading", "speakerSelect", "bodyField", "parentheticalField", "kindSelect",
    "addButton", "emptyState", "saveFirst"
  ]

  static values = {
    speakerChoices: Array
  }

  connect() {
    this.handleValues = (event) => this.showTurns(event.detail)
    this.handleKindChange = () => this.syncVisibility()
    this.element.addEventListener("modal-form:values", this.handleValues)
    this.kindSelectTarget.addEventListener("change", this.handleKindChange)
    this.addButtonTarget.addEventListener("click", () => this.create())

    const prompt = document.createElement("option")
    prompt.value = ""
    prompt.textContent = t("scenes.elements.dialogue_turns.choose_speaker")
    this.speakerSelectTarget.appendChild(prompt)

    // The speaker options are the same for adding a turn and for editing one.
    this.speakerChoicesValue.forEach((pair) => {
      const option = document.createElement("option")
      option.value = String(pair[1])
      option.textContent = pair[0]
      this.speakerSelectTarget.appendChild(option)
    })
  }

  disconnect() {
    this.element.removeEventListener("modal-form:values", this.handleValues)
    this.kindSelectTarget.removeEventListener("change", this.handleKindChange)
  }

  // Renders the turns the modal's JSON payload named, replacing whatever a
  // previous element left behind. A Narration Element cannot add turns, but any
  // existing rows stay visible so they can be removed before changing its kind.
  showTurns(values) {
    const turns = Array.isArray(values.turns) ? values.turns : []

    this.element.querySelector(".turn-error")?.remove()
    this.turnsTarget.replaceChildren()
    this.turnsCreateUrl = values.turns_create_url
    this.kindSelectTarget.value = values.kind || this.kindSelectTarget.value

    turns.forEach((turn, index) => {
      this.turnsTarget.appendChild(this.row(turn, index, turns.length))
    })
    this.syncVisibility()
  }

  // The kind can change after the modal is filled. Keep existing rows visible
  // while switching to Narration so the author can remove turns before saving;
  // never offer a new turn unless this is a saved Dialogue Element.
  syncVisibility() {
    const dialogue = this.kindSelectTarget.value === "dialogue"
    const hasTurns = this.turnsTarget.childElementCount > 0
    const canAddTurns = dialogue && Boolean(this.turnsCreateUrl)

    this.turnsTarget.hidden = !hasTurns
    this.turnsHeadingTarget.hidden = !hasTurns
    this.emptyStateTarget.hidden = !dialogue || hasTurns
    this.addButtonTarget.hidden = !canAddTurns
    this.saveFirstTarget.hidden = !dialogue || Boolean(this.turnsCreateUrl)
    this.speakerSelectTarget.disabled = !canAddTurns
    this.bodyFieldTarget.disabled = !canAddTurns
    this.parentheticalFieldTarget.disabled = !canAddTurns
  }

  // One turn in display mode: speaker, line, optional parenthetical, and the
  // move/delete/edit controls. Move and delete are issued by the shared modal
  // form, so they refresh the page exactly as an Element move/delete does.
  row(turn, position, total) {
    const container = document.createElement("div")
    container.className = "turn-row list-group-item d-flex align-items-start gap-2"
    container.dataset.turnId = turn.id
    container.dataset.speakerId = turn.speaker_id
    container.dataset.speakerName = turn.speaker_name
    container.dataset.body = turn.body ?? ""
    container.dataset.parenthetical = turn.parenthetical ?? ""
    container.dataset.updateUrl = turn.update_url
    container.dataset.moveUpUrl = turn.move_up_url
    container.dataset.moveDownUrl = turn.move_down_url
    container.dataset.destroyUrl = turn.destroy_url

    const speaker = document.createElement("span")
    speaker.className = "turn-speaker"
    speaker.textContent = turn.speaker_name
    container.appendChild(speaker)

    const line = document.createElement("span")
    line.className = "turn-line"
    line.textContent = turn.body
    container.appendChild(line)

    if (turn.parenthetical) {
      const note = document.createElement("span")
      note.className = "turn-parenthetical text-body-secondary ms-2"
      note.textContent = `(${turn.parenthetical})`
      container.appendChild(note)
    }

    const actions = document.createElement("div")
    actions.className = "ms-auto d-flex align-items-center gap-1"

    actions.append(
      this.moveButton(turn.move_up_url, "up", position === 0),
      this.moveButton(turn.move_down_url, "down", position === total - 1)
    )

    const del = document.createElement("button")
    del.type = "button"
    del.className = "btn btn-sm btn-light border text-danger"
    del.dataset.action = "modal-form#destroy"
    del.dataset.modalFormUrl = turn.destroy_url
    del.dataset.modalFormConfirm = t("scenes.elements.dialogue_turns.delete_confirm")
    del.textContent = t("shared.row_actions.delete")
    actions.appendChild(del)

    const edit = document.createElement("button")
    edit.type = "button"
    edit.className = "btn btn-sm btn-light border ms-2"
    edit.dataset.action = "scene-turns#edit"
    edit.textContent = t("scenes.elements.dialogue_turns.edit")
    actions.appendChild(edit)

    container.appendChild(actions)
    return container
  }

  moveButton(url, direction, disabled) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "btn btn-sm btn-light border"
    button.dataset.action = "modal-form#move"
    button.dataset.modalFormUrl = url
    button.dataset.modalFormDirection = direction
    button.disabled = disabled
    button.textContent = direction === "up" ? "↑" : "↓"
    const label = direction === "up" ? t("scenes.move.up") : t("scenes.move.down")
    button.title = label
    button.setAttribute("aria-label", label)
    return button
  }

  // Replaces a displayed row with an inline form: speaker, line, parenthetical,
  // save, cancel. The stored values pre-fill the controls.
  edit(event) {
    const container = event.currentTarget.closest("[data-turn-id]")
    container.replaceChildren()

    const speaker = document.createElement("select")
    speaker.className = "form-select form-select-sm me-1"
    speaker.name = "speaker_id"
    speaker.setAttribute("aria-label", t("scenes.elements.dialogue_turns.form.speaker"))
    this.speakerChoicesValue.forEach((pair) => {
      const option = document.createElement("option")
      option.value = String(pair[1])
      option.textContent = pair[0]
      if (String(pair[1]) === container.dataset.speakerId) option.selected = true
      speaker.appendChild(option)
    })

    const line = document.createElement("textarea")
    line.className = "form-control form-control-sm me-1 flex-grow-1"
    line.name = "body"
    line.rows = 1
    line.value = container.dataset.body
    line.setAttribute("aria-label", t("scenes.elements.dialogue_turns.form.body"))

    const parenthetical = document.createElement("input")
    parenthetical.type = "text"
    parenthetical.className = "form-control form-control-sm me-1"
    parenthetical.name = "parenthetical"
    parenthetical.value = container.dataset.parenthetical
    parenthetical.setAttribute("aria-label", t("scenes.elements.dialogue_turns.form.parenthetical"))

    const save = document.createElement("button")
    save.type = "button"
    save.className = "btn btn-sm btn-success"
    save.dataset.action = "scene-turns#save"
    save.textContent = t("scenes.elements.dialogue_turns.form.save")

    const cancel = document.createElement("button")
    cancel.type = "button"
    cancel.className = "btn btn-sm btn-light border ms-2"
    cancel.dataset.action = "scene-turns#cancel"
    cancel.textContent = t("shared.form.cancel")

    container.append(speaker, line, parenthetical, save, cancel)
    container.className = "turn-row list-group-item d-flex align-items-center gap-1"
  }

  // Restores the stored row, discarding an inline edit.
  cancel(event) {
    const container = event.currentTarget.closest("[data-turn-id]")
    const turn = {
      id: container.dataset.turnId,
      speaker_id: container.dataset.speakerId,
      speaker_name: container.dataset.speakerName,
      body: container.dataset.body,
      parenthetical: container.dataset.parenthetical,
      update_url: container.dataset.updateUrl,
      move_up_url: container.dataset.moveUpUrl,
      move_down_url: container.dataset.moveDownUrl,
      destroy_url: container.dataset.destroyUrl
    }
    const rows = [ ...this.turnsTarget.children ]
    const position = rows.indexOf(container)
    container.replaceWith(this.row(turn, position, rows.length))
  }

  // Adds a turn from the controls; successful writes refresh from the server.
  create() {
    if (!this.speakerSelectTarget.value) {
      this.showError(t("scenes.elements.dialogue_turns.speaker_required"))
      return false
    }

    const formData = new FormData()
    formData.append("scene_dialogue_turn[speaker_id]", this.speakerSelectTarget.value)
    formData.append("scene_dialogue_turn[body]", this.bodyFieldTarget.value)
    formData.append("scene_dialogue_turn[parenthetical]", this.parentheticalFieldTarget.value)

    return this.submit(this.turnsCreateUrl, "POST", formData)
  }

  save(event) {
    const button = event.currentTarget
    const container = button.closest("[data-turn-id]")
    const speaker = container.querySelector("select[name='speaker_id']")
    const line = container.querySelector("textarea[name='body']")
    const parenthetical = container.querySelector("input[name='parenthetical']")

    const formData = new FormData()
    formData.append("scene_dialogue_turn[speaker_id]", speaker.value)
    formData.append("scene_dialogue_turn[body]", line.value)
    formData.append("scene_dialogue_turn[parenthetical]", parenthetical.value)

    return this.submit(container.dataset.updateUrl, "PATCH", formData)
  }

  async submit(url, method, formData) {
    const params = new URLSearchParams(formData)
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const headers = {
      Accept: "application/json",
      "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8"
    }
    if (token) headers["X-CSRF-Token"] = token

    this.setPending(true)
    try {
      const response = await window.fetch(url, { method, headers, body: params })
      if (!response.ok) {
        let payload
        try {
          payload = await response.json()
        } catch (_error) {
          payload = null
        }
        const messages = payload?.errors ? Object.values(payload.errors).flat() : []
        this.showError(messages.length > 0 ? messages.join(" ") : t("scenes.elements.dialogue_turns.save_failed"))
        this.setPending(false)
        return false
      }

      // A direct mutation is rendered from persisted state; a draft mutation is
      // only a receipt. Refresh for both so the client never presents an
      // unpersisted change as a saved turn and derived participation stays fresh.
      this.refresh()
      return true
    } catch (_error) {
      this.showError(t("scenes.elements.dialogue_turns.save_failed"))
      this.setPending(false)
      return false
    }
  }

  setPending(pending) {
    this.element.setAttribute("aria-busy", String(pending))
    this.addButtonTarget.disabled = pending
    this.element.querySelectorAll("button[data-action='scene-turns#save']").forEach((button) => {
      button.disabled = pending
    })
  }

  showError(message) {
    const existing = this.element.querySelector(".turn-error")
    if (existing) existing.remove()
    const error = document.createElement("p")
    error.className = "turn-error text-danger small mb-1"
    error.setAttribute("role", "alert")
    error.textContent = message
    this.element.insertBefore(error, this.element.firstChild)
  }

  refresh() {
    if (window.Turbo?.visit) window.Turbo.visit(window.location.href, { action: "replace" })
    else window.location.reload()
  }
}
