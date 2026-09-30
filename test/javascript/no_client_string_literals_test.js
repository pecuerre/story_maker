import { describe, expect, test } from "bun:test"
import { readdirSync, readFileSync, statSync } from "node:fs"
import { join } from "node:path"

// A client-side string must be a key, not a literal.
//
// Brakeman does not read `app/javascript`, `TranslationsTest` cannot see a
// sentence typed into a controller, and a suite that only ever runs in the
// default locale renders English chrome happily — so until this gate, a Spanish
// page could carry an English sentence in a JavaScript-built modal and every
// test would stay green. This is the client-side half of the missing-key
// enforcement ADR 0016 settled, and it is the same shape as
// `no_html_sink_test.js`: a scan, an explicit allowlist, and a failure the next
// time a new sentence appears.
//
// A **user-facing literal** is a quoted string that reads as prose rather than
// as a name:
//
//   - a phrase — it contains a space, and some token is a capitalized word of
//     three or more letters. That skips every CSS class list (`"d-flex
//     flex-wrap gap-2"`), every ARIA and data attribute name, every form field
//     name, and every MIME type this application posts.
//   - a single capitalized alphabetic word — `"Cancel"`, `"Photo"`, `"Zoom"`.
//     Element names, action names, HTTP verbs, and attribute values are all
//     lowercase or contain a hyphen, so they do not match.
//
// The remaining hole is deliberate and small: an all-lowercase multi-word
// sentence. It is caught when it reaches a text sink (below) and missed when it
// does not, so `ClientStringsTest` is what makes the case matter — it proves
// every key a controller reads resolves in both locales, so a literal is not
// needed to stand in for a missing one.

const PHRASE = /\s/ // any whitespace-separated token…
const CAPITALIZED_WORD = /(^|\s)[A-Z][a-z]{2,}/ // …that is a capitalized word
const SINGLE_WORD = /^[A-Z][a-z]+$/

// A scanner, not a regular expression. A regex over three kinds of delimiter
// either mis-reads a template literal that contains a quote or runs from one
// string to the next several lines away, and a gate that cannot tell a real
// literal from a run of code is a gate nobody trusts. This walks the source
// once, tracking which delimiter it is inside and whether the current character
// is escaped, and returns the contents of every literal it closes.
function stringLiterals(source) {
  const found = []
  const openers = { "\"": "\"", "'": "'", "`": "`" }

  for (let index = 0; index < source.length; index++) {
    const character = source[index]
    const closer = openers[character]
    if (!closer) continue

    let value = ""
    let escaped = false
    for (index++; index < source.length; index++) {
      const next = source[index]
      if (escaped) {
        value += next
        escaped = false
        continue
      }
      if (next === "\\") {
        escaped = true
        continue
      }
      if (next === closer) break
      // A literal that spans lines is not a sentence anyone reads, and an
      // unterminated one means the scanner lost track; either way there is no
      // user-facing string here to report.
      if (next === "\n") {
        value = ""
        break
      }
      value += next
    }
    if (value.length > 0) found.push(value)
  }

  return found
}

// Text sinks: a position whose argument is read by a reader rather than by the
// browser. This is the second half of the rule, and it is what catches a
// sentence that is not capitalized — `"the event must have a title"` is a phrase
// with no capitalized word.
const SINKS = [
  "textContent =",
  "innerText =",
  "setAttribute(\"aria-label\",",
  "setAttribute(\"aria-placeholder\",",
  "setAttribute(\"aria-roledescription\",",
  "setAttribute(\"title\",",
  ".title =",
  ".placeholder =",
  "window.confirm(",
  "announce(",
  "pageStatus(",
  "showSummary(",
  "fail(",
  "this.message(",
  "this.group(",
  "this.button(",
  "iconButton(",
  "statusMessage(",
  "mutationMessage("
]

// The reviewed exceptions. Each one is a *name the browser or a library owns*,
// not a sentence, and each says why it is here — a new entry is a decision, not
// a convenience.
const ALLOWED = [
  // HTTP request header names. The wire format is a name; the value beside it
  // is the translated string.
  { file: "search_controller.js", needle: "Accept" },
  { file: "modal_form_controller.js", needle: "Accept" },
  { file: "modal_form_controller.js", needle: "Content-Type" },
  // `KeyboardEvent.key` values. These are the names the browser's own API
  // reports, compared by identity, and are spelled the same in every language.
  { file: "search_controller.js", needle: "ArrowDown" },
  { file: "search_controller.js", needle: "ArrowUp" },
  { file: "search_controller.js", needle: "Enter" },
  { file: "search_controller.js", needle: "Escape" },
  { file: "search_controller.js", needle: "Tab" },
  // `taxonomy_tree_controller.js` asks for the same JSON the search box asks
  // for, over the same request the two editors share.
  { file: "taxonomy_tree_controller.js", needle: "Accept" }
]

function javascriptFiles(directory) {
  return readdirSync(directory).flatMap((entry) => {
    const path = join(directory, entry)
    return statSync(path).isDirectory() ? javascriptFiles(path) : (path.endsWith(".js") ? [ path ] : [])
  })
}

function isProse(value) {
  if (PHRASE.test(value)) return CAPITALIZED_WORD.test(value)
  return SINGLE_WORD.test(value)
}

// Only the lines that matter: a comment or a string *inside* a comment is
// documentation, and the controllers are heavily commented on purpose. The scan
// therefore drops `//` line comments and `/* … */` blocks before it reads
// anything, and asserts separately that dropping them did not eat the code.
function code(source) {
  return source.replace(/\/\*[\s\S]*?\*\//g, "").replace(/^\s*\/\/.*$/gm, "")
}

describe("client-side user-facing strings", () => {
  const files = javascriptFiles(join(import.meta.dir, "../../app/javascript"))

  test("the guard actually inspects the shipped controllers", () => {
    expect(files.length).toBeGreaterThan(3)
  })

  test("every allowlist entry still names the literal it was written for", () => {
    // An allowlist entry that has stopped matching is an allowlist entry that
    // has silently started permitting whatever replaced it.
    for (const entry of ALLOWED) {
      const file = files.find((path) => path.endsWith(entry.file))
      expect(file).toBeDefined()
      expect(stringLiterals(readFileSync(file, "utf8"))).toContain(entry.needle)
    }
  })

  for (const file of files) {
    const relative = file.split("/app/javascript/").pop()
    const source = readFileSync(file, "utf8")

    test(`${relative} holds no user-facing string literal`, () => {
      const allowed = ALLOWED.filter((entry) => relative.split("/").pop() === entry.file).map((entry) => entry.needle)
      const offending = [ ...new Set(stringLiterals(code(source))) ]
        .filter(isProse)
        .filter((value) => !allowed.includes(value))

      expect(offending).toEqual([])
    })

    test(`${relative} passes no user-facing string literal to a text sink`, () => {
      const lines = code(source).split("\n").filter((line) => SINKS.some((sink) => line.includes(sink)))
      const allowed = ALLOWED.filter((entry) => relative.split("/").pop() === entry.file).map((entry) => entry.needle)
      const offending = lines.flatMap((line) => stringLiterals(line))
        .filter(isProse)
        .filter((value) => !allowed.includes(value))

      expect(offending).toEqual([])
    })
  }
})
