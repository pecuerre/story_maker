import { describe, expect, test } from "bun:test"
import { readdirSync, readFileSync, statSync } from "node:fs"
import { join } from "node:path"

// The taxonomy and modal editors build their rows, options, labels, and error
// messages with DOM APIs so a user-controlled value is only ever text or an
// attribute (see `docs/resolved_quirks.md`, former quirk #8). Brakeman does not
// read client-side code, so this gate keeps the one remaining HTML-parsing sink
// a deliberate, reviewed decision instead of a habit.
const ALLOWED_HTML_SINKS = [
  // `timeline_controller.markerDefs()` is a developer's static SVG string with
  // no interpolation, assigned to `svg.innerHTML` on every redraw.
  { file: "timeline_controller.js", needle: "svg.innerHTML = this.markerDefs()" }
]

const SINKS = [ /\.\s*innerHTML\s*=/, /\.\s*outerHTML\s*=/, /insertAdjacentHTML\(/, /document\.write\(/ ]

function javascriptFiles(directory) {
  return readdirSync(directory).flatMap((entry) => {
    const path = join(directory, entry)
    return statSync(path).isDirectory() ? javascriptFiles(path) : (path.endsWith(".js") ? [ path ] : [])
  })
}

describe("client-side HTML sinks", () => {
  const files = javascriptFiles(join(import.meta.dir, "../../app/javascript"))

  test("the guard actually inspects the shipped controllers", () => {
    expect(files.length).toBeGreaterThan(3)
  })

  for (const file of files) {
    const relative = file.split("/app/javascript/").pop()

    test(`${relative} parses no user-controlled value as markup`, () => {
      const source = readFileSync(file, "utf8")
      const found = SINKS.flatMap((pattern) => source.match(new RegExp(pattern.source, "g")) || [])
      const allowed = ALLOWED_HTML_SINKS.filter((entry) => relative.split("/").pop() === entry.file)

      expect(found.length).toBeLessThanOrEqual(allowed.length)
      for (const entry of allowed) {
        expect(source).toContain(entry.needle)
      }
    })
  }
})
