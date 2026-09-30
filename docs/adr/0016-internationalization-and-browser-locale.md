# ADR 0016: Translate application chrome through I18n keys, and keep the language a browser-owned preference

- **Status:** Accepted
- **Date:** 2026-09-29
- **Related:** [`../architecture.md`](../architecture.md),
  [`../conventions.md`](../conventions.md),
  [`../visual_design.md`](../visual_design.md),
  [0013](0013-platform-settings-and-browser-theme.md),
  [0012](0012-client-side-verification-and-csrf.md)

## Context

Every user-facing string in the application was an English literal: in the ERB
views, in `ApplicationHelper` and the shared partials, in the controller flash and
redirect messages, in `AppTheme`'s theme names, and in the password-reset mailer.
`config/locales/en.yml` held six `section_*` keys that nothing read. There was no
second locale and no way for a reader to ask for one.

Adding a language raises three questions the repository could not answer, and each
of them decides how the other slices of the internationalization work are written.

1. **Where does the choice to translate live?** Every other string in the
   application belongs somewhere. The language belongs to nobody in particular:
   it is not universe data, not story data, and not an account attribute anyone
   has asked for.
2. **Which strings are chrome and which are the author's data?** The application
   stores character names, descriptions, tag names, and universe and story names.
   Translating any of those would corrupt an author's work, and a translator would
   be rewriting, not translating.
3. **What happens when a key is missing?** A page that silently falls back to
   English in a Spanish locale looks finished and is not, and nothing in the
   existing suite would have noticed.

The work is delivered in stages. Every server-rendered view, helper, model-level label, and flash in
the application is now behind a key, and so is every string a Stimulus controller prints: the
client-side half resolves its words in the same place and ships them to the browser, because a
controller has no I18n backend of its own. This ADR records the decisions the delivered stages settled
— the key layout, the browser-owned language cookie, why author data is excluded, and why the browser
reads rather than resolves — because every later stage repeats them.

## Decision

- **The language is a signed cookie, exactly like the theme.** `AppLocale`
  (`app/models/app_locale.rb`) is the whole of the feature: two known names
  (`en`, `es`), `en` as the default, one cookie, and the same
  `normalize`-on-read contract `AppTheme` uses, so a forged, stale, or
  hand-edited cookie can only ever select a known locale. It is not a `User`
  column and not a universe setting, for the reasons
  [ADR 0013](0013-platform-settings-and-browser-theme.md) gives for the theme —
  a reader's language has to work before a universe is chosen, and no universe
  admin may impose one on a collaborator.
- **The server renders the choice.** `ApplicationController#switch_locale` is an
  `around_action` that reads the cookie and sets `I18n.locale` for the request,
  before any action runs, so a redirect's flash is already translated. It is an
  `around_action` rather than a `before_action` because `I18n.locale` is thread
  state: `I18n.with_locale` restores the previous value, so one request cannot
  leak its language into the next one on the same thread. The layout renders
  `<html lang="...">` from the same value, so the first paint is in the right
  language for a screen reader and for the browser's own hyphenation.
- **Language is a second section of the existing settings page, not a second
  route.** `/settings?section=language` is the tab strip ADR 0013 already
  describes: the first tab owns the page's own URL and a later tab gets a query
  parameter. One settings page, one address per section, no duplicate route.
- **Only chrome is translated. Author data never is.** A record's name,
  description, tag name, universe name, and story name are data. A translation
  layer that rewrote them would be editing the author's work, so they are not keys
  and must not become keys.
- **Keys are grouped by the surface that owns the string** — `layouts.*`,
  `sidebar.*`, `shared.*`, `settings.*`, `sessions.*`, `passwords.*` — rather than
  held in one flat list, so a page and its translations live together and a
  surface can move without renumbering everything else. `config/locales/en.yml`
  is the source of truth and `config/locales/es.yml` mirrors it.
- **A missing key is a failure, not a fallback.**
  `config.i18n.raise_on_missing_translations = true` in the test environment
  makes a new key fail the suite until it is added to *both* files, and
  `test/models/translations_test.rb` compares the two key sets, their
  interpolation placeholders, and their plural forms directly. This is why the
  application ships a Spanish subset of Rails' own strings: Rails defines
  `errors.messages.*`, `errors.format`, `datetime.distance_in_words.*`, and
  `support.array.*` in English only, so a Spanish page rendering a validation
  message or a duration would otherwise raise. The subset is checked against the
  real Rails key set, so it cannot rot into translating a key the framework never
  asks for. The same rule governs a key a **controller** reads:
  `ClientStringsTest` asserts both that every `t()` call in `app/javascript`
  names a key the server sends and that every key the server sends is one a
  controller reads, and `no_client_string_literals_test.js` fails when a
  controller holds English of its own.
- **Record-type nouns live at the root of the locale files.** Every workspace
  already passes a bare word as a count label (`count_label: "character"`,
  `details_count_label: "scene"`), and the shared count helpers now resolve that
  word as a key with a `count:` so the plural comes from the locale. Nesting them
  would have meant renaming fifty-odd call sites for no gain.
