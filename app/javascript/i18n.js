// The one lookup every Stimulus controller uses for a user-facing string.
//
// A controller does not call `I18n.t` — the browser has no I18n backend, and
// ADR 0016 settled the boundary as "the server resolves it, the browser prints
// it". The layout renders the resolved strings as one JSON blob
// (`ClientStrings#payload`), and this module is the client half of that
// contract: it reads the blob, interpolates, and picks a plural form, so no
// controller invents its own mechanism and none of them can drift apart.
//
// Four rules a controller inherits from using this, and cannot get wrong
// locally:
//
//   1. A missing key is a **failure**, not a fallback. Nothing here renders
//      English, because an English word on a Spanish page looks finished and is
//      not. The key is returned so the failure is visible on the page and in the
//      console rather than silently absorbed, and `ClientStringsTest` is what
//      makes the case unreachable for a key a controller actually reads.
//   2. A plural is chosen by the **locale**, from a `count`. The blob carries
//      every plural form the locale defines, and the form is selected with
//      `Intl.PluralRules` — the platform's own rule table for the locale, which
//      is the same data a locale file's `one:`/`few:`/`other:` keys encode. So a
//      controller cannot express `count === 1 ? …`, and adding a language with a
//      richer plural rule needs no change here at all.
//   3. A key is a **dotted path the caller gives whole**. The client never
//      assembles a key from a value, so a value that travels in a URL or a
//      record's own data can never become a lookup that raises.
//   4. Interpolation is **named**, never positional, and a value that is not
//      supplied leaves its placeholder visible rather than being dropped.
//
// `recordSubject` is the one entry that is not chrome: it is the reader's own
// noun for a record type, which the client cannot derive from the `model_param`
// it holds. It is a plain lookup, not a sentence, and it is resolved server-side
// for the same reason.

const BLOB_ID = "client-strings"

let table = null

// The blob is read once per page, and lazily rather than at module load: this
// module is imported by a controller, and a controller is imported by a unit
// test that never renders a layout.
export function load() {
  if (table) return table

  const blob = document.getElementById(BLOB_ID)
  table = blob ? JSON.parse(blob.textContent) : {}
  return table
}

// The locale the blob was resolved in, for `Intl.PluralRules`. It travels with
// the strings rather than being read from `<html lang>`, because the blob is
// what was actually resolved: reading the document's language would let a page
// whose strings and whose `lang` attribute disagree pick a plural rule that does
// not match the words it is choosing between.
function locale() {
  return load().locale || document.documentElement?.lang || "en"
}

// Replace the table for a unit test that builds a controller without a layout.
//
// A language change in the application never needs this: `AppLocale` is a
// cookie, so choosing a language is a full page load, and the blob is rendered
// again in the new language with it.
export function use(strings) {
  table = strings || {}
  return table
}

// A translated string, or the key itself when the key is not there.
//
// Returning the key rather than an empty string is deliberate: a reader who
// sees `searches.bar.no_matches` knows something is wrong, and so does anyone
// reading a failing test. An empty string would look like a page that simply has
// nothing to say.
export function t(key, values = {}) {
  const strings = load()
  const entry = strings[key]

  if (entry === undefined) {
    console.warn(`[i18n] missing translation for "${key}"`)
    return key
  }

  return interpolate(resolve(entry, values.count), values)
}

// The reader's own name for a record type, from the `model_param` a controller
// already holds. Used by the two editors that report a record-level (`base`)
// error as a sentence about the record.
export function recordSubject(modelParam) {
  const subjects = load().record_subject || {}
  return subjects[modelParam] || modelParam
}

// The one form of an entry, chosen by the locale's own rule.
//
// A plain string is already resolved. A pluralized entry arrives whole — every
// form the locale defines — because the blob is rendered once per page while
// the count is only known when a controller asks, so the choice has to happen
// here. A category the locale does not define falls back to `other`, which is
// what I18n does for a language whose rule names a form its file omits, and is
// the only form every locale is required to have.
function resolve(entry, count) {
  if (typeof entry !== "object" || entry === null) return entry
  if (count === undefined || count === null) return entry.other

  const category = new Intl.PluralRules(locale()).select(count)
  return entry[category] ?? entry.other
}

// `%{name}` is substituted and `%1`/`%2` is not, so a key that reached the
// client with a positional placeholder renders it literally rather than
// silently binding the wrong argument.
//
// A missing value leaves the placeholder visible. Dropping it produces a
// sentence that reads as though it were complete, which is the one outcome worse
// than showing the reader what went wrong.
function interpolate(template, values) {
  if (typeof template !== "string") return template

  return template.replace(/%\{(\w+)\}/g, (match, name) =>
    values[name] === undefined || values[name] === null ? match : String(values[name])
  )
}
