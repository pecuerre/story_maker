import { beforeEach, describe, expect, test } from "bun:test"
import SearchController from "../../app/javascript/controllers/search_controller"

// The autocomplete half of the top-bar search box. The box is a form first —
// submitting it opens the results page — so what is under test here is only the
// enhancement: that it asks the server, renders what came back, and lets a reader
// drive the list from the keyboard without losing the caret.
const RESPONSE = {
  available: true,
  query: "hannah",
  scope: "universe",
  scope_label: "This universe",
  total: 1,
  discarded: [],
  commands: [],
  results: [
    {
      id: "character-4",
      kind: "character",
      kind_label: "Character",
      title: "Hannah",
      subtitle: "Dark",
      snippet: "A mother who disappears.",
      url: "/u/dark/characters/4"
    }
  ]
}

function build({ action = "/u/dark/search" } = {}) {
  const host = document.createElement("div")
  host.innerHTML = `
    <form data-controller="search" data-search-minimum-value="2" data-search-delay-value="1" action="${action}">
      <input name="q" data-search-target="input" />
      <select name="scope" data-search-target="scope">
        <option value="universe" selected>This universe</option>
        <option value="platform">Entire platform</option>
      </select>
      <input type="hidden" name="story_id" value="7" />
      <div role="listbox" data-search-target="results" hidden></div>
      <p data-search-target="status"></p>
      <a data-search-target="allLink" hidden>See all results</a>
    </form>
  `
  document.body.append(host)

  const form = host.querySelector("form")
  const controller = new SearchController()
  controller.element = form
  controller.inputTarget = form.querySelector("[data-search-target='input']")
  controller.scopeTarget = form.querySelector("[data-search-target='scope']")
  controller.resultsTarget = form.querySelector("[data-search-target='results']")
  controller.statusTarget = form.querySelector("[data-search-target='status']")
  controller.allLinkTarget = form.querySelector("[data-search-target='allLink']")
  controller.minimumValue = 2
  controller.delayValue = 1
  controller.connect()
  return { controller, form, input: controller.inputTarget }
}

function captureFetch(payload = RESPONSE, { ok = true } = {}) {
  const calls = []
  globalThis.fetch = async (url, options) => {
    calls.push({ url, options })
    return new Response(JSON.stringify(payload), { status: ok ? 200 : 500 })
  }
  return calls
}

const wait = () => new Promise((resolve) => setTimeout(resolve, 5))

beforeEach(() => {
  document.head.innerHTML = ""
  document.body.innerHTML = ""
  globalThis.fetch = async () => new Response("{}", { status: 200 })
})

