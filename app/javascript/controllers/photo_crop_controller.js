import { Controller } from "@hotwired/stimulus"
import { t } from "i18n"

// The square photo editor.
//
// One control serves all three page patterns in this application, which is why
// the whole widget is built here instead of in a template: the JSON modals, the
// taxonomy editor's DOM-built modal, and the plain full-page forms each produce
// only the same bare container, and everything inside it is this controller's own
// DOM. One implementation, so the three surfaces cannot drift.
//
// The author picks a file, the image opens in a square viewport, and they drag
// it — or use the arrow keys, the four move buttons, or the zoom slider — to
// choose the part that matters. Confirming draws that square to a canvas and
// hands the result to the form as a `data:` URL in a hidden field, so the upload
// is one ordinary form field rather than a multipart body. That is what lets the
// existing mutation contracts carry it unchanged: the JSON modals already post
// `application/x-www-form-urlencoded`, and a plain Turbo form posts a string.
//
// Every node here is built with DOM APIs. Nothing parses markup, and nothing a
// user supplies ever becomes any: a file name only ever reaches a text node.
//
// Every word the widget shows is read through `t()`, so a Spanish page has no
// English left in it. The one value that is not chrome is the field's own
// `label`, which is the descriptor label the surface that rendered the container
// sent — the taxonomy tree's own editor label, not a word this controller owns.
//
// The server is the authority on the stored file. This crop is a square because
// a photo is always shown as one, and the server crops and resizes to 300x300
// again whatever arrives.
// The event the shared modal dispatches on the photo control to say which row
// it is about to edit.
const ROW_CHANGED = "photo-crop:load"

export default class PhotoCropController extends Controller {
  static values = {
    field: String,
    removeField: String,
    currentUrl: { type: String, default: "" },
    label: { type: String, default: "" }
  }

  static SIZE = 300
  static MIN_ZOOM = 100
  static MAX_ZOOM = 400
  static ZOOM_STEP = 10
  static PAN_STEP = 12

  connect() {
    this.image = null
    this.objectUrl = null
    this.drag = null
    this.offsetX = 0
    this.offsetY = 0
    this.zoom = PhotoCropController.MIN_ZOOM

    this.build()
    this.form = this.element.closest("form")
    this.onFormReset = () => this.reset()
    this.form?.addEventListener("reset", this.onFormReset)
    this.element.addEventListener(ROW_CHANGED, (event) => this.load(event))

    this.reset()
  }

  disconnect() {
    this.form?.removeEventListener("reset", this.onFormReset)
    this.release()
  }

  // The shared JSON modal reuses one form for every row, so it tells the control
  // which record it is about before filling the other fields. Without this a row
  // would open showing the previous row's photo. The event is dispatched on this
  // element because a separate controller is told rather than written to.
  load(event) {
    this.currentUrlValue = event.detail?.url || ""
    this.reset()
  }

  // ---------------------------------------------------------------- the widget

  build() {
    this.chooser = this.group(...this.fileField())
    this.preview = this.element.appendChild(this.previewBox())
    this.removeControl = this.element.appendChild(this.removeControlBox())
    this.removeInput = this.removeControl.querySelector("input")
    this.status = this.element.appendChild(this.liveRegion())
    this.cropper = this.element.appendChild(this.cropperBox())
  }

  fileField() {
    const input = document.createElement("input")
    input.type = "file"
    input.accept = "image/jpeg,image/png,image/webp,image/gif"
    input.className = "form-control"
    input.id = `photo-crop-file-${this.identifier}`
    input.dataset.action = "photo-crop#choose"

    const label = document.createElement("label")
    label.className = "form-label"
    label.htmlFor = input.id
    label.textContent = this.labelValue

    const hint = document.createElement("p")
    hint.className = "form-text mb-0"
    hint.textContent = t("shared.photo_field.hint")

    return [ label, input, hint ]
  }

