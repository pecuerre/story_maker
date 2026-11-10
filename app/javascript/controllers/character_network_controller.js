import { Controller } from "@hotwired/stimulus"

// The Network tab's three view checkboxes. The server renders the whole graph,
// with every node already laid out, so these checkboxes only hide layers: a node
// never moves when a layer is turned off.
//
// The controls are real checkboxes in a GET form. With JavaScript the change is
// applied in place and the URL is rewritten so a reload or a shared link restores
// the same view. Without it the form's Apply button navigates to the
// server-rendered alternative.
export default class extends Controller {
  static values = {
    showUnconnected: Boolean,
    showRelationLinks: Boolean,
    showFactionLinks: Boolean
  }

  connect() {
    this.apply()
  }

  toggleUnconnected(event) {
    this.showUnconnectedValue = event.target.checked
    this.apply()
    this.updateUrl()
  }

  toggleRelationLinks(event) {
    this.showRelationLinksValue = event.target.checked
    this.apply()
    this.updateUrl()
  }

  toggleFactionLinks(event) {
    this.showFactionLinksValue = event.target.checked
    this.apply()
    this.updateUrl()
  }

  apply() {
    this.toggleAll("[data-character-network-unconnected]", !this.showUnconnectedValue)
    this.toggleAll(
      "[data-character-network-unconnected-legend]",
      !this.showUnconnectedValue
    )

    this.querySelectorAll("[data-character-network-relation-link]").forEach(
      (element) => {
        const touchesUnconnected =
          element.dataset.characterNetworkRelationUnconnected === "true"
        const hidden =
          !this.showRelationLinksValue ||
          (!this.showUnconnectedValue && touchesUnconnected)

        element.classList.toggle("character-network-hidden", hidden)
      }
    )

    this.toggleAll(
      "[data-character-network-relation-legend]",
      !this.showRelationLinksValue
    )

    this.querySelectorAll("[data-character-network-faction-link]").forEach(
      (element) => {
        const touchesUnconnected =
          element.dataset.characterNetworkFactionUnconnected === "true"
        const hidden =
          !this.showFactionLinksValue ||
          (!this.showUnconnectedValue && touchesUnconnected)

        element.classList.toggle("character-network-hidden", hidden)
      }
    )

    this.toggleAll(
      "[data-character-network-faction-legend]",
      !this.showFactionLinksValue
    )
  }

  updateUrl() {
    window.history.replaceState(
      {},
      "",
      this.urlFor(
        this.showUnconnectedValue,
        this.showRelationLinksValue,
        this.showFactionLinksValue
      )
    )
  }

  urlFor(showUnconnected, showRelationLinks, showFactionLinks) {
    const url = new URL(window.location.href)
    this.writeParam(url, "show_unconnected", showUnconnected)
    this.writeParam(url, "relation_links", showRelationLinks)
    this.writeParam(url, "faction_links", showFactionLinks)

    return url.toString()
  }

  writeParam(url, name, on) {
    if (on) url.searchParams.delete(name)
    else url.searchParams.set(name, "0")
  }

  toggleAll(selector, hidden) {
    this.querySelectorAll(selector).forEach((element) => {
      element.classList.toggle("character-network-hidden", hidden)
    })
  }

  querySelectorAll(selector) {
    return this.element.querySelectorAll(selector)
  }
}