describe("asking the server", () => {
  test("one character asks nothing, and says how much more is needed", async () => {
    const calls = captureFetch()
    const { controller, input } = build()

    input.value = "h"
    controller.query()
    await wait()

    expect(calls.length).toBe(0)
    // The shortfall is a count, so the plural is the locale's: one character
    // left is not "1 more characters", which is what a client-side
    // `count === 1 ? …` would have printed here.
    expect(controller.statusTarget.textContent).toBe("Type 1 more character to search.")
    expect(controller.resultsTarget.hidden).toBe(true)
  })

  test("an empty box asks nothing and says nothing", async () => {
    const calls = captureFetch()
    const { controller, input } = build()

    input.value = "   "
    controller.query()
    await wait()

    expect(calls.length).toBe(0)
    // Nothing typed is not a shortfall to report: a reader who has not started
    // has not been told anything wrong.
    expect(controller.statusTarget.textContent).toBe("")
  })

  test("the request is the form's own GET, so the dropdown cannot ask a different question", async () => {
    const calls = captureFetch()
    const { controller, input } = build()

    input.value = "hannah"
    controller.query()
    await wait()

    expect(calls.length).toBe(1)
    const url = new URL(calls[0].url)
    expect(url.pathname).toBe("/u/dark/search")
    expect(url.searchParams.get("q")).toBe("hannah")
    expect(url.searchParams.get("scope")).toBe("universe")
    // The story boundary travels with the form and is asked as part of the search.
    expect(url.searchParams.get("story_id")).toBe("7")
    expect(calls[0].options.headers.Accept).toBe("application/json")
    // A read is not a mutation, so no token is sent.
    expect(calls[0].options.headers["X-CSRF-Token"]).toBeUndefined()
  })

  test("changing the scope asks again, because the scope is part of the question", async () => {
    const calls = captureFetch()
    const { controller, input } = build()

    input.value = "hannah"
    controller.query()
    await wait()
    controller.scopeTarget.value = "platform"
    controller.query()
    await wait()

    expect(calls.length).toBe(2)
    expect(new URL(calls[1].url).searchParams.get("scope")).toBe("platform")
  })

  test("a burst of typing asks once", async () => {
    const calls = captureFetch()
    const { controller, input } = build()

    input.value = "h"
    controller.query()
    input.value = "ha"
    controller.query()
    input.value = "han"
    controller.query()
    await wait()

    expect(calls.length).toBe(1)
    expect(new URL(calls[0].url).searchParams.get("q")).toBe("han")
  })

  test("an answer to a question nobody is waiting for is dropped", async () => {
    const calls = []
    const pending = []
    globalThis.fetch = (url) => {
      calls.push(url)
      return new Promise((resolve) => pending.push(resolve))
    }
    const { controller, input } = build()

    input.value = "hannah"
    controller.query()
    await wait()
    input.value = "hannah Kent"
    controller.query()
    await wait()

    // The first question is answered after the second one was asked. Its answer
    // belongs to a question nobody is waiting for any more.
    pending[0](new Response(JSON.stringify(RESPONSE)))
    await wait()

    expect(calls.length).toBe(2)
    expect(controller.resultsTarget.querySelectorAll("[role='option']").length).toBe(0)

    // The answer the reader *is* waiting for still fills the list.
    pending[1](new Response(JSON.stringify(RESPONSE)))
    await wait()
    expect(controller.resultsTarget.querySelectorAll("[role='option']").length).toBe(1)
  })

  test("a network failure is reported as a problem, not as no results", async () => {
    globalThis.fetch = async () => { throw new Error("offline") }
    const { controller, input } = build()

    input.value = "hannah"
    controller.query()
    await wait()

    expect(controller.statusTarget.textContent).toBe("Search is not available.")
    expect(controller.resultsTarget.textContent).toContain("could not be reached")
  })

  test("a failed response is not treated as an answer", async () => {
    captureFetch(RESPONSE, { ok: false })
    const { controller, input } = build()

    input.value = "hannah"
    controller.query()
    await wait()

    expect(controller.resultsTarget.hidden).toBe(true)
    expect(controller.inputTarget.getAttribute("aria-busy")).toBe("false")
  })
})

