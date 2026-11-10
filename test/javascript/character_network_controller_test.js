import { beforeEach, describe, expect, test } from "bun:test"
import CharacterNetworkController from "../../app/javascript/controllers/character_network_controller"

// The three view checkboxes on the Character network. The server renders the
// whole graph with fixed coordinates; this controller must only hide layers,
// never remove or move a node, and it must keep the URL pointing at the visible
// state. Without JavaScript the form's Apply button does the same through a
// normal navigation.
function build({
  showUnconnected = true,
  showRelationLinks = true,
  showFactionLinks = true
} = {}) {
  const host = document.createElement("div")
  host.innerHTML = `
    <div data-controller="character-network">
      <input type="checkbox" name="show_unconnected" checked>
      <input type="checkbox" name="relation_links" checked>
      <input type="checkbox" name="faction_links" checked>
      <a class="character-network-node" data-character-network-unconnected="true"></a>
      <a class="character-network-node"></a>
      <line class="character-network-faction-link" data-character-network-faction-link data-character-network-faction-unconnected="true"></line>
      <line class="character-network-faction-link" data-character-network-faction-link></line>
      <line class="character-network-relation-link" data-character-network-relation-link data-character-network-relation-unconnected="true"></line>
      <line class="character-network-relation-link" data-character-network-relation-link></line>
      <li data-character-network-unconnected-legend></li>
      <li data-character-network-relation-legend></li>
      <li data-character-network-faction-legend></li>
    </div>
  `
  document.body.append(host)

  const root = host.querySelector("[data-controller]")
  const controller = new CharacterNetworkController()
  controller.element = root
  controller.showUnconnectedValue = showUnconnected
  controller.showRelationLinksValue = showRelationLinks
  controller.showFactionLinksValue = showFactionLinks
  controller.connect()

  return { controller, root }
}

const hidden = (element) =>
  element.classList.contains("character-network-hidden")

const change = (checked) => ({ target: { checked } })

beforeEach(() => {
  document.body.innerHTML = ""
  window.history.replaceState({}, "", "/u/tcs/network")
})

describe("hiding layers without moving nodes", () => {
  test("every layer is visible by default", () => {
    const { root } = build()

    expect([ ...root.querySelectorAll(".character-network-node") ].some(hidden)).toBe(false)
    expect([ ...root.querySelectorAll(".character-network-faction-link") ].some(hidden)).toBe(false)
    expect([ ...root.querySelectorAll(".character-network-relation-link") ].some(hidden)).toBe(false)
    expect(
      root.querySelector("[data-character-network-unconnected-legend]")
        .classList.contains("character-network-hidden")
    ).toBe(false)
  })

  test("turning unconnected off hides its nodes and the links that touch them", () => {
    const { controller, root } = build()

    controller.toggleUnconnected(change(false))

    expect(hidden(root.querySelectorAll(".character-network-node")[0])).toBe(true)
    expect(hidden(root.querySelectorAll(".character-network-node")[1])).toBe(false)
    expect(hidden(root.querySelectorAll(".character-network-faction-link")[0])).toBe(true)
    expect(hidden(root.querySelectorAll(".character-network-faction-link")[1])).toBe(false)
    expect(hidden(root.querySelectorAll(".character-network-relation-link")[0])).toBe(true)
    expect(hidden(root.querySelectorAll(".character-network-relation-link")[1])).toBe(false)
    expect(
      root.querySelector("[data-character-network-unconnected-legend]")
        .classList.contains("character-network-hidden")
    ).toBe(true)
    expect(controller.showUnconnectedValue).toBe(false)
  })

  test("turning relation links off hides only the relation lines", () => {
    const { controller, root } = build()

    controller.toggleRelationLinks(change(false))

    expect(
      [ ...root.querySelectorAll(".character-network-relation-link") ].every(hidden)
    ).toBe(true)
    expect(
      [ ...root.querySelectorAll(".character-network-faction-link") ].some(hidden)
    ).toBe(false)
    expect(
      [ ...root.querySelectorAll(".character-network-node") ].some(hidden)
    ).toBe(false)
    expect(
      root.querySelector("[data-character-network-relation-legend]")
        .classList.contains("character-network-hidden")
    ).toBe(true)
    expect(controller.showRelationLinksValue).toBe(false)
  })

  test("turning faction links off hides only the faction lines", () => {
    const { controller, root } = build()

    controller.toggleFactionLinks(change(false))

    expect(
      [ ...root.querySelectorAll(".character-network-faction-link") ].every(hidden)
    ).toBe(true)
    expect(
      [ ...root.querySelectorAll(".character-network-relation-link") ].some(hidden)
    ).toBe(false)
    expect(
      [ ...root.querySelectorAll(".character-network-node") ].some(hidden)
    ).toBe(false)
    expect(
      root.querySelector("[data-character-network-faction-legend]")
        .classList.contains("character-network-hidden")
    ).toBe(true)
    expect(controller.showFactionLinksValue).toBe(false)
  })

  test("the URL records the hidden layers and clears them again", () => {
    const { controller } = build()

    controller.toggleUnconnected(change(false))
    expect(window.location.search).toBe("?show_unconnected=0")

    controller.toggleRelationLinks(change(false))
    expect(window.location.search).toBe(
      "?show_unconnected=0&relation_links=0"
    )

    controller.toggleFactionLinks(change(false))
    expect(window.location.search).toBe(
      "?show_unconnected=0&relation_links=0&faction_links=0"
    )

    controller.toggleUnconnected(change(true))
    controller.toggleRelationLinks(change(true))
    controller.toggleFactionLinks(change(true))
    expect(window.location.search).toBe("")
  })
})
