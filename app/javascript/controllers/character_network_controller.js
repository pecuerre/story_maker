import { Controller } from "@hotwired/stimulus"

// The Network tab's two view toggles. The server renders the whole graph, with
// every node already laid out, so these toggles only hide layers: a node never
// moves when a layer is turned off.
//
// The controls stay real links. Without JavaScript they navigate to the
// server-rendered alternative; with JavaScript the click is intercepted, the
// layers are hidden or shown, and the URL is rewritten in place so a reload or a
// shared link restores the same view.
export default class extends Controller {
  static values = { showUnconnected: Boolean, showFactionLinks: Boolean }
  static targets = [ "unconnectedButton", "unconnectedLabel", "factionButton" ]

  connect() {
    this.apply()
    this.updateButtonHrefs()
  }

  toggleUnconnected(event) {
    event.preventDefault()
    this.showUnconnectedValue = !this.showUnconnectedValue
    this.apply()
    this.updateUrl()
    this.updateButtonHrefs()
  }

  toggleFactionLinks(event) {
    event.preventDefault()
    this.showFactionLinksValue = !this.showFactionLinksValue
    this.apply()
    this.updateUrl()
    this.updateButtonHrefs()
  }

  apply() {
    this.toggleAll("[data-character-network-unconnected]", !this.showUnconnectedValue)
    this.toggleAll("[data-character-network-unconnected-legend]", !this.showUnconnectedValue)

    this.element.querySelectorAll("[data-character-network-faction-link]").forEach((element) => {
      const touchesUnconnected =
        element.dataset.characterNetworkFactionUnconnected === "true"
      const hidden =
        !this.showFactionLinksValue ||
        (!this.showUnconnectedValue && touchesUnconnected)

      element.classList.toggle("character-network-hidden", hidden)
    })

    this.toggleAll("[data-character-network-faction-legend]", !this.showFactionLinksValue)

    if (this.hasUnconnectedButtonTarget) {
      this.unconnectedButtonTarget.setAttribute(
        "aria-pressed",
        String(this.showUnconnectedValue)
      )
    }

    if (this.hasUnconnectedLabelTarget) {
      const labels = this.unconnectedLabelTarget.dataset
      this.unconnectedLabelTarget.textContent = this.showUnconnectedValue
        ? labels.characterNetworkOnLabel
        : labels.characterNetworkOffLabel
    }

    if (this.hasFactionButtonTarget) {
      this.factionButtonTarget.setAttribute(
        "aria-pressed",
        String(this.showFactionLinksValue)
      )
      this.factionButtonTarget.classList.toggle(
        "btn-primary",
        this.showFactionLinksValue
      )
      this.factionButtonTarget.classList.toggle(
        "btn-outline-secondary",
        !this.showFactionLinksValue
      )
    }
  }

  updateUrl() {
    window.history.replaceState(
      {},
      "",
      this.urlFor(this.showUnconnectedValue, this.showFactionLinksValue)
    )
  }

  updateButtonHrefs() {
    if (this.hasUnconnectedButtonTarget) {
      this.unconnectedButtonTarget.href = this.urlFor(
        !this.showUnconnectedValue,
        this.showFactionLinksValue
      )
    }

    if (this.hasFactionButtonTarget) {
      this.factionButtonTarget.href = this.urlFor(
        this.showUnconnectedValue,
        !this.showFactionLinksValue
      )
    }
  }

  urlFor(showUnconnected, showFactionLinks) {
    const url = new URL(window.location.href)
    this.writeParam(url, "show_unconnected", showUnconnected)
    this.writeParam(url, "faction_links", showFactionLinks)

    return url.toString()
  }

  writeParam(url, name, on) {
    if (on) url.searchParams.delete(name)
    else url.searchParams.set(name, "0")
  }

  toggleAll(selector, hidden) {
    this.element.querySelectorAll(selector).forEach((element) => {
      element.classList.toggle("character-network-hidden", hidden)
    })
  }
}
