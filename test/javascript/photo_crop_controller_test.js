import { beforeEach, describe, expect, test } from "bun:test"
import PhotoCropController from "../../app/javascript/controllers/photo_crop_controller"

// The square photo editor. What the request suite cannot see is the whole
// interaction: that a chosen file opens a square, that the square stays a square
// and stays inside the image, that the keyboard can do what the pointer does, and
// that the finished crop is handed to the form as one ordinary field. Those are
// the cases below.
function build(values = {}) {
  const host = document.createElement("div")
  host.dataset.controller = "photo-crop"
  document.body.append(host)

  const controller = new PhotoCropController()
  controller.element = host

  // Stimulus reads these off the container's data attributes in a browser. The
  // mocked base class here has no value machinery, so the test sets them.
  controller.fieldValue = "character[photo_data]"
  controller.removeFieldValue = "character[remove_photo]"
  controller.labelValue = "Photo"
  controller.currentUrlValue = values.currentUrl || ""
  controller.connect()
  return { controller, host }
}

// happy-dom has no 2D canvas; the controller only needs somewhere to draw, and
// a stub keeps these cases about the crop and the fields rather than about pixels.
function stubCanvas() {
  HTMLCanvasElement.prototype.getContext = () => ({ drawImage: () => {} })
  HTMLCanvasElement.prototype.toDataURL = () => "data:image/jpeg;base64,cropped"
}

function fakeImage(width, height) {
  return { naturalWidth: width, naturalHeight: height }
}

function withImage(controller, width = 400, height = 200) {
  controller.image = fakeImage(width, height)
  controller.zoom = PhotoCropController.MIN_ZOOM
  controller.center()
  return controller
}

beforeEach(() => {
  document.body.innerHTML = ""
  stubCanvas()
})

describe("the stored photo", () => {
  test("a record with a photo shows it and offers to remove it", () => {
    const { controller } = build({ currentUrl: "/rails/active_storage/photo.jpg" })

    expect(controller.preview.hidden).toBe(false)
    expect(controller.previewImage.getAttribute("src")).toBe("/rails/active_storage/photo.jpg")
    expect(controller.removeControl.hidden).toBe(false)
  })

  test("a record with no photo shows no preview and no remove control", () => {
    const { controller } = build()

    expect(controller.preview.hidden).toBe(true)
    expect(controller.removeControl.hidden).toBe(true)
    expect(controller.valueField().value).toBe("")
  })

  test("the editor is told which row a shared modal is about", () => {
    const { controller, host } = build()

    // The event the shared modal dispatches, not a direct call: the wiring is
    // what makes a reused modal form show the right row.
    host.dispatchEvent(new CustomEvent("photo-crop:load", {
      bubbles: true,
      detail: { url: "/rails/active_storage/other.jpg" }
    }))

    expect(controller.previewImage.getAttribute("src")).toBe("/rails/active_storage/other.jpg")
  })

  test("a form reset drops the previous row's picture", () => {
    const form = document.createElement("form")
    document.body.append(form)
    const { controller } = build({ currentUrl: "/rails/active_storage/first.jpg" })
    form.append(controller.element)
    // Reconnect now that the control sits inside a form, which is the order the
    // page builds them in.
    controller.disconnect()
    controller.connect()

    controller.removeBox().checked = true
    controller.valueField().value = "data:image/jpeg;base64,chosen"
    // `form.reset()` fires `reset` (the HTML reset algorithm), which is what the
    // shared JSON modal relies on when it reuses one form for every row.
    form.dispatchEvent(new Event("reset"))

    expect(controller.removeBox().checked).toBe(false)
    expect(controller.valueField().value).toBe("")
    expect(controller.previewImage.getAttribute("src")).toBe("/rails/active_storage/first.jpg")
  })

  test("a row switch after a reset shows the new row's photo, not the old one", () => {
    const form = document.createElement("form")
    document.body.append(form)
    const { controller } = build({ currentUrl: "/rails/active_storage/first.jpg" })
    form.append(controller.element)
    controller.disconnect()
    controller.connect()

    controller.element.dispatchEvent(new CustomEvent("photo-crop:load", {
      bubbles: true,
      detail: { url: "/rails/active_storage/second.jpg" }
    }))
    form.dispatchEvent(new Event("reset"))

    expect(controller.previewImage.getAttribute("src")).toBe("/rails/active_storage/second.jpg")
  })
})

describe("the submitted fields", () => {
  test("the crop is posted as one ordinary form field, never a multipart body", () => {
    const { controller } = build()

    expect(controller.valueField().name).toBe("character[photo_data]")
    expect(controller.valueField().type).toBe("hidden")
    expect(controller.removeInput.name).toBe("character[remove_photo]")
  })

  test("removing clears the crop and ticks the checkbox, so the server sees both", () => {
    const { controller } = build({ currentUrl: "/rails/active_storage/photo.jpg" })
    controller.valueField().value = "data:image/jpeg;base64,chosen"

    controller.removeBox().checked = true
    controller.toggleRemove()

    expect(controller.valueField().value).toBe("")
    expect(controller.preview.hidden).toBe(true)
  })

  test("unchecking the remove box puts the stored photo back", () => {
    const { controller } = build({ currentUrl: "/rails/active_storage/photo.jpg" })
    controller.removeBox().checked = true
    controller.toggleRemove()
    controller.removeBox().checked = false
    controller.toggleRemove()

    expect(controller.preview.hidden).toBe(false)
  })
})

