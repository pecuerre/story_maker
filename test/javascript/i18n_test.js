import { afterAll, beforeEach, describe, expect, test } from "bun:test"
import { recordSubject, t, use } from "../../app/javascript/i18n"
import clientStrings from "./fixtures/client_strings.en.json"

// The client half of the server/client string contract.
//
// What is under test is the behaviour a controller inherits rather than writes:
// a missing key is visible instead of silently English, a plural is the locale's
// choice rather than a `count === 1`, a named interpolation is substituted and a
// positional one is not, and an unsupplied value leaves its placeholder visible
// rather than producing a sentence that reads as though it were complete.
const ENGLISH = {
  locale: "en",
  "shared.form.cancel": "Cancel",
  "shared.record_message": "%{label} %{message}",
  "searches.bar.type_more": {
    one: "Type %{count} more character to search.",
    other: "Type %{count} more characters to search."
  },
  record_subject: { scene_element: "the scene element" }
}

const SPANISH = {
  locale: "es",
  "shared.form.cancel": "Cancelar",
  "shared.record_message": "%{label} %{message}",
  "searches.bar.type_more": {
    one: "Escribe %{count} carácter más para buscar.",
    other: "Escribe %{count} caracteres más para buscar."
  },
  record_subject: { scene_element: "este elemento de la escena" }
}

beforeEach(() => {
  use(ENGLISH)
})

// Bun runs every file in this directory in one process, in the order the
// filesystem hands them over — which is alphabetical here and something else on
// another machine. `use` replaces one module-wide table rather than a per-test
// one, so a file that leaves its own four-key fixture behind hands every file
// that runs after it a table with nothing in it, and the controller tests then
// assert against the raw key: "shared.modal_form.unexplained" instead of the
// sentence a reader is shown. Putting the real blob back when this file is done
// is what makes those files' result independent of the order they ran in.
afterAll(() => {
  use(clientStrings)
})

describe("a plain string", () => {
  test("is the reader's own wording, not the controller's", () => {
    use(SPANISH)

    expect(t("shared.form.cancel")).toBe("Cancelar")
  })

  test("is read from the blob each time, so a language change needs no reload of the module", () => {
    expect(t("shared.form.cancel")).toBe("Cancel")

    use(SPANISH)

    expect(t("shared.form.cancel")).toBe("Cancelar")
  })
})

describe("a missing key", () => {
  test("renders as the key rather than as nothing", () => {
    // A reader who sees `searches.bar.no_matches` knows something is wrong, and
    // so does anyone reading a failing test. An empty string would look like a
    // page that simply has nothing to say.
    expect(t("searches.bar.no_matches")).toBe("searches.bar.no_matches")
  })

  test("is reported on the console rather than absorbed", () => {
    const warn = console.warn
    const seen = []
    console.warn = (message) => seen.push(message)
    try {
      t("searches.bar.no_matches")
    } finally {
      console.warn = warn
    }

    expect(seen).toEqual([ '[i18n] missing translation for "searches.bar.no_matches"' ])
  })
})

describe("a plural", () => {
  test("is chosen by the count, in the locale's own words", () => {
    expect(t("searches.bar.type_more", { count: 1 })).toBe("Type 1 more character to search.")
    expect(t("searches.bar.type_more", { count: 4 })).toBe("Type 4 more characters to search.")
  })

  test("follows the locale rather than the count alone", () => {
    use(SPANISH)

    // The same `count: 1` produces different words, which is the whole point of
    // the form travelling whole instead of being resolved on the server: a
    // server-resolved blob would have had to pick the form before the count was
    // known.
    expect(t("searches.bar.type_more", { count: 1 })).toBe("Escribe 1 carácter más para buscar.")
    expect(t("searches.bar.type_more", { count: 4 })).toBe("Escribe 4 caracteres más para buscar.")
  })

  test("treats zero as the plural form, because zero is not one", () => {
    expect(t("searches.bar.type_more", { count: 0 })).toBe("Type 0 more characters to search.")
  })

  test("falls back to the other form when no count is given", () => {
    // The only form every locale is required to define, so an entry read without
    // a count is still a sentence rather than an object printed as `[object Object]`.
    expect(t("searches.bar.type_more")).toBe("Type %{count} more characters to search.")
  })

  test("uses the locale the blob was resolved in, not the document's", () => {
    document.documentElement.lang = "es"
    use(ENGLISH)

    // A page whose blob and whose `lang` attribute disagreed would otherwise
    // pick a plural rule that does not match the words it is choosing between.
    expect(t("searches.bar.type_more", { count: 1 })).toBe("Type 1 more character to search.")
    document.documentElement.lang = "en"
  })
})

describe("interpolation", () => {
  test("substitutes a named argument", () => {
    expect(t("shared.record_message", { label: "Name", message: "can't be blank" })).toBe("Name can't be blank")
  })

  test("leaves a positional placeholder alone rather than binding the wrong argument", () => {
    use({ locale: "en", "shared.bad": "%1 must be blank" })

    expect(t("shared.bad")).toBe("%1 must be blank")
  })

  test("leaves an unsupplied value visible rather than dropping it", () => {
    // The alternative produces "Name must be blank"-shaped sentences that read
    // as though they were complete, which is worse than showing what went wrong.
    expect(t("shared.record_message", { label: "Name" })).toBe("Name %{message}")
  })

  test("renders a null value as absent, because null is not a word", () => {
    expect(t("shared.record_message", { label: "Name", message: null })).toBe("Name %{message}")
  })
})

describe("a record's own noun", () => {
  test("is the reader's words for the record type, not a humanized parameter", () => {
    // `scene_element` is a form field name; the reader is not shown it.
    use(SPANISH)

    expect(recordSubject("scene_element")).toBe("este elemento de la escena")
  })

  test("falls back to the parameter when the server has no word for it", () => {
    expect(recordSubject("brand_new_model")).toBe("brand_new_model")
  })
})
