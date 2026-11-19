import { Controller } from "@hotwired/stimulus"

// The tools rail's width preference: a full labelled column, or a narrow icon
// strip that gives the writing column back 156px.
//
// The state is rendered server-side from a browser cookie (`AppToolsRail`) so
// the first paint is already the chosen width. This controller only flips the
// class, keeps the control's accessible name honest, gives the hidden labels a
// pointer tooltip, and writes the cookie for the next request. The labels stay
// in the document when collapsed, so every link keeps its name; the tooltip is
// the visible equivalent, not the accessible one.
export default class extends Controller {
  connect() {
    this.shell = this.element.closest(".workspace-shell")
    this.button = this.element.querySelector("[data-tools-rail-toggle]")
    this.collapsed = this.readPreference()
    this.shell?.classList.toggle("tools-rail-collapsed", this.collapsed)
    this.apply()
  }

  toggle() {
    if (!this.shell) return

    this.collapsed = !this.collapsed
    this.shell.classList.toggle("tools-rail-collapsed", this.collapsed)
    this.apply()
    this.writePreference()
  }

  // The cookie is the preference; the class is only the render of it. Reading the
  // cookie here reconciles a page Turbo restored from its cache, where the
  // snapshot was taken before the rail was last toggled. With no cookie yet, the
  // server-rendered class is the only answer there is.
  readPreference() {
    const name = this.element.dataset.toolsRailCookie
    const collapsedValue = this.element.dataset.toolsRailCollapsed
    if (!name || !collapsedValue) return this.renderedCollapsed()

    const entry = document.cookie
      .split(";")
      .map((part) => part.trim())
      .find((part) => part.startsWith(`${name}=`))

    return entry ? entry === `${name}=${collapsedValue}` : this.renderedCollapsed()
  }

  renderedCollapsed() {
    return Boolean(this.shell?.classList.contains("tools-rail-collapsed"))
  }

  apply() {
    if (this.button) {
      this.button.setAttribute("aria-expanded", String(!this.collapsed))

      const label = this.button.querySelector("[data-tools-rail-label]")
      const text = this.collapsed ? this.button.dataset.expandLabel : this.button.dataset.collapseLabel
      if (label && text) label.textContent = text
    }

    this.element.querySelectorAll(".sidebar-link").forEach((link) => {
      const label = link.querySelector(".sidebar-link-label")
      if (!label) return

      if (this.collapsed) link.title = label.textContent.trim()
      else link.removeAttribute("title")
    })
  }

  writePreference() {
    const name = this.element.dataset.toolsRailCookie
    const collapsedValue = this.element.dataset.toolsRailCollapsed
    const expandedValue = this.element.dataset.toolsRailExpanded
    if (!name || !collapsedValue || !expandedValue) return

    const value = this.collapsed ? collapsedValue : expandedValue
    // biome-ignore lint/suspicious/noDocumentCookie: the server reads this preference on the next request; the Cookie Store API is not available in every supported browser.
    document.cookie = `${name}=${encodeURIComponent(value)}; path=/; max-age=31536000; samesite=lax`
  }
}
