# Platform settings

`GET /settings` shows the page and `PATCH /settings` stores a preference. It is the only page
outside `/u/:universe_slug` that is not authentication, so it skips `set_current_universe` and
`authorize_universe_access` and allows unauthenticated access.

**A platform preference belongs to the browser, not to a universe.** That single decision is why this
page exists, why it is reachable by a guest, and why it is deliberately absent from the right utility
sidebar's **Configuration** section, which configures a universe. It lives in the top bar's
**Settings** entry, inside the account menu.

## The three independent preferences

**Theme** ([ADR 0013](../adr/0013-platform-settings-and-browser-theme.md)), **language**
([ADR 0016](../adr/0016-internationalization-and-browser-locale.md)), and **start page**
([ADR 0017](../adr/0017-browser-owned-start-page-and-remembered-destination.md)) are all per-browser
signed cookies, and each is resolved in a different place because each answers a different question.

- `AppTheme` reads the signed cookie `um_theme` and the layout renders it as `<html data-bs-theme>`,
  so the first paint is already correct and no script is involved. The `current_theme` helper
  memoizes it for the render. The appearance preference is deliberately **not** part of `Current`: a
  theme belongs to the browser, not to the session, universe, or story a request carries.
- `AppLocale` reads the signed cookie `um_locale`, and `ApplicationController#switch_locale` is an
  `around_action` that sets `I18n.locale` **before any action runs**, so a redirect's flash is
  already translated. The layout renders `<html lang="...">` from the same value, so the first paint
  is in the right language.
- `AppStartPage` reads the signed cookie `um_start_page` and answers one question: where a sign-in
  with nothing to return to should land. It is **not** display state, which is why it is its own
  section rather than part of Appearance. The value is one of `remember` (the default) and
  `universes`; the remembered destination it governs is separate state, described in
  [architecture.md](../architecture.md).

All three are validated independently before any is written, so a request that refuses one does not
apply the others. All three forms opt out of Turbo. For the theme and the language that is a
necessity — the theme lives in an attribute on the root element, and `I18n.locale` is read at render,
so a Turbo Drive navigation would update the body while leaving the root element stale. The start
page form opts out for **consistency** rather than necessity: nothing it sets lives on the root
element, but every section of the page then saves the same way, and the section navigation's active
state and the flash are both rendered by one response rather than re-derived from the one before it.

## The page

`app/views/settings/show.html.erb` posts a flat `theme`, `locale`, and/or `start_page` parameter to
`PATCH /settings`, and the controller answers with a redirect (`see_other`) or a refusal. The
controller declares the three as one `PREFERENCES` map from request parameter to the model that owns
the cookie, so the "is this value known" and "write this preference" pairs cannot drift apart between
sections.

It uses the plain full-page form shape with no record behind it, and its navigation is its own small
page shape:

- A **vertical** Bootstrap tab strip beside the panel: `nav nav-tabs flex-column`, a 12rem navigation
  column at `md` and above and stacked above the panel below it, so a narrow window never squeezes
  the panel. Each destination is a real request like every other tab strip, so the strip uses the
  active class plus `aria-current="page"` and **no** `data-bs-toggle`. `settings_tabs` in
  `ApplicationHelper` declares the sections and `shared/_settings_navigation` renders them; adding a
  section is one entry in `settings_tabs`, one value in `SETTINGS_SECTIONS`, and one panel. The first
  section owns `/settings` and a later one gets a `?section=` query parameter, which
  `current_settings_section` is the single answer for. An absent or unrecognised `?section=` is the
  first section, so a stale or mistyped query parameter cannot produce a blank page.
- **Appearance** is the first tab. Its only control is **Theme**: a radio group of two labelled cards,
  **Light** and **Dark**, each with a swatch of that theme's page color, and a **Save theme** button.
  The card is the option's `<label>`, so the chosen state is a border and background change on the
  label, a filled radio for the non-color signal, and the checked attribute for assistive technology.
  The page says plainly that the choice is remembered in this browser and that no universe admin can
  change it for someone else, because that is the whole scope of the setting.
- **Language** holds the same kind of control for the locale, with the same labelled-card radio
  group. A language option is labelled in **its own** language, not in the current one, so a reader
  who cannot read the current language can still find theirs.
- **Start page** holds the same control for where a sign-in lands: **My last story** or **The
  universes list**. Its cards carry an icon rather than a colour swatch, because a destination has no
  palette to preview. Choosing the universes list also forgets the stored destination, so the two
  cannot be left disagreeing; choosing the last story keeps it. The page says plainly that returning
  to a story only ever happens for a story the reader picked themselves.

The page remembers where it was opened from and offers a **Go back** action that returns there. The
painted treatment is in [visual_design.md](../visual_design.md); the rules for writing a translatable
string are in [features/i18n.md](i18n.md).