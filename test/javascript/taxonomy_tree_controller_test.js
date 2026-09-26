import { beforeEach, describe, expect, test } from "bun:test"
import TaxonomyTreeController from "../../app/javascript/controllers/taxonomy_tree_controller"

// The shared hierarchy editor. Its rows, options, and error messages are all
// built from user-controlled values, so the cases below pin the two properties
// the browser suite once discovered the hard way: a rejection explains itself
// next to the field that caused it, and nothing is ever parsed as markup.
function build({ elementHtml = "", modalFields = [] } = {}) {
  const host = document.createElement("div")
  host.innerHTML = elementHtml
  document.body.append(host)

  const controller = new TaxonomyTreeController()
  controller.element = host
  controller.editableValue = true
  controller.modelParamValue = "character_tag"
  controller.modalFieldsValue = JSON.stringify(modalFields)
  controller.hasFieldNameValue = false
  controller.emptyStateTemplate = null
  return { controller, host }
}

function csrfMeta(content) {
  const meta = document.createElement("meta")
  meta.name = "csrf-token"
  meta.content = content
  document.head.append(meta)
  return meta
}

function captureFetch(response = new Response("{}", { status: 200 })) {
  const calls = []
  globalThis.fetch = async (url, options) => {
    calls.push({ url, options })
    if (response instanceof Error) throw response
    return response
  }
  return calls
}

beforeEach(() => {
  document.head.innerHTML = ""
  document.body.innerHTML = ""
  globalThis.fetch = async () => new Response("{}", { status: 200 })
})

describe("taxonomy mutation request", () => {
  test("sends the page's CSRF token and asks for JSON", async () => {
    const meta = csrfMeta("token-from-meta")
    const calls = captureFetch()
    const { controller } = build()

    await controller.request("/u/dark/character_tags/1", "PATCH", { name: "Hero" })

    expect(calls).toHaveLength(1)
    expect(calls[0].url).toBe("/u/dark/character_tags/1")
    expect(calls[0].options.method).toBe("PATCH")
    expect(calls[0].options.headers["X-CSRF-Token"]).toBe("token-from-meta")
    expect(calls[0].options.headers.Accept).toBe("application/json")
    meta.remove()
  })

  test("omits the token header instead of sending an undefined one", async () => {
    const calls = captureFetch()
    const { controller } = build()

    await controller.request("/u/dark/character_tags/1", "DELETE")

    expect(calls[0].options.headers["X-CSRF-Token"]).toBeUndefined()
  })

  test("scopes every value to the model and skips the absent ones", async () => {
    const calls = captureFetch()
    const { controller } = build()

    await controller.request("/u/dark/character_tags/1", "PATCH", {
      name: "Hero",
      parent_id: "",
      position: null,
      character_tag_ids: [ "1", "2" ],
      skipped: undefined
    })

    const body = new URLSearchParams(calls[0].options.body.toString())
    expect([ ...body.keys() ]).toEqual([
      "character_tag[name]",
      "character_tag[parent_id]",
      "character_tag[character_tag_ids][]",
      "character_tag[character_tag_ids][]"
    ])
    expect(body.getAll("character_tag[character_tag_ids][]")).toEqual([ "1", "2" ])
  })

  test("announces a request that never reaches the server", async () => {
    captureFetch(new Error("offline"))
    const { controller, host } = build({ elementHtml: '<div data-taxonomy-tree-status></div>' })

    expect(await controller.request("/u/dark/character_tags/1", "DELETE")).toBeNull()
    expect(host.querySelector("[data-taxonomy-tree-status]").textContent).toContain("network request failed")
  })
})

describe("taxonomy form values", () => {
  test("reads the scoped, array, and plain values out of a form", () => {
    const { controller } = build()
    const form = document.createElement("form")
    form.innerHTML = `
      <input name="character_tag[name]" value="Hero">
      <input name="character_tag[character_tag_ids][]" value="1">
      <input name="character_tag[character_tag_ids][]" value="2">
      <input name="utf8" value="ignored">
      <input name="_method" value="ignored">
    `

    expect(controller.formValues(form)).toEqual({ name: "Hero", character_tag_ids: [ "1", "2" ] })
  })
})