  previewBox() {
    this.previewImage = document.createElement("img")
    this.previewImage.className = "photo-preview-image"
    this.previewImage.alt = ""
    this.previewImage.hidden = true

    const box = document.createElement("div")
    box.className = "photo-preview"
    box.hidden = true
    box.append(this.previewImage)
    return box
  }

  // A real form field rather than a button that posts something of its own: an
  // unchecked box sends nothing, which the model reads as "leave the photo
  // alone", and a checked one clears the reference on the next save.
  removeControlBox() {
    const input = document.createElement("input")
    input.type = "checkbox"
    input.className = "form-check-input"
    input.id = `photo-crop-remove-${this.identifier}`
    input.name = this.removeFieldValue
    input.value = "1"
    input.dataset.action = "photo-crop#toggleRemove"

    const label = document.createElement("label")
    label.className = "form-check-label"
    label.htmlFor = input.id
    label.textContent = t("shared.photo_field.remove")

    const wrapper = document.createElement("div")
    wrapper.className = "form-check photo-remove"
    wrapper.append(input, label)
    return wrapper
  }

  liveRegion() {
    const status = document.createElement("p")
    status.className = "form-text photo-status"
    status.setAttribute("role", "status")
    status.setAttribute("aria-live", "polite")
    return status
  }

  cropperBox() {
    this.stage = document.createElement("div")
    this.stage.className = "photo-crop-stage"
    this.stage.tabIndex = 0
    this.stage.dataset.action = "photo-crop#dragStart photo-crop#drag photo-crop#dragEnd keydown->photo-crop#nudge"
    this.stage.setAttribute("role", "application")
    this.stage.setAttribute("aria-label", t("shared.photo_field.stage_aria"))

    this.canvas = document.createElement("canvas")
    this.canvas.width = PhotoCropController.SIZE
    this.canvas.height = PhotoCropController.SIZE
    this.canvas.className = "photo-crop-canvas"
    this.canvas.hidden = true

    this.zoomInput = document.createElement("input")
    this.zoomInput.type = "range"
    this.zoomInput.className = "form-range"
    this.zoomInput.min = String(PhotoCropController.MIN_ZOOM)
    this.zoomInput.max = String(PhotoCropController.MAX_ZOOM)
    this.zoomInput.step = String(PhotoCropController.ZOOM_STEP)
    this.zoomInput.value = String(this.zoom)
    this.zoomInput.id = `photo-crop-zoom-${this.identifier}`
    this.zoomInput.dataset.action = "photo-crop#zoomTo"
    this.zoomInput.setAttribute("aria-label", t("shared.photo_field.zoom_aria"))

    const zoomLabel = document.createElement("label")
    zoomLabel.className = "form-label"
    zoomLabel.htmlFor = this.zoomInput.id
    zoomLabel.textContent = t("shared.photo_field.zoom")

    const actions = document.createElement("div")
    actions.className = "d-flex flex-wrap gap-2"
    actions.append(
      this.button(t("shared.photo_field.accept"), "btn btn-primary", "photo-crop#accept"),
      this.button(t("shared.form.cancel"), "btn btn-outline-secondary", "photo-crop#discard")
    )

    const controls = document.createElement("div")
    controls.className = "photo-crop-controls"
    controls.append(zoomLabel, this.zoomInput, this.nudgeControls(), actions)

    const box = document.createElement("div")
    box.className = "photo-crop"
    box.hidden = true
    box.append(this.stage, this.canvas, controls)
    return box
  }