describe("rendering an answer", () => {
  test("a result is a link, inside a labelled group, inside the listbox", async () => {
    captureFetch()
    const { controller, input } = build()

    input.value = "hannah"
    controller.query()
    await wait()

    const listbox = controller.resultsTarget
    expect(listbox.hidden).toBe(false)
    expect(listbox.getAttribute("role")).toBe("listbox")
    expect(input.getAttribute("aria-expanded")).toBe("true")

    const group = listbox.querySelector("[role='group']")
    expect(group.getAttribute("aria-label")).toBe("Results")
    // The visible heading is hidden from assistive technology, because the group
    // already carries the same label.
    expect(group.querySelector(".navbar-search-group-title").getAttribute("aria-hidden")).toBe("true")

    const option = listbox.querySelector("[role='option']")
    expect(option.tagName).toBe("A")
    expect(option.getAttribute("href")).toBe("/u/dark/characters/4")
    expect(option.getAttribute("aria-selected")).toBe("false")
    expect(option.textContent).toContain("Character")
    expect(option.textContent).toContain("Hannah")
    expect(option.textContent).toContain("Dark")
    expect(option.textContent).toContain("A mother who disappears.")
  })

  test("commands and results are separate groups, commands first", async () => {
    captureFetch({
      ...RESPONSE,
      commands: [ { id: "characters", title: "Characters", subtitle: "Dark", url: "/u/dark/characters" } ]
    })
    const { controller, input } = build()

    input.value = "chara"
    controller.query()
    await wait()

    const groups = [ ...controller.resultsTarget.querySelectorAll("[role='group']") ]
    expect(groups.map((group) => group.getAttribute("aria-label"))).toEqual([ "Go to", "Results" ])
    expect(groups[0].querySelector("[role='option']").getAttribute("href")).toBe("/u/dark/characters")
  })

  test("a result's own text is never parsed as markup", async () => {
    captureFetch({
      ...RESPONSE,
      results: [ { ...RESPONSE.results[0], title: "<img src=x onerror=alert(1)>", snippet: "<b>bold</b>" } ]
    })
    const { controller, input } = build()

    input.value = "hannah"
    controller.query()
    await wait()

    const option = controller.resultsTarget.querySelector("[role='option']")
    expect(option.querySelector("img")).toBeNull()
    expect(option.querySelector("b")).toBeNull()
    expect(option.textContent).toContain("<img src=x onerror=alert(1)>")
  })

  test("the matched run is marked up, and only the matched run", async () => {
    captureFetch()
    const { controller, input } = build()

    input.value = "HAN"
    controller.query()
    await wait()

    const title = controller.resultsTarget.querySelector(".navbar-search-result-title")
    expect(title.textContent).toBe("Hannah")
    const mark = title.querySelector("mark")
    // The author's own casing is left alone: only the run is marked.
    expect(mark.textContent).toBe("Han")
    expect([ ...title.childNodes ].filter((node) => node.nodeType === 3).map((node) => node.textContent))
      .toEqual([ "", "nah" ])
  })

  test("a title that does not contain the text is left alone", async () => {
    captureFetch({ ...RESPONSE, results: [ { ...RESPONSE.results[0], title: "Kafka", body: null, snippet: null } ] })
    const { controller, input } = build()

    input.value = "hannah"
    controller.query()
    await wait()

    const title = controller.resultsTarget.querySelector(".navbar-search-result-title")
    expect(title.querySelector("mark")).toBeNull()
    expect(title.textContent).toBe("Kafka")
  })

  test("the count is announced, and a single result is not plural", async () => {
    captureFetch()
    const { controller, input } = build()

    input.value = "hannah"
    controller.query()
    await wait()

    expect(controller.statusTarget.textContent).toBe("1 result for hannah.")
  })

  test("no matches is stated, with no path to a page that would also be empty", async () => {
    captureFetch({ ...RESPONSE, results: [], commands: [] })
    const { controller, input } = build()

    input.value = "zzzz"
    controller.query()
    await wait()

    expect(controller.statusTarget.textContent).toBe("No matches for zzzz.")
    const option = controller.resultsTarget.querySelector("[role='option']")
    expect(option.getAttribute("aria-disabled")).toBe("true")
    expect(option.textContent).toContain("No matches")
    expect(controller.allLinkTarget.hidden).toBe(true)
  })

  test("an unavailable engine is stated with the reason the server gave", async () => {
    captureFetch({ available: false, reason: "Search is not configured.", results: [], commands: [] })
    const { controller, input } = build()

    input.value = "hannah"
    controller.query()
    await wait()

    expect(controller.statusTarget.textContent).toBe("Search is not available.")
    expect(controller.resultsTarget.textContent).toContain("Search is not configured.")
  })

  test("the way into the full answer carries the search that was asked", async () => {
    captureFetch()
    const { controller, input } = build()

    input.value = "hannah"
    controller.query()
    await wait()

    expect(controller.allLinkTarget.hidden).toBe(false)
    const url = new URL(controller.allLinkTarget.href)
    expect(url.pathname).toBe("/u/dark/search")
    expect(url.searchParams.get("q")).toBe("hannah")
  })
})

