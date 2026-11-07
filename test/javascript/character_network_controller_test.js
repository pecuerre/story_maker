import { beforeEach, describe, expect, test } from "bun:test"
import CharacterNetworkController from "../../app/javascript/controllers/character_network_controller"

// The two view toggles on the Character network. The server renders the whole
// graph with fixed coordinates; this controller must only hide layers, never
// remove or move a node, and it must keep the URL and the no-JavaScript link
// hrefs pointing at the visible state.
function build({ showUnconnected = true, showFactionLinks = true } = {}) {
  const host = document.createElement("div")
  host.innerHTML = `
    <div data-controller="character-network">
      <a data-character-network-target="unconnectedButton" href="/u/tcs/network?show_unconnected=0" aria-pressed="true">
        <span data-character-network-target="unconnectedLabel"
          data-character-network-on-label="Hide characters with no connections"
          data-character-network-off-label="Show 1 character with no connection">Hide characters with no connections</span>
      </a>
      <a data-character-network-target="factionButton" class="btn btn-primary" href="/u/tcs/network?faction_links=0" aria-pressed="true">Show faction membership as relation</a>
      <a class="character-network-node" data-character-network-unconnected="true"></a>
      <a class="character-network-node"></a>
      <line class="character-network-faction-link" data-character-network-faction-link data-character-network-faction-unconnected="true"></line>
      <line class="character-network-faction-link" data-character-network-faction-link></line>
      <li data-character-network-unconnected-legend></li>
      <li data-character-network-faction-legend></li>
    </div>
  `
  document.body.append(host)

  const root = host.querySelector("[data-controller]")
  const controller = new CharacterNetworkController()
  controller.element = root
  controller.showUnconnectedValue = showUnconnected
  controller.showFactionLinksValue = showFactionLinks
  controller.hasUnconnectedButtonTarget = true
  controller.unconnectedButtonTarget = root.querySelector(
    "[data-character-network-target='unconnectedButton']"
  )
  controller.hasUnconnectedLabelTarget = true
  controller.unconnectedLabelTarget = root.querySelector(
    "[data-character-network-target='unconnectedLabel']"
  )
  controller.hasFactionButtonTarget = true
  controller.factionButtonTarget = root.querySelector(
    "[data-character-network-target='factionButton']"
  )
  controller.connect()

  return { controller, root }
}

const event = () => ({ preventDefault: () => {} })
const hidden = (element) =>
  element.classList.contains("character-network-hidden")

beforeEach(() => {
  document.body.innerHTML = ""
  window.history.replaceState({}, "", "/u/tcs/network")
})

describe("hiding layers without moving nodes", () => {
  test("both layers are visible by default", () => {
    const { root } = build()
    const nodes = root.querySelectorAll(".character-network-node")
    const links = root.querySelectorAll(".character-network-faction-link")

    expect([ ...nodes ].some(hidden)).toBe(false)
    expect([ ...links ].some(hidden)).toBe(false)
    expect(
      root.querySelector("[data-character-network-unconnected-legend]")
        .classList.contains("character-network-hidden")
    ).toBe(false)
  })

  test("turning unconnected off hides its nodes and the faction lines that touch them", () => {
    const { controller, root } = build()
    const nodes = root.querySelectorAll(".character-network-node")
    const links = root.querySelectorAll(".character-network-faction-link")

    controller.toggleUnconnected(event())

    expect(hidden(nodes[0])).toBe(true)
    expect(hidden(nodes[1])).toBe(false)
    expect(hidden(links[0])).toBe(true)
    expect(hidden(links[1])).toBe(false)
    expect(
      root.querySelector("[data-character-network-unconnected-legend]")
        .classList.contains("character-network-hidden")
    ).toBe(true)
    expect(controller.showUnconnectedValue).toBe(false)
  })

  test("turning faction links off hides only the faction lines", () => {
    const { controller, root } = build()

    controller.toggleFactionLinks(event())

    expect(
      [ ...root.querySelectorAll(".character-network-faction-link") ].every(hidden)
    ).toBe(true)
    expect(
      [ ...root.querySelectorAll(".character-network-node") ].some(hidden)
    ).toBe(false)
    expect(
      root.querySelector("[data-character-network-faction-legend]")
        .classList.contains("character-network-hidden")
    ).toBe(true)
    expect(controller.showFactionLinksValue).toBe(false)
  })

  test("the buttons update their labels, pressed state, and fallback hrefs", () => {
    const { controller, root } = build()
    const unconnected = root.querySelector(
      "[data-character-network-target='unconnectedButton']"
    )
    const label = root.querySelector(
      "[data-character-network-target='unconnectedLabel']"
    )
    const faction = root.querySelector(
      "[data-character-network-target='factionButton']"
    )

    controller.toggleUnconnected(event())

    expect(label.textContent).toBe("Show 1 character with no connection")
    expect(unconnected.getAttribute("aria-pressed")).toBe("false")
    expect(new URL(unconnected.href).search).toBe("")

    controller.toggleFactionLinks(event())

    expect(faction.getAttribute("aria-pressed")).toBe("false")
    expect(faction.classList.contains("btn-primary")).toBe(false)
    expect(faction.classList.contains("btn-outline-secondary")).toBe(true)
    expect(new URL(faction.href).search).toBe("?show_unconnected=0")
  })

  test("the URL records the hidden layers and clears them again", () => {
    const { controller } = build()

    controller.toggleUnconnected(event())
    expect(window.location.search).toBe("?show_unconnected=0")

    controller.toggleFactionLinks(event())
    expect(window.location.search).toBe(
      "?show_unconnected=0&faction_links=0"
    )

    controller.toggleUnconnected(event())
    controller.toggleFactionLinks(event())
    expect(window.location.search).toBe("")
  })
})