  // Four real buttons: dragging is a pointer gesture and a keyboard has none, so
  // the same moves the pointer makes have to exist as controls.
  nudgeControls() {
    const wrapper = document.createElement("div")
    wrapper.className = "photo-crop-nudge"
    wrapper.setAttribute("role", "group")
    wrapper.setAttribute("aria-label", t("shared.photo_field.move_group_aria"))

    // The four directions are four keys rather than one sentence with a spliced
    // word, because a locale that orders the adverb differently would have to
    // rewrite the sentence to place it. The icon name beside each is Bootstrap's
    // own and is not chrome.
    const moves = [
      [ "arrow-left", -1, 0, t("shared.photo_field.move_left") ],
      [ "arrow-up", 0, -1, t("shared.photo_field.move_up") ],
      [ "arrow-down", 0, 1, t("shared.photo_field.move_down") ],
      [ "arrow-right", 1, 0, t("shared.photo_field.move_right") ]
    ]

    moves.forEach(([ icon, dx, dy, label ]) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "btn btn-sm btn-light border"
      button.setAttribute("aria-label", label)
      button.dataset.action = "photo-crop#nudgeBy"
      button.dataset.dx = String(dx)
      button.dataset.dy = String(dy)
      const glyph = document.createElement("i")
      glyph.className = `bi bi-${icon}`
      glyph.setAttribute("aria-hidden", "true")
      button.append(glyph)
      wrapper.append(button)
    })

