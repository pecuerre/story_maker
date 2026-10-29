import { beforeEach, describe, expect, test } from "bun:test"
import NameConfirmationController from "../../app/javascript/controllers/name_confirmation_controller"

// The permanent-delete form asks the reader to type the universe's name. The
// server compares it exactly, so this controller may only mirror that rule: it
// must not trim, downcase, or otherwise "help", because a button enabled by a
// looser comparison would send a request the server refuses and make the reader
// think the name had matched.
describe("the name confirmation controller", () => {
  function build(expected) {
    const form = document.createElement("form")
    const input = document.createElement("input")
    const submit = document.createElement("button")

    input.type = "text"
    submit.type = "submit"
    form.append(input, submit)
    document.body.append(form)

    const controller = new NameConfirmationController()
    controller.element = form
    controller.inputTarget = input
    controller.submitTarget = submit
    controller.expectedValue = expected
    controller.connect()

    return { controller, input, submit }
  }

  beforeEach(() => {
    document.body.innerHTML = ""
  })

  test("the button starts disabled while the field is empty", () => {
    const { submit } = build("Universe one")

    expect(submit.disabled).toBe(true)
  })

  test("the exact name, including capitals and punctuation, enables the button", () => {
    const { controller, input, submit } = build("Eärendil, The Mariner!")

    input.value = "Eärendil, The Mariner!"
    controller.check()

    expect(submit.disabled).toBe(false)
  })

  test("a missing comma is a different name", () => {
    const { controller, input, submit } = build("Eärendil, The Mariner!")

    input.value = "Eärendil The Mariner!"
    controller.check()

    expect(submit.disabled).toBe(true)
  })

  test("case folding is not applied", () => {
    const { controller, input, submit } = build("Universe one")

    input.value = "universe one"
    controller.check()

    expect(submit.disabled).toBe(true)
  })

  test("leading or trailing whitespace is not trimmed", () => {
    const { controller, input, submit } = build("Universe one")

    input.value = " Universe one "
    controller.check()

    expect(submit.disabled).toBe(true)
  })

  test("deleting back to a mismatch disables the button again", () => {
    const { controller, input, submit } = build("Universe one")

    input.value = "Universe one"
    controller.check()
    expect(submit.disabled).toBe(false)

    input.value = "Universe on"
    controller.check()
    expect(submit.disabled).toBe(true)
  })
})