- **A value that travels in a URL is not translated.** `SceneFilter::UNGROUPED`
  is the string `"ungrouped"` because it is a query value, and a search scope's
  `value` is a query value. Only the *label* beside them is translated. This is
  the one place where a mechanical conversion would quietly break links, and it
  recurs on the client too: a `data-modal-form-direction` attribute carries
  `"up"`/`"down"`, so the two sentences that mention moving are two keys rather
  than one frame with a spliced word.
- **The browser reads; the server resolves.** A client-side string is a `t()`
  call against a JSON blob the layout renders, not a translation the browser
  performs. `ClientStrings` owns the list of keys a controller may read and
  `app/javascript/i18n.js` is the only lookup, so the same missing-key and
  one-sided-key rules that govern a view govern a controller. A controller never
  assembles a key from a value, which is what keeps a value that travels in a
  URL from ever becoming a lookup.

## Consequences

### Benefits

- A guest can choose a language, and the choice follows them to every page
  including the landing page, exactly as the theme does.
- A page in a locale with a hole in it fails in the suite rather than shipping
  mixed-language chrome to a reader.
- Adding a third language is a new `es.yml`-shaped file plus one entry in
  `AppLocale` and `config.i18n.available_locales`; the "one locale file per
  offered locale" test says so out loud.

### Costs and constraints

- A language does **not** follow an account to another browser or device. That is
  the same deliberate trade ADR 0013 makes for the theme, and it is the opposite
  decision a per-user preference would need.
- A **queued** password reset is written in the default locale, because
  `deliver_later` renders the message on a thread that has no `I18n.locale`. The
  locale is passed explicitly so a caller that knows the reader's language — an
  inline delivery, or a future per-account preference — can supply it, and
  `test/mailers/passwords_mailer_test.rb` states the current limit rather than
  pretending it does not exist. Following an account is what would fix it.
- The Spanish translations of Rails' own strings are maintained by hand and are
  limited to the keys the application reaches. The proper answer for a fuller set
  is the `rails-i18n` gem; it is not added here because that is a dependency
  change, and the hand-maintained block is what the application needs today.
- Spanish is a gendered and plural-ruled language, and the English keys were
  written as short labels. A translation that reads correctly in isolation can
  still be awkward once a sentence wraps it. The browser suite is where that
  shows up.
- The client-side half works the way the rest of the decision describes, and it
  costs one extra file. The browser has no I18n backend, so a controller's
  strings are resolved by the server and shipped as one JSON blob the layout
  renders on every page; `app/javascript/i18n.js` is the only lookup.
  `ClientStringsTest` and `no_client_string_literals_test.js` enforce the
  boundary from both sides, so a controller that hardcodes English or reads a
  key the server does not send fails the suite. A **pluralized** key travels as
  its whole `{one:, other:}` hash and the client picks the form with
  `Intl.PluralRules`, because the blob is rendered once per page while the
  count is only known when a controller asks. That is a genuinely new rule —
  the words are still the locale file's, but the choice among them is the
  browser's — and a third language with a richer plural rule needs no change
  here. See [features/i18n.md](../features/i18n.md#a-string-the-browser-has-to-have).
- The blob is sent on every page rather than per controller, because which
  controllers a page carries is not something the layout can know: the taxonomy
  tree builds a photo editor inside a modal it creates after load. That is a few
  hundred words of chrome on a page that may use none of it.

## Alternatives considered

### A `users.locale` column

Rejected for now, for the reasons [ADR 0013](0013-platform-settings-and-browser-theme.md) gives for
`users.theme`; that ADR records them, so they are not repeated here. What the locale adds to the
answer is one more reason it becomes right later: it is what would let a queued password reset be
written in the reader's own language. If the column is ever added, the cookie would take precedence
for a signed-out reader and the column would be the fallback.

### Detecting the browser's `Accept-Language` header

Rejected for now. It would make the very first visit to the application render in
a language nobody chose, with no control on the page having been used, and it
would make a shared machine's language depend on who used it last. An explicit
choice on the settings page is honest about the fact that the setting is the
reader's.

### A URL prefix such as `/es/u/...`

Rejected. It would make every link, every redirect, and every `redirect_back`
locale-aware, and it would give one preference two addresses. A cookie keeps the
locale a property of the browser, which is what it is.

### Falling back to English for a missing key

Rejected. It is the failure this ADR exists to prevent: a page that looks
translated, is not, and is not caught by a suite running in the default locale.
`config.i18n.fallbacks` stays as production already had it, so a production page
degrades to English rather than erroring; the test environment is where a hole is
caught.

### One `strings.yml` for the whole application

Rejected. A single flat list makes it impossible to see which surface owns a
string, and a later change to one page diffs against the whole application.

## Related documentation

- [`../architecture.md`](../architecture.md)
- [`../conventions.md`](../conventions.md)
- [`../visual_design.md`](../visual_design.md)
- [`../development.md`](../development.md)
- [0013](0013-platform-settings-and-browser-theme.md)
- [0012](0012-client-side-verification-and-csrf.md)