    return wrapper
  }

  button(label, className, action) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = className
    button.textContent = label
    button.dataset.action = action
    return button
  }

  group(...nodes) {
    const wrapper = document.createElement("div")
    wrapper.className = "mb-3"
    wrapper.append(...nodes)
    this.element.append(wrapper)
    return wrapper
  }

  // ------------------------------------------------------------- the cropper

  async choose(event) {
    const file = event.target.files?.[0]
    if (!file) return

    this.announce(t("shared.photo_field.reading"))
    const url = URL.createObjectURL(file)
    const image = new Image()

    try {
      await new Promise((resolve, reject) => {
        image.onload = resolve
        image.onerror = () => reject(new Error("unreadable"))
        image.src = url
      })
    } catch (_error) {
      URL.revokeObjectURL(url)
      this.announce(t("shared.photo_field.unreadable"), true)
      return
    }

    this.release()
    this.image = image
    this.objectUrl = url
    this.zoom = PhotoCropController.MIN_ZOOM
    this.zoomInput.value = String(this.zoom)
    this.center()

    this.chooser.hidden = true
    this.cropper.hidden = false
    this.draw()
    // The sentence names the button by that button's own key, so a translator
    // placing the reference and a translator naming the control are two separate
    // decisions — the same split a sentence carrying a link has.
    this.announce(t("shared.photo_field.ready", { action: t("shared.photo_field.accept") }))
    this.stage.focus()
  }

  // The square, in source-image pixels. It is always the largest square the
  // image allows at the current zoom, so it can never be smaller than the output
  // and the stored photo is never scaled up.
  crop() {
    const shortest = Math.min(this.image.naturalWidth, this.image.naturalHeight)
    const size = clamp(Math.round(shortest * (100 / this.zoom)), 1, shortest)
    return {
      x: clamp(Math.round(this.offsetX), 0, this.image.naturalWidth - size),
      y: clamp(Math.round(this.offsetY), 0, this.image.naturalHeight - size),
      size
    }
  }

  center() {
    const shortest = Math.min(this.image.naturalWidth, this.image.naturalHeight)
    const size = clamp(Math.round(shortest * (100 / this.zoom)), 1, shortest)
    this.offsetX = (this.image.naturalWidth - size) / 2
    this.offsetY = (this.image.naturalHeight - size) / 2
  }

  // The stage shows the source image scaled so the square fills it, which is
  // literally the region that will be stored. Nothing is re-encoded while
  // dragging; the canvas is only drawn once, on accept.
  draw() {
    if (!this.image) return

    const { x, y, size } = this.crop()
    const side = this.stageSide()

    this.canvas.hidden = false
    this.canvas.style.width = `${side}px`
    this.canvas.style.height = `${side}px`
    this.canvas.getContext("2d").drawImage(this.image, x, y, size, size, 0, 0, side, side)
  }

  stageSide() {
    return this.stage.clientWidth || PhotoCropController.SIZE
  }

  dragStart(event) {
    if (event.pointerId === undefined || !this.image) return
    this.drag = { x: event.clientX, y: event.clientY }
    this.stage.setPointerCapture?.(event.pointerId)
  }

  drag(event) {
    if (!this.drag || !this.image) return
    const { size } = this.crop()
    const perPixel = size / this.stageSide()

    this.offsetX += (event.clientX - this.drag.x) * perPixel
    this.offsetY += (event.clientY - this.drag.y) * perPixel
    this.drag = { x: event.clientX, y: event.clientY }
    this.draw()
  }

  dragEnd(event) {
    if (!this.drag) return
    this.stage.releasePointerCapture?.(event.pointerId)
    this.drag = null
  }

  nudge(event) {
    if (!this.image) return

    const step = PhotoCropController.PAN_STEP
    const moves = {
      ArrowLeft: [ -step, 0 ], ArrowRight: [ step, 0 ],
      ArrowUp: [ 0, -step ], ArrowDown: [ 0, step ]
    }
    const move = moves[event.key]

    if (move) {
      this.panBy(move[0], move[1])
    } else if (event.key === "+" || event.key === "=") {
      this.zoomBy(PhotoCropController.ZOOM_STEP)
    } else if (event.key === "-" || event.key === "_") {
      this.zoomBy(-PhotoCropController.ZOOM_STEP)
    } else {
      return
    }

    event.preventDefault()
  }

  nudgeBy(event) {
    const button = event.currentTarget
    this.panBy(Number(button.dataset.dx) * PhotoCropController.PAN_STEP, Number(button.dataset.dy) * PhotoCropController.PAN_STEP)
  }

  panBy(dx, dy) {
    this.offsetX += dx
    this.offsetY += dy
    this.draw()
  }

  zoomTo(event) {
    this.zoomBy(Number(event.target.value) - this.zoom)
  }

  zoomBy(delta) {
    if (!this.image) return
    this.zoom = clamp(this.zoom + delta, PhotoCropController.MIN_ZOOM, PhotoCropController.MAX_ZOOM)
    this.zoomInput.value = String(this.zoom)
    this.center()
    this.draw()
  }

  accept() {
    if (!this.image) return

    this.valueField().value = this.canvas.toDataURL("image/jpeg", 0.9)
    this.release()
    this.close()
    this.announce(t("shared.photo_field.chosen"))
    this.showChosen()
  }

  discard() {
    this.release()
    this.close()
    this.announce(t("shared.photo_field.discarded"))
  }

  close() {
    this.cropper.hidden = true
    this.chooser.hidden = false
  }

  toggleRemove() {
    if (!this.removeBox().checked) {
      this.reset()
      return
    }

    this.valueField().value = ""
    this.announce(t("shared.photo_field.removing"))
    this.showChosen()
  }

  // ---------------------------------------------------------- the stored photo

  reset() {
    this.removeBox().checked = false
    this.valueField().value = ""

    if (this.currentUrlValue) {
      this.previewImage.src = this.currentUrlValue
      this.previewImage.hidden = false
      this.preview.hidden = false
      this.removeControl.hidden = false
      return
    }

    this.preview.hidden = true
    this.previewImage.hidden = true
    this.previewImage.removeAttribute("src")
    this.removeControl.hidden = true
  }

  // A crop that has been chosen but not yet saved is not the stored photo, so
  // the stored one is taken off screen until the form is saved and the row
  // reopens with the new one.
  showChosen() {
    this.preview.hidden = true
    this.previewImage.hidden = true
    this.previewImage.removeAttribute("src")
  }

  valueField() {
    this.value = this.value || this.hidden(this.fieldValue)
    return this.value
  }

  removeBox() {
    return this.removeInput
  }

  hidden(name) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    this.element.append(input)
    return input
  }

  announce(message, problem = false) {
    this.status.textContent = message
    this.status.classList.toggle("text-danger", problem)
  }

  release() {
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = null
    this.image = null
    this.drag = null
  }
}

function clamp(value, low, high) {
  return Math.min(Math.max(value, low), high)
}
