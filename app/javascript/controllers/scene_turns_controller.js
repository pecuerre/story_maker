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
    "entryFields", "addButton", "emptyState", "saveFirst"
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
    this.entryFieldsTarget.hidden = !canAddTurns
    this.addButtonTarget.hidden = !canAddTurns
    this.saveFirstTarget.hidden = !dialogue || Boolean(this.turnsCreateUrl)
    this.speakerSelectTarget.disabled = !canAddTurns
    this.bodyFieldTarget.disabled = !canAddTurns
    this.parentheticalFieldTarget.disabled = !canAddTurns
  }

  // One turn in display mode, read as one sentence — `speaker: line (note)` —
  // with the move/delete/edit controls at the right edge. Move and delete are
  // issued by the shared modal form, so they refresh the page exactly as an
  // Element move/delete does.
  row(turn, position, total, { pending = false } = {}) {
    const container = document.createElement("div")
    container.className = pending
      ? "turn-row turn-row--pending list-group-item"
      : "turn-row list-group-item"

    if (!pending) {
      container.dataset.turnId = turn.id
      container.dataset.speakerId = turn.speaker_id ?? ""
      container.dataset.speakerValue = turn.speaker_value ?? ""
      container.dataset.speakerName = turn.speaker_name
      container.dataset.body = turn.body ?? ""
      container.dataset.parenthetical = turn.parenthetical ?? ""
      container.dataset.updateUrl = turn.update_url
      container.dataset.moveUpUrl = turn.move_up_url
      container.dataset.moveDownUrl = turn.move_down_url
      container.dataset.destroyUrl = turn.destroy_url
    }

    const copy = document.createElement("p")
    copy.className = "turn-copy"

    const speaker = document.createElement("span")
    speaker.className = "turn-speaker"
    speaker.textContent = turn.speaker_name
    copy.append(speaker, document.createTextNode(": "))

    const line = document.createElement("span")
    line.className = "turn-line"
    line.textContent = turn.body
    copy.appendChild(line)

    if (turn.parenthetical) {
      const note = document.createElement("span")
      note.className = "turn-parenthetical"
      note.textContent = ` (${turn.parenthetical})`
      copy.appendChild(note)
    }

    container.appendChild(copy)

    const actions = document.createElement("div")
    actions.className = "turn-actions"

    if (pending) {
      const badge = document.createElement("span")
      badge.className = "badge rounded-pill text-bg-warning border"
      badge.textContent = t("scenes.elements.dialogue_turns.pending")
      actions.appendChild(badge)
      container.appendChild(actions)
      return container
    }

    actions.append(
      this.moveButton(turn.move_up_url, "up", position === 0),
      this.moveButton(turn.move_down_url, "down", position === total - 1),
      this.iconButton("bi-pencil", t("scenes.elements.dialogue_turns.edit"), {
        action: "scene-turns#edit"
      }),
      this.iconButton("bi-trash", t("scenes.elements.dialogue_turns.delete"), {
        action: "modal-form#destroy",
        url: turn.destroy_url,
        confirm: t("scenes.elements.dialogue_turns.delete_confirm"),
        danger: true
      })
    )

    container.appendChild(actions)
    return container
  }

  moveButton(url, direction, disabled) {
    const label = direction === "up" ? t("scenes.move.up") : t("scenes.move.down")
    return this.iconButton(direction === "up" ? "bi-arrow-up" : "bi-arrow-down", label, {
      action: "modal-form#move",
      url,
      direction,
      disabled
    })
  }

  // Every turn action is an icon with an accessible name, so the right-hand
  // column keeps one width instead of growing with the words "Edit turn".
  iconButton(icon, label, { action, url = null, direction = null, confirm = null, disabled = false, danger = false } = {}) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = danger ? "btn btn-sm btn-light border text-danger" : "btn btn-sm btn-light border"
    button.dataset.action = action
    if (url) button.dataset.modalFormUrl = url
    if (direction) button.dataset.modalFormDirection = direction
    if (confirm) button.dataset.modalFormConfirm = confirm
    button.disabled = disabled
    button.title = label
    button.setAttribute("aria-label", label)

    const iconElement = document.createElement("i")
    iconElement.className = `bi ${icon}`
    iconElement.setAttribute("aria-hidden", "true")
    button.appendChild(iconElement)
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
      speaker.appendChild(option)
    })
    // Selecting after every option is appended is the reliable path; setting an
    // option's `selected` while it is detached is not.
    if (container.dataset.speakerValue) speaker.value = container.dataset.speakerValue

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
    container.className = "turn-row turn-row--editing list-group-item"
  }

  // Restores the stored row, discarding an inline edit.
  cancel(event) {
    const container = event.currentTarget.closest("[data-turn-id]")
    const turn = {
      id: container.dataset.turnId,
      speaker_id: container.dataset.speakerId,
      speaker_value: container.dataset.speakerValue,
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

  // Adds a turn from the controls and appends it in the open modal, so an author
  // writing a conversation never loses the editor between lines. A direct
  // mutation returns the stored row; a draft-based universe returns a receipt,
  // and the row is shown as saved to the draft instead of pretending it is
  // already stored. The speaker is kept for the next line; the line and its
  // delivery note are cleared.
  create() {
    if (!this.speakerSelectTarget.value) {
      this.showError(t("scenes.elements.dialogue_turns.speaker_required"))
      return false
    }

    const speakerOption = this.speakerSelectTarget.selectedOptions[0]
    const pendingTurn = {
      speaker_name: speakerOption?.textContent.trim() || "",
      body: this.bodyFieldTarget.value,
      parenthetical: this.parentheticalFieldTarget.value
    }

    const formData = new FormData()
    formData.append("scene_dialogue_turn[speaker_id]", this.speakerSelectTarget.value)
    formData.append("scene_dialogue_turn[body]", pendingTurn.body)
    formData.append("scene_dialogue_turn[parenthetical]", pendingTurn.parenthetical)

    return this.submit(this.turnsCreateUrl, "POST", formData, {
      saved: (turn) => {
        this.appendTurn(turn)
        this.resetEntry()
      },
      pending: () => {
        this.appendPendingTurn(pendingTurn)
        this.resetEntry()
      }
    })
  }

  resetEntry() {
    this.bodyFieldTarget.value = ""
    this.parentheticalFieldTarget.value = ""
  }

  // A saved turn joins the end of the list. The row that was last keeps its
  // controls, but its Move down is no longer at the boundary.
  appendTurn(turn) {
    const total = this.turnsTarget.childElementCount
    const previous = this.turnsTarget.lastElementChild
    const previousDown = previous?.querySelector("button[data-modal-form-direction='down']")
    if (previousDown) previousDown.disabled = false

    this.turnsTarget.appendChild(this.row(turn, total, total + 1))
    this.syncVisibility()
  }

  // A remembered turn has no server id yet, so it has no move/edit/delete
  // controls; the badge says it is waiting in the author's draft.
  appendPendingTurn(turn) {
    const total = this.turnsTarget.childElementCount
    this.turnsTarget.appendChild(this.row(turn, total, total + 1, { pending: true }))
    this.syncVisibility()
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

  async submit(url, method, formData, handlers = {}) {
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

      // A direct mutation returns the stored turn, which can join the open list
      // as it is. A draft mutation is only a receipt, so it joins the list as a
      // clearly pending row; neither case closes the editor. Every other
      // mutation keeps the page-refresh contract.
      const payload = await response.json().catch(() => null)
      if (handlers.saved && payload?.id) {
        handlers.saved(payload)
        this.setPending(false)
        return true
      }

      if (handlers.pending && payload?.draft) {
        handlers.pending(payload)
        this.setPending(false)
        return true
      }

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
