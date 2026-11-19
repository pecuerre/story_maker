import { beforeEach, describe, expect, test } from "bun:test"
import ToolsRailController from "../../app/javascript/controllers/tools_rail_controller"

// The rail preference is a class on the workspace shell plus a cookie. The
// server renders the class on the first request; these cases cover what the
// controller does after that: flip the class, keep the button's name and
// state honest, give the hidden labels a tooltip, and write the cookie.
function build({ collapsed = false } = {}) {
  const host = document.createElement("div")
  host.innerHTML = `
    <div class="workspace-shell${collapsed ? " tools-rail-collapsed" : ""}">
      <aside data-controller="tools-rail"
        data-tools-rail-cookie="um_tools_rail"
        data-tools-rail-collapsed="collapsed"
        data-tools-rail-expanded="expanded">
        <button type="button"
          data-action="tools-rail#toggle"
          data-tools-rail-toggle
          data-collapse-label="Collapse tools"
          data-expand-label="Expand tools"
          aria-expanded="${collapsed ? "false" : "true"}">
          <span data-tools-rail-label>${collapsed ? "Expand tools" : "Collapse tools"}</span>
        </button>
        <a class="sidebar-link" href="#"><span class="sidebar-link-label">Tags</span></a>
        <a class="sidebar-link" href="#"><span class="sidebar-link-label">Members</span></a>
      </aside>
    </div>
  `
  document.body.append(host)

  const shell = host.querySelector(".workspace-shell")
  const aside = host.querySelector("aside")
  const button = host.querySelector("[data-tools-rail-toggle]")
  const controller = new ToolsRailController()
  controller.element = aside
  controller.connect()
  return { controller, shell, button, links: [...host.querySelectorAll(".sidebar-link")] }
}

beforeEach(() => {
  document.body.innerHTML = ""
  // biome-ignore lint/suspicious/noDocumentCookie: the controller's unit test has to clear the preference it writes.
  document.cookie = "um_tools_rail=; path=/; max-age=0"
})

describe("tools rail state", () => {
  test("a server-rendered expanded rail starts expanded", () => {
    const { shell, button } = build()

    expect(shell.classList.contains("tools-rail-collapsed")).toBe(false)
    expect(button.getAttribute("aria-expanded")).toBe("true")
    expect(button.querySelector("[data-tools-rail-label]").textContent).toBe("Collapse tools")
  })

  test("a server-rendered collapsed rail starts collapsed", () => {
    const { shell, button, links } = build({ collapsed: true })

    expect(shell.classList.contains("tools-rail-collapsed")).toBe(true)
    expect(button.getAttribute("aria-expanded")).toBe("false")
    expect(button.querySelector("[data-tools-rail-label]").textContent).toBe("Expand tools")
    expect(links[0].title).toBe("Tags")
  })

  test("a page restored from cache follows the stored preference", () => {
    // biome-ignore lint/suspicious/noDocumentCookie: the test has to seed the preference the controller reads.
    document.cookie = "um_tools_rail=collapsed; path=/"
    const { shell, button } = build()

    expect(shell.classList.contains("tools-rail-collapsed")).toBe(true)
    expect(button.getAttribute("aria-expanded")).toBe("false")
  })
})

describe("tools rail toggle", () => {
  test("collapsing narrows the shell, renames the control, and titles the links", () => {
    const { controller, shell, button, links } = build()

    controller.toggle()

    expect(shell.classList.contains("tools-rail-collapsed")).toBe(true)
    expect(button.getAttribute("aria-expanded")).toBe("false")
    expect(button.querySelector("[data-tools-rail-label]").textContent).toBe("Expand tools")
    expect(links.map((link) => link.title)).toEqual([ "Tags", "Members" ])
  })

  test("expanding restores the width, the name, and removes the tooltips", () => {
    const { controller, shell, button, links } = build()

    controller.toggle()
    controller.toggle()

    expect(shell.classList.contains("tools-rail-collapsed")).toBe(false)
    expect(button.getAttribute("aria-expanded")).toBe("true")
    expect(button.querySelector("[data-tools-rail-label]").textContent).toBe("Collapse tools")
    expect(links.map((link) => link.hasAttribute("title"))).toEqual([ false, false ])
  })
})

describe("tools rail preference", () => {
  test("collapsing writes the browser preference", () => {
    const { controller } = build()

    controller.toggle()

    expect(document.cookie).toContain("um_tools_rail=collapsed")
  })

  test("expanding writes the expanded preference", () => {
    const { controller } = build()

    controller.toggle()
    controller.toggle()

    expect(document.cookie).toContain("um_tools_rail=expanded")
  })
})
