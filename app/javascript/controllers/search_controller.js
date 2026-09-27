import { Controller } from "@hotwired/stimulus"

// The autocomplete half of the top-bar search box.
//
// The box is a form first: submitting it opens the results page, which is
// shareable and works without scripting. This controller only adds the answer
// *while* someone is typing, and it never decides what is searchable — the
// server sends the results, the scope, and any reason there are none.
//
// Focus stays in the input. Arrowing moves a cursor through the options with
// `aria-activedescendant` rather than moving focus, so the caret and the
// selection are still the reader's while they look at the list — the behaviour
// a combobox is expected to have.
//
// Every node here is built with DOM APIs and every piece of text goes in as
// text: a result carries the author's own words, and they are never parsed as
// markup.
export default class extends Controller {
  static targets = [ "input", "scope", "results", "status", "allLink" ]
  static values = { minimum: Number, delay: Number }

  connect() {
    this.timer = null
    this.latestRequest = 0
    this.activeIndex = -1
    this.options = []

    // The dropdown is a child of the form, so a click anywhere else on the page
    // has to close it. Listening on the document is what makes that true, and
    // disconnecting has to undo it or every visit would add another listener.
    this.closeOnOutsideClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    document.addEventListener("click", this.closeOnOutsideClick, true)
  }

  disconnect() {
    this.cancelPending()
    document.removeEventListener("click", this.closeOnOutsideClick, true)
  }

  // Any change to the text or the scope asks the same question again: the scope
  // is part of the question, not a display preference.
  query() {
    this.cancelPending()
    this.close()

    const text = this.inputTarget.value.trim()
    if (text.length < this.minimumValue) {
      this.announce(text.length > 0 ? `Type ${this.minimumValue - text.length} more characters to search.` : "")
      return
    }

    this.timer = setTimeout(() => this.ask(text), this.delayValue)
  }

  navigate(event) {
    if (this.options.length > 0) {
      if (event.key === "ArrowDown") {
        event.preventDefault()
        this.move(1)
        return
      }
      if (event.key === "ArrowUp") {
        event.preventDefault()
        this.move(-1)
        return
      }
      if (event.key === "Enter" && this.activeIndex >= 0) {
        event.preventDefault()
        this.follow()
        return
      }
    }

    if (event.key === "Escape") {
      // A closed box must not swallow the key: Escape still leaves whatever else
      // the reader was on the page to leave.
      if (this.isOpen()) {
        event.preventDefault()
        this.close()
      }
      return
    }

    if (event.key === "Tab") this.close()
  }

  async ask(text) {
    const request = ++this.latestRequest
    this.busy(true)

    const response = await this.fetchResults()
    // A later keystroke has already asked its own question; this answer belongs
    // to a question nobody is waiting for any more.
    if (request !== this.latestRequest) return

    this.busy(false)
    if (response) this.render(response, text)
  }