describe("driving the list from the keyboard", () => {
  // There is no Stimulus application here, so the key handler is called the way
  // the browser would: with a real cancellable event, whose `defaultPrevented` is
  // what tells a reader's key press apart from the page's own behaviour.
  const press = (controller, key) => {
    const event = new KeyboardEvent("keydown", { key, cancelable: true })
    controller.navigate(event)
    return event
  }

  test("the focus stays in the input while a cursor moves through the options", async () => {
    captureFetch({
      ...RESPONSE,
      commands: [ { id: "characters", title: "Characters", subtitle: "Dark", url: "/u/dark/characters" } ]
    })
    const { controller, input } = build()
    input.value = "hannah"
    controller.query()
    await wait()

    expect(press(controller, "ArrowDown").defaultPrevented).toBe(true)
    press(controller, "ArrowDown")

    const options = controller.options
    expect(options.length).toBe(2)
    expect(options[1].classList.contains("active")).toBe(true)
    expect(options[1].getAttribute("aria-selected")).toBe("true")
    // The combobox pattern: the input keeps focus and points at the active option.
    expect(input.getAttribute("aria-activedescendant")).toBe(options[1].id)
    expect(document.activeElement).not.toBe(options[1])
  })

  test("the cursor wraps and never leaves the list", async () => {
    captureFetch()
    const { controller, input } = build()
    input.value = "hannah"
    controller.query()
    await wait()

    press(controller, "ArrowUp")
    expect(controller.options[0].classList.contains("active")).toBe(true)

    press(controller, "ArrowDown")
    expect(controller.options[0].classList.contains("active")).toBe(true)
  })

  test("Enter follows the active option, and is not a form submission", async () => {
    captureFetch()
    const { controller, input } = build()
    const followed = []
    globalThis.location.assign = (url) => followed.push(url)

    input.value = "hannah"
    controller.query()
    await wait()
    press(controller, "ArrowDown")

    expect(press(controller, "Enter").defaultPrevented).toBe(true)
    // `location.assign` is given the link's resolved URL, as a browser resolves it.
    expect(followed).toEqual([ "http://localhost/u/dark/characters/4" ])
  })

  test("Enter with no active option is left to the form, so the page answers", async () => {
    captureFetch()
    const { controller, input } = build()
    const followed = []
    globalThis.location.assign = (url) => followed.push(url)

    input.value = "hannah"
    controller.query()
    await wait()

    expect(press(controller, "Enter").defaultPrevented).toBe(false)
    expect(followed).toEqual([])
  })

  test("Escape closes the dropdown and only then does it stop being handled", async () => {
    captureFetch()
    const { controller, input } = build()

    input.value = "hannah"
    controller.query()
    await wait()

    expect(press(controller, "Escape").defaultPrevented).toBe(true)
    expect(controller.resultsTarget.hidden).toBe(true)
    expect(input.getAttribute("aria-expanded")).toBe("false")
    expect(input.hasAttribute("aria-activedescendant")).toBe(false)

    // A closed box must not swallow the key from whatever else is on the page.
    expect(press(controller, "Escape").defaultPrevented).toBe(false)
  })

  test("arrow keys are the page's own while the dropdown is closed", async () => {
    const { controller } = build()

    expect(press(controller, "ArrowDown").defaultPrevented).toBe(false)
    expect(controller.options.length).toBe(0)
  })

  test("typing again closes the list before asking the new question", async () => {
    captureFetch()
    const { controller, input } = build()

    input.value = "hannah"
    controller.query()
    await wait()
    expect(controller.resultsTarget.hidden).toBe(false)

    input.value = "hannah k"
    controller.query()

    expect(controller.resultsTarget.hidden).toBe(true)
    expect(controller.allLinkTarget.hidden).toBe(true)
  })

  test("a click outside closes the dropdown", async () => {
    captureFetch()
    const { controller, input } = build()

    input.value = "hannah"
    controller.query()
    await wait()

    document.body.click()
    expect(controller.resultsTarget.hidden).toBe(true)
  })

  test("a click inside the dropdown leaves it open, so the link can be followed", async () => {
    captureFetch()
    const { controller, input } = build()

    input.value = "hannah"
    controller.query()
    await wait()

    controller.resultsTarget.querySelector("[role='option']").click()
    expect(controller.resultsTarget.hidden).toBe(false)
  })

  test("leaving the page removes the document listener the controller added", async () => {
    captureFetch()
    const { controller, input } = build()
    input.value = "hannah"
    controller.query()
    await wait()

    controller.disconnect()
    document.body.click()

    // No listener, no error, and the state is left as it was.
    expect(controller.resultsTarget.hidden).toBe(false)
  })
})