describe("taxonomy error rendering", () => {
  const modalFields = [
    { name: "name", label: "Name", type: "text", required: true },
    { name: "parent_id", label: "Parent tag", type: "select", options: [ [ "1", "Root" ] ] },
    { name: "description", label: "Description", type: "textarea" }
  ]

  function editor() {
    const { controller } = build({ modalFields })
    const modal = document.createElement("div")
    modal.innerHTML = `
      <div data-taxonomy-tree-errors tabindex="-1" hidden></div>
      <div class="mb-3">
        <label class="form-label" for="tag-name">Name</label>
        <input class="form-control" id="tag-name" name="character_tag[name]" type="text">
      </div>
      <div class="mb-3">
        <label class="form-label" for="tag-parent">Parent tag</label>
        <select class="form-select" id="tag-parent" name="character_tag[parent_id]"></select>
      </div>
    `
    document.body.append(modal)
    return { controller, modal }
  }

  test("an error message uses the label the editor shows", () => {
    const { controller } = build({ modalFields })

    expect(controller.errorFieldLabel("name")).toBe("Name")
    expect(controller.errorFieldLabel("parent_id")).toBe("Parent tag")
    // A `belongs_to` rejection is keyed by the association, not its foreign key.
    expect(controller.errorFieldLabel("parent")).toBe("Parent tag")
    expect(controller.errorFieldLabel("unknown_field")).toBe("unknown_field")
  })

  test("the error label builder did not replace the field label builder", () => {
    const { controller } = build({ modalFields })

    const label = controller.fieldLabel({ name: "name", label: "Name", required: true }, "tag-name")

    expect(label.tagName).toBe("LABEL")
    expect(label.className).toBe("form-label")
    expect(label.htmlFor).toBe("tag-name")
    expect(label.textContent).toContain("Name")
    expect(label.querySelector(".text-danger").textContent).toBe(" *")
    expect(label.querySelector(".visually-hidden").textContent).toBe(" (required)")
  })

  test("an association error is reported against its foreign-key field", () => {
    const { controller, modal } = editor()

    const entries = controller.errorEntries({ errors: { parent: [ "can't be blank" ], base: "must belong to a universe" } })

    expect(entries).toEqual([
      [ "parent", [ "Parent tag can't be blank" ] ],
      [ "base", [ "the character tag must belong to a universe" ] ]
    ])

    controller.markFieldInvalid(modal, "parent", [ "Parent tag can't be blank" ])
    const field = modal.querySelector("#tag-parent")
    expect(field.getAttribute("aria-invalid")).toBe("true")
    expect(field.getAttribute("aria-describedby")).toContain("tag-parent-error")
    expect(modal.querySelector(".invalid-feedback").textContent).toBe("Parent tag can't be blank")
  })

  test("a rejected save keeps the editor open with the server's own message", async () => {
    const { controller, modal } = editor()
    captureFetch(new Response(JSON.stringify({ errors: { name: [ "can't be blank" ] } }), { status: 422 }))

    controller.renderFieldErrors(modal, { errors: { name: [ "can't be blank" ] } })

    const region = modal.querySelector("[data-taxonomy-tree-errors]")
    expect(region.hidden).toBe(false)
    expect(region.querySelectorAll("li")).toHaveLength(1)
    expect(modal.querySelector("#tag-name").getAttribute("aria-invalid")).toBe("true")
  })

  test("a rejection with no usable error hash is announced, not rendered", () => {
    const { controller, host } = build({ elementHtml: '<div data-taxonomy-tree-status></div>' })
    const modal = document.createElement("div")
    modal.innerHTML = '<div data-taxonomy-tree-errors hidden></div>'
    document.body.append(modal)

    controller.renderFieldErrors(modal, { errors: "boom" })

    expect(modal.querySelector("[data-taxonomy-tree-errors]").hidden).toBe(true)
    expect(host.querySelector("[data-taxonomy-tree-status]").textContent).toContain("did not explain why")
  })

  test("a single-field path announces the server's message on a 422", async () => {
    const { controller } = build({ modalFields })
    captureFetch(new Response(JSON.stringify({ errors: { name: [ "is already taken" ] } }), { status: 422 }))

    const response = await controller.request("/u/dark/character_tags/1", "PATCH", { name: "Hero" })
    expect(await controller.mutationMessage(response, "The name could not be saved.")).toBe("Name is already taken")
  })

  test("any other status keeps the caller's own fallback", async () => {
    const { controller } = build({ modalFields })
    captureFetch(new Response("{}", { status: 500 }))

    const response = await controller.request("/u/dark/character_tags/1", "DELETE")
    expect(await controller.mutationMessage(response, "The item could not be deleted.")).toBe("The item could not be deleted.")
  })
})

