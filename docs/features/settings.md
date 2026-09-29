# Platform settings

`GET /settings` shows the page and `PATCH /settings` stores a preference. It is the only page
outside `/u/:universe_slug` that is not authentication, so it skips `set_current_universe` and
`authorize_universe_access` and allows unauthenticated access.

**A display preference belongs to the browser, not to a universe.** That single decision is why this
page exists, why it is reachable by a guest, and why it is deliberately absent from the right utility
sidebar's **Configuration** section, which configures a universe. It lives in the top bar's
**Settings** entry, inside the account menu.

## The two independent preferences

**Theme** ([ADR 0013](../adr/0013-platform-settings-and-browser-theme.md)) and **language**
([ADR 0016](../adr/0016-internationalization-and-browser-locale.md)) are both per-browser cookies and
both are resolved by the layout, not by a controller callback:

- `AppTheme` reads the signed cookie `um_theme` and the layout renders it as `<html data-bs-theme>`,
  so the first paint is already correct and no script is involved. The `current_theme` helper
  memoizes it for the render. The appearance preference is deliberately **not** part of `Current`: a
  theme belongs to the browser, not to the session, universe, or story a request carries.
- `AppLocale` reads the signed cookie `um_locale`, and `ApplicationController#switch_locale` is an
  `around_action` that sets `I18n.locale` **before any action runs**, so a redirect's flash is
  already translated. The layout renders `<html lang="...">` from the same value, so the first paint
  is in the right language.

The two are validated independently before either is written, so a request that refuses one does not
apply the other. A change to either loads the whole document rather than navigating with Turbo,
because the theme lives in an attribute on the root element and a Turbo Drive navigation does not
update root attributes; the language needs the same opt-out for the same reason.

## The page

`app/views/settings/show.html.erb` posts a flat `theme` and/or `locale` parameter to `PATCH /settings`,
and the controller answers with a redirect (`see_other`) or a refusal. It carries `data: { turbo:
false }`.

It uses the plain full-page form shape with no record behind it, and its navigation is its own small
page shape:

- A **vertical** Bootstrap tab strip beside the panel: `nav nav-tabs flex-column`, a 12rem navigation
  column at `md` and above and stacked above the panel below it, so a narrow window never squeezes
  the panel. Each destination is a real request like every other tab strip, so the strip uses the
  active class plus `aria-current="page"` and **no** `data-bs-toggle`. `settings_tabs` in
  `ApplicationHelper` declares the sections and `shared/_settings_navigation` renders them; adding a
  section is one entry in `settings_tabs` plus its panel. The first section owns `/settings` and a
  later one gets a `?section=` query parameter, which `settings_language_section?` is the single
  predicate for.
- **Appearance** is the first tab. Its only control is **Theme**: a radio group of two labelled cards,
  **Light** and **Dark**, each with a swatch of that theme's page color, and a **Save theme** button.
  The card is the option's `<label>`, so the chosen state is a border and background change on the
  label, a filled radio for the non-color signal, and the checked attribute for assistive technology.
  The page says plainly that the choice is remembered in this browser and that no universe admin can
  change it for someone else, because that is the whole scope of the setting.
- **Language** holds the same kind of control for the locale, with the same labelled-card radio
  group. A language option is labelled in **its own** language, not in the current one, so a reader
  who cannot read the current language can still find theirs.

The page remembers where it was opened from and offers a **Go back** action that returns there. The
painted treatment is in [visual_design.md](../visual_design.md); the rules for writing a translatable
string are in [features/i18n.md](i18n.md).