describe("the crop square", () => {
  test("a wide image is cropped to the largest square it allows", () => {
    const { controller } = build()

    withImage(controller, 400, 200)

    expect(controller.crop().size).toBe(200)
  })

  test("a tall image is cropped to the largest square it allows", () => {
    const { controller } = build()

    withImage(controller, 200, 400)

    expect(controller.crop().size).toBe(200)
  })

  test("an already square image is cropped whole", () => {
    const { controller } = build()

    withImage(controller, 300, 300)

    expect(controller.crop()).toEqual({ x: 0, y: 0, size: 300 })
  })

  test("the square never leaves the image, however far it is dragged", () => {
    const { controller } = build()
    withImage(controller, 400, 300)

    const drags = [ -10000, 0, 10000, -10000, 10000 ]
    drags.forEach((amount) => {
      controller.panBy(amount, amount)
      const { x, y, size } = controller.crop()

      expect(x).toBeGreaterThanOrEqual(0)
      expect(y).toBeGreaterThanOrEqual(0)
      expect(x + size).toBeLessThanOrEqual(400)
      expect(y + size).toBeLessThanOrEqual(300)
    })
  })

  test("zooming in makes the square smaller, never larger than the image", () => {
    const { controller } = build()
    withImage(controller, 400, 200)

    controller.zoomBy(PhotoCropController.ZOOM_STEP)
    expect(controller.crop().size).toBeLessThan(200)

    controller.zoomBy(PhotoCropController.MAX_ZOOM)
    expect(controller.crop().size).toBeLessThanOrEqual(200)
  })

  test("zooming out stops at the largest square the image allows", () => {
    const { controller } = build()
    withImage(controller, 400, 200)

    controller.zoomBy(-PhotoCropController.MAX_ZOOM)
    expect(controller.crop().size).toBe(200)
  })

  test("zooming recentres the square rather than pushing it off the image", () => {
    const { controller } = build()
    withImage(controller, 400, 200)
    controller.panBy(200, 0)

    controller.zoomBy(PhotoCropController.ZOOM_STEP)

    const { x, size } = controller.crop()
    expect(x).toBeGreaterThanOrEqual(0)
    expect(x + size).toBeLessThanOrEqual(400)
  })
})

describe("keyboard access", () => {
  test("the arrow keys move the image, as the pointer does", () => {
    const { controller } = build()
    withImage(controller, 400, 200)
    const before = controller.crop().x

    controller.nudge({ key: "ArrowRight", preventDefault() {} })

    expect(controller.crop().x).toBeGreaterThan(before)
    controller.nudge({ key: "ArrowLeft", preventDefault() {} })
    expect(controller.crop().x).toBe(before)
  })

  test("plus and minus zoom the image", () => {
    const { controller } = build()
    withImage(controller, 400, 200)
    const before = controller.zoom

    controller.nudge({ key: "+", preventDefault() {} })

    expect(controller.zoom).toBeGreaterThan(before)
  })

  test("a key the crop does not use is left to the browser", () => {
    const { controller } = build()
    withImage(controller, 400, 200)
    let prevented = false

    controller.nudge({ key: "Tab", preventDefault() { prevented = true } })

    expect(prevented).toBe(false)
  })

  test("the four move buttons exist, because dragging is not a keyboard gesture", () => {
    const { controller } = build()
    withImage(controller, 300, 600)
    const before = controller.crop().y

    const buttons = [...controller.nudgeControls().children]

    expect(buttons).toHaveLength(4)
    expect(buttons.map((button) => button.getAttribute("aria-label"))).toEqual([
      "Move left", "Move up", "Move down", "Move right"
    ])
    // Stimulus binds the action in a browser; here the handler is called with the
    // button it reads its direction from.
    expect(buttons.every((button) => button.dataset.action === "photo-crop#nudgeBy")).toBe(true)

    controller.nudgeBy({ currentTarget: buttons.find((button) => button.dataset.dy === "1") })

    expect(controller.crop().y).toBeGreaterThan(before)
  })

  test("the stage says how to use it", () => {
    const { controller } = build()

    expect(controller.stage.getAttribute("aria-label").toLowerCase()).toContain("arrow keys")
    expect(controller.stage.tabIndex).toBe(0)
  })
})

describe("choosing a file", () => {
  test("an unreadable file says so and opens no cropper", async () => {
    const { controller } = build()
    const input = controller.element.querySelector("input[type=file]")
    Object.defineProperty(input, "files", { value: [ new File([], "x.jpg") ] })
    globalThis.Image = class {
      set src(_value) { this.onerror() }
    }

    await controller.choose({ target: input })

    expect(controller.cropper.hidden).toBe(true)
    expect(controller.status.textContent).toContain("could not be read")
    expect(controller.status.classList.contains("text-danger")).toBe(true)
  })

  test("a readable file opens a square and hides the chooser", async () => {
    const { controller } = build()
    const input = controller.element.querySelector("input[type=file]")
    Object.defineProperty(input, "files", { value: [ new File([], "x.jpg") ] })
    globalThis.Image = class {
      set src(_value) { this.naturalWidth = 400; this.naturalHeight = 200; this.onload() }
    }
    globalThis.URL.createObjectURL = () => "blob:photo"
    globalThis.URL.revokeObjectURL = () => {}

    await controller.choose({ target: input })

    expect(controller.cropper.hidden).toBe(false)
    expect(controller.chooser.hidden).toBe(true)
    expect(controller.crop().size).toBe(200)
  })

  test("the file input only offers the formats the server accepts", () => {
    const { controller } = build()

    const accepted = controller.element.querySelector("input[type=file]").accept.split(",")
    expect(accepted).toEqual([ "image/jpeg", "image/png", "image/webp", "image/gif" ])
  })
})
