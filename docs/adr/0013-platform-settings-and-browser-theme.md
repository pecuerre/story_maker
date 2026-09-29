# ADR 0013: Keep platform settings browser-owned, server-rendered, and out of the universe workspace

- **Status:** Accepted
- **Date:** 2026-09-27
- **Related:** [`../architecture.md`](../architecture.md),
  [`../universe_maker_conventions.md`](../universe_maker_conventions.md),
  [`../visual_design.md`](../visual_design.md),
  [0001](0001-universe-and-story-scope.md),
  [0005](0005-universe-access-levels.md)

## Context

The request was a settings page under Configuration with vertical tabs, starting with one
**Appearance** tab holding a light/dark **Theme** choice. Two things about that request do not fit
the shape of everything else in the application:

- [ADR 0001](0001-universe-and-story-scope.md) makes the universe the unit of ownership: characters,
  locations, events, items, relations, memberships, taxonomies, and stories all belong to a universe
  and are shared by its stories. The right utility sidebar's **Configuration** section is the
  configuration of *that universe*: Tags and the admin-only Members manager.
- [ADR 0005](0005-universe-access-levels.md) gives universes read/write/admin levels. A display
  preference is none of those things: it is a property of the browser, it must work before a universe
  is chosen (the landing page) and for a guest reading a public universe, and no universe admin may
  impose one on a collaborator.

Two smaller questions were open as well. Where the theme is stored decides whether a guest can use
it at all and whether the page needs a schema change. And the theme has to be in effect on the *first*
paint: Bootstrap 5.3 implements dark mode through a `data-bs-theme` attribute, so anything that
applies the theme after load produces a visible flash of the wrong palette.

## Decision

- **Settings is a platform-level surface at `/settings`** (`resource :settings, only: %i[show
  update]`). It skips `set_current_universe` and `authorize_universe_access`, allows
  unauthenticated access, and renders without the workspace shell. It is reached from **one** place:
  a **Settings** entry in the top bar next to the account menu, rendered for every visitor. It is
  deliberately *not* a Configuration entry in the right utility sidebar, which stays about universe
  configuration.
- **The theme is a signed cookie, not a record.** `AppTheme` is the whole of the feature: two known
  names (`light`, `dark`), `light` as the default, and one cookie. It is not a `User` column and not
  a universe setting. A read that does not match a known name is the default, never an error, because
  appearance never blocks a page and an unverifiable or hand-edited cookie must not be able to put
  anything but a known theme into the document.
- **The server renders the choice.** The application layout writes
  `<html lang="en" data-bs-theme="<%= current_theme %>">`, and Bootstrap's own dark variables do the
  rest. There is no client-side theme script, no `localStorage`, and no flash of the wrong palette.
- **Custom design tokens are themed too.** The `--um-*` tokens in
  `app/assets/stylesheets/_application_custom.scss` are ours, not Bootstrap's, so a
  `[data-bs-theme="dark"]` block re-tints every one that carried a light-only value. A literal
  near-white surface is not acceptable in the dark theme, so those surfaces became tokens
  (`--um-surface-raised`, `--um-row-hover`, `--um-surface-veil`, `--um-tag-badge-border`). Each scope
  hue (universe, story, tools) keeps its hue and only changes value and background, so a block still
  reads as the same scope in both themes.
- **The settings form is a plain full-page form that opts out of Turbo.** It `PATCH`es a flat `theme`
  parameter and answers with a redirect (`see_other`), like the other non-model forms. It carries
  `data: { turbo: false }` because Turbo Drive replaces the body and head but does **not** update
  attributes on the root element: a Turbo submission would store the new theme and keep painting the
  old one. A real page load is also the one navigation that guarantees the first paint is correct.
- **Tabs are declarative and URL-backed.** `settings_tabs` lists them and
  `shared/_settings_navigation` renders them as a vertical Bootstrap tab strip with the active class
  and `aria-current="page"` — no `data-bs-toggle="tab"`, no in-document panes, exactly like
  `shared/_content_tabs` and `shared/_tag_workspace_navigation`. The first tab owns the page's own
  URL (`/settings`) rather than a query parameter, so one tab does not have two addresses. A later tab
  that needs its own state gets a query parameter in the shape of the taxonomy workspace
  (`?scope=…&taxonomy=…`).

## Consequences

### Benefits

- A guest can choose a theme, and the choice follows them to every page including the landing page.
- No migration, no model, and nothing to authorize: adding a preference of the same kind is a new
  entry in `AppTheme` and a new control on its tab.
- The first paint is always in the chosen palette, with no script, no inline style, and no flash.
- A forged cookie cannot inject anything: the value is checked against the known names on every read
  and every write.

### Costs and constraints

- A theme does **not** follow an account to another browser or another device. That is the deliberate
  trade for working signed out; a per-account preference is a different decision and would need a
  column and a precedence rule between the account and the cookie.
- **The theme lives on the root element, so any future client-side theme switch must set
  `document.documentElement` explicitly** (or a full page load). A Turbo navigation alone will never
  change it. `test/system/settings_theme_test.rb` is what catches that.
- The dark theme has to be maintained by hand for anything that is not a Bootstrap variable. A new
  light-only literal color in the stylesheets is a dark-theme bug, so those surfaces are tokens with
  a dark value.
- The settings page is not part of the universe workspace, so it is not covered by the sidebar's scope
  rules or by universe authorization tests. Its own tests state that it works with no universe and
  with a guest.

## Alternatives considered

### A universe-scoped `/u/:universe_slug/settings`

Rejected. It would have to be admin-only (it would sit beside Members), which would deny the control
to a read-only member and a guest; it would be unreachable from the landing page; and it would imply
that a universe can own a display preference, which contradicts the scope decision. The owner chose
the top-bar entry for the same reason.

### A `users.theme` column

Rejected. It needs a migration, it cannot be used by a guest, and it does not work on the landing
page. It remains the right answer if a preference ever has to follow an account across devices, and
the account value could then take precedence over the cookie.

### A `System` option following `prefers-color-scheme`

Rejected for now, deliberately out of scope: it needs a client-side `matchMedia` listener to
re-evaluate without a page load, which is the client-side script this decision avoids. The two themes
are a complete, honest first version.

### Applying the theme to `<body>` instead of the root element

Rejected. It would make a Turbo submission work without `data: { turbo: false }`, but the theme is a
document-level choice: `color-scheme` should apply to the whole document, including the canvas and
scrollbar outside the body, and `<html data-bs-theme>` is what Bootstrap documents. The cost of the
root element is one opted-out form, which is a smaller and more visible cost than a half-themed
document.

### A top-bar toggle that switches the theme without a page load

Rejected for now. It is a nicer interaction, but it is a new client-side code path (an instant
attribute flip, then a background write of the cookie) that needs its own Bun tests and a CSRF
decision, and it is not what was asked for.

## Related documentation

- [`../architecture.md`](../architecture.md)
- [`../universe_maker_conventions.md`](../universe_maker_conventions.md)
- [`../visual_design.md`](../visual_design.md)
- [`../development.md`](../development.md)
- [0001](0001-universe-and-story-scope.md)
- [0005](0005-universe-access-levels.md)
- [0012](0012-client-side-verification-and-csrf.md)