describe("taxonomy row building", () => {
  test("a color is only accepted in the documented format", () => {
    const { controller } = build()

    expect(controller.safeColor("#a1b2c3")).toBe(true)
    expect(controller.safeColor("#A1B2C3")).toBe(true)
    expect(controller.safeColor("red")).toBe(false)
    expect(controller.safeColor("#fff")).toBe(false)
    expect(controller.safeColor("url(javascript:alert(1))")).toBe(false)
    expect(controller.safeColor(undefined)).toBe(false)
  })

  test("a hostile name stays text and injects no element", () => {
    const { controller, host } = build()
    const hostile = '<img src=x onerror="window.pwned = true">'

    const trigger = controller.buildNameTrigger({
      name: hostile,
      bgcolor: "#ff0000",
      fgcolor: "javascript:alert(1)",
      recordCountLabel: "(4 characters)",
      description: "<script>window.pwned = true</script>"
    })
    host.append(trigger)

    expect(trigger.tagName).toBe("BUTTON")
    expect(trigger.getAttribute("aria-label")).toBe(`Rename ${hostile}`)
    expect(trigger.querySelector("img")).toBeNull()
    expect(trigger.querySelector("script")).toBeNull()
    expect(trigger.querySelector(".badge").textContent).toBe(hostile)
    // An unusable foreground color is dropped rather than written into the style.
    expect(trigger.querySelector(".badge").style.color).toBe("")
    expect(trigger.querySelector(".record-count").textContent).toBe("(4 characters)")
    expect(trigger.querySelector(".entity-description").textContent).toBe("<script>window.pwned = true</script>")
  })

  test("a node without a usable color still shows its name", () => {
    const { controller } = build()

    const fragment = controller.buildNameContent({ name: "Root", bgcolor: "not-a-color" })

    expect(fragment.querySelector(".entity-title").textContent).toBe("Root")
    expect(fragment.querySelector(".badge")).toBeNull()
  })

  test("a cancelled inline rename restores the server's name, not the typed one", () => {
    const { controller, host } = build({
      elementHtml: `
        <div class="taxonomy-surface">
          <ul class="taxonomy-list" data-drop-parent-id="">
            <li class="taxonomy-node" data-node-id="3">
              <form><input name="name" value="Never saved"></form>
            </li>
          </ul>
        </div>
      `
    })
    const node = host.querySelector("[data-node-id]")
    node.dataset.name = "Hero"
    node.dataset.taxonomyValues = JSON.stringify({ name: "Hero", bgcolor: "#00ff00" })
    node.dataset.recordCountLabel = "(4 characters)"

    controller.restoreName(node.querySelector("form"))

    const trigger = host.querySelector("[data-taxonomy-tree-target='name']")
    expect(host.querySelector("form")).toBeNull()
    expect(trigger.tagName).toBe("BUTTON")
    expect(trigger.textContent).toContain("Hero")
    expect(trigger.textContent).not.toContain("Never saved")
    expect(trigger.textContent).toContain("(4 characters)")
    expect(document.activeElement).toBe(trigger)
  })
})

describe("taxonomy announcements", () => {
  test("a failure is visible and a progress note is not", () => {
    const { controller, host } = build({ elementHtml: '<div data-taxonomy-tree-status></div>' })
    const status = host.querySelector("[data-taxonomy-tree-status]")

    controller.announce("Saved. Refreshing the taxonomy…")
    expect(status.classList.contains("visually-hidden")).toBe(true)
    expect(status.classList.contains("text-danger")).toBe(false)

    controller.announce("The name could not be saved.", true)
    expect(status.classList.contains("visually-hidden")).toBe(false)
    expect(status.classList.contains("text-danger")).toBe(true)
    expect(status.textContent).toBe("The name could not be saved.")
  })

  test("a malformed serialized value falls back instead of throwing", () => {
    const { controller } = build()

    expect(controller.parseJson("{oops", [])).toEqual([])
    expect(controller.parseJson(undefined, null)).toBeNull()
    expect(controller.escapeRegExp("a[b]c")).toBe("a\\[b\\]c")
  })
})