  async fetchResults() {
    try {
      const response = await window.fetch(this.resultsUrl(), {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) return null
      return await response.json()
    } catch (_error) {
      // A network failure is not a result. It is reported as a problem, which is
      // the same answer the server gives for an engine it cannot reach.
      return { available: false, reason: "Search could not be reached.", results: [], commands: [] }
    }
  }

  // The form's own action and fields, so the request is the same GET the form
  // would have submitted — including the story boundary — and the dropdown can
  // never ask a different question from the page.
  resultsUrl() {
    const url = new URL(this.element.getAttribute("action") || window.location.href, window.location.origin)
    const fields = new URLSearchParams(new window.FormData(this.element))
    fields.forEach((value, key) => {
      url.searchParams.set(key, value)
    })
    return url.toString()
  }

  render(payload, text) {
    if (!payload.available) {
      this.show([ this.message(`Search is not available. ${payload.reason || ""}`.trim()) ], { allLink: false })
      this.announce("Search is not available.")
      return
    }

    const groups = []
    if (payload.commands && payload.commands.length > 0) groups.push([ "Go to", payload.commands, "command" ])
    if (payload.results && payload.results.length > 0) groups.push([ "Results", payload.results, "result" ])

    if (groups.length === 0) {
      this.show([ this.message(`No matches for “${text}”.`) ], { allLink: false })
      this.announce(`No matches for ${text}.`)
      return
    }

    const nodes = []
    this.options = []
    groups.forEach(([ label, items, kind ]) => {
      const group = this.group(label)
      items.forEach((item) => {
        const option = this.option(item, text, kind)
        group.append(option)
        this.options.push(option)
      })
      nodes.push(group)
    })
    this.show(nodes)

    const count = this.options.length
    this.announce(`${count} ${count === 1 ? "result" : "results"} for ${text}.`)
  }

  // `allLink` is the way into the full answer, so it appears only when there is
  // an answer to see. A "no matches" or "unavailable" message has none.
  show(nodes, { allLink = true } = {}) {
    this.resultsTarget.replaceChildren(...nodes)
    this.resultsTarget.hidden = false
    this.inputTarget.setAttribute("aria-expanded", "true")
    this.activeIndex = -1
    this.inputTarget.removeAttribute("aria-activedescendant")
    this.allLinkTarget.hidden = !allLink
    this.allLinkTarget.href = this.resultsUrl()
  }

  close() {
    this.resultsTarget.replaceChildren()
    this.resultsTarget.hidden = true
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.removeAttribute("aria-activedescendant")
    this.options = []
    this.activeIndex = -1
    this.allLinkTarget.hidden = true
  }

  isOpen() {
    return !this.resultsTarget.hidden
  }

  move(step) {
    const count = this.options.length
    if (count === 0) return

    this.activeIndex = (this.activeIndex + step + count) % count
    this.options.forEach((option, index) => {
      const active = index === this.activeIndex
      option.classList.toggle("active", active)
      option.setAttribute("aria-selected", active ? "true" : "false")
    })

    const active = this.options[this.activeIndex]
    this.inputTarget.setAttribute("aria-activedescendant", active.id)
    active.scrollIntoView?.({ block: "nearest" })
  }

  follow() {
    const active = this.options[this.activeIndex]
    if (active) window.location.assign(active.href)
  }

  // A group is labelled once, and its visible heading is hidden from assistive
  // technology so the label is not read twice. Both groups are inside one
  // listbox because a reader arrows through them as a single list.
  group(label) {
    const group = document.createElement("div")
    group.className = "navbar-search-group"
    group.setAttribute("role", "group")
    group.setAttribute("aria-label", label)

    const heading = document.createElement("div")
    heading.className = "navbar-search-group-title"
    heading.setAttribute("aria-hidden", "true")
    heading.textContent = label
    group.append(heading)

    return group
  }

  message(text) {
    const node = document.createElement("div")
    node.className = "navbar-search-message"
    node.setAttribute("role", "option")
    node.setAttribute("aria-disabled", "true")
    node.textContent = text
    return node
  }

  // A result is a real link, so it can be opened without scripting, middle
  // clicked, or copied. Its title is written as text with the matched run marked
  // up, because the author's own words are data and not markup.
  option(item, text, kind) {
    const link = document.createElement("a")
    link.className = `navbar-search-${kind}`
    link.href = item.url
    link.id = `${this.resultsTarget.id}_option_${this.options.length}`
    link.setAttribute("role", "option")
    link.setAttribute("aria-selected", "false")

    const label = document.createElement("span")
    label.className = "navbar-search-result-kind"
    label.textContent = item.kind_label || labelFor(kind)
    link.append(label)

    const title = document.createElement("span")
    title.className = "navbar-search-result-title"
    this.appendMarked(title, item.title || "", text)
    link.append(title)

    if (item.subtitle) {
      const context = document.createElement("span")
      context.className = "navbar-search-result-context"
      context.textContent = item.subtitle
      link.append(context)
    }

    if (item.snippet) {
      const snippet = document.createElement("span")
      snippet.className = "navbar-search-result-snippet"
      snippet.textContent = item.snippet
      link.append(snippet)
    }

    return link
  }

  appendMarked(parent, text, needle) {
    const index = needle ? text.toLowerCase().indexOf(needle.toLowerCase()) : -1
    if (index < 0) {
      parent.textContent = text
      return
    }

    const end = index + needle.length
    parent.append(document.createTextNode(text.slice(0, index)))
    const mark = document.createElement("mark")
    mark.textContent = text.slice(index, end)
    parent.append(mark, document.createTextNode(text.slice(end)))
  }

  busy(busy) {
    this.inputTarget.setAttribute("aria-busy", busy ? "true" : "false")
  }

  cancelPending() {
    if (this.timer) clearTimeout(this.timer)
    this.timer = null
  }

  announce(message) {
    this.statusTarget.textContent = message
  }
}

// A command is a destination rather than a record, so it is labelled as one. The
// server sends its own label; this is only the last resort for a payload that
// carries none.
function labelFor(kind) {
  return kind === "command" ? "Go to" : "Result"
}
