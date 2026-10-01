# ADR 0017: Keep the start page browser-owned, and bind the remembered destination to the account

- **Status:** Accepted
- **Date:** 2026-10-01
- **Related:** [`../features/settings.md`](../features/settings.md),
  [`../architecture.md`](../architecture.md),
  [0013](0013-platform-settings-and-browser-theme.md),
  [0016](0016-internationalization-and-browser-locale.md),
  [0001](0001-universe-and-story-scope.md),
  [0005](0005-universe-access-levels.md)

## Context

A reader signing in with nothing to return to lands on the universes index and has to choose a
universe and a story again, even when they left off in one five minutes ago. The request was to make
signing in go straight back to the last universe and story, with the behaviour on by default, and to
let it be turned off from the settings page. It was also stated that this preference is neither
"appearance" nor "language", so its settings category was left to the implementer.

The application already remembers a story, but it does so in a place that cannot answer this question.
`set_current_story` keeps a per-universe map in `session[:current_story_ids]`, and the authentication
concern **deliberately deletes that map** whenever a session starts, ends, is invalidated by a stale
cookie, or is destroyed by a password reset
(`app/controllers/concerns/authentication.rb`). That is right: it is what stops one account's story
choices from being handed to the next account on the same browser. It also means the memory is gone
by the time a new sign-in happens.

Three things follow from that, and they are what make this a decision rather than a small change.

1. The destination has to live outside the session, or it cannot survive a sign-out.
2. It must not become a session that outlives a sign-out, or the clearing above stops meaning
   anything and a shared browser leaks one reader's working context into another's.
3. [ADR 0001](0001-universe-and-story-scope.md) forbids falling back to the universe's first story, so
   "the last story" is the **only** thing that may become a landing page, and only because it was
   explicitly chosen.

There is also a question of which page the preference belongs to. Appearance and Language are display
state: they change how a page is drawn. This changes *which page is opened*, so folding it into either
would have made both sections mean something they do not.

## Decision

- **`AppStartPage` is a third browser-owned signed cookie**, `um_start_page`, with two known values:
  `remember` (the default) and `universes`. It follows [ADR 0013](0013-platform-settings-and-browser-theme.md)
  exactly — a plain Ruby class with a `normalize` chokepoint, a signed cookie, no `User` column, no
  universe scope, reachable by a guest before a universe is chosen.
- **It gets its own section on `/settings`**, the third tab, because it is navigation state rather than
  display state. The sections are a list (`SETTINGS_SECTIONS`) rather than a pair of booleans so that
  adding one stays a single declarative entry.
- **The remembered destination is a separate signed cookie**, `um_last_scope`, holding JSON: the
  `user_id` that wrote it, the universe slug, and the story id. It is deliberately *not* the same
  cookie as the preference. The preference is a durable choice; the destination is moving state, and
  mixing them would mean every page view inside a universe rewrote the reader's durable preference.
- **The destination is bound to the account that wrote it.** `RememberedDestination.for` returns
  nothing unless the stored `user_id` is the account signing in. This is the same rule the session map
  already follows, expressed in the one place that outlives the session.
- **Everything read out of it is re-resolved and re-authorized**, never trusted. A signed cookie cannot
  be forged, but it can be stale: the universe may since have been made private, the membership
  revoked, or the story deleted. Reading resolves live records, checks `readable_by?`, and finds the
  story *through that universe's own collection*, so a tampered story id finds nothing rather than
  reaching a neighbouring universe's story. Every one of those cases answers `nil`, which is the same
  universes-list landing a reader with no memory gets.
- **A page to return to still wins.** The preference only answers "and when there is nothing to return
  to?", so `after_authentication_url` tries the stored return destination, then the remembered
  destination, then the universes list.
- **Sign-out does not forget it.** That is the entire point: the feature is about resuming across a
  sign-in. `terminate_session` still clears the session map; the browser cookie is a different thing.
- **The root path is unchanged.** `/` is still the universes index, because that is where a universe is
  chosen and created. Only the post-sign-in redirect follows the preference.

## Consequences

### Benefits

- Signing in returns a reader to their work, which is the common case, with no extra click.
- The preference follows the reader to the landing page and works for a guest, exactly like the other
  two, and adding it needed no migration and no new table.
- The safety properties are stated once and tested once, in `RememberedDestination`, rather than
  spread through the controller.

### Costs and constraints

- **The destination does not follow an account to another device.** It lives in a browser, the same
  trade ADR 0013 records for the theme. A per-account column would follow, and would need a precedence
  rule between the account and the cookie.
- **A shared browser carries one account's destination to another**, and this is deliberate: the
  binding is to the account id, so another account simply does not receive it. The cost is that
  signing in as a second account in the same browser resumes nothing, even though the first account
  used the same browser.
- **The remembered value is re-checked on every sign-in**, which costs one universe lookup and one
  story lookup per sign-in. It is not re-checked on every request, and the write is skipped when the
  destination has not changed, so ordinary browsing does not rewrite the cookie.
- **A story that was deleted becomes the universe alone**, not a dead link. This is a real behaviour
  difference from having no memory at all, and it is stated in the tests.
- `remembered_start_url` lives in the authentication concern rather than in `Current`, because a
  remembered destination is not the current scope of the request being served.

## Alternatives considered

### A `users.last_story_id` column

Rejected for now, and this is the main alternative. It would follow an account across devices, which is
the better long-term answer, and it would make the binding structural rather than a value inside a
cookie. Rejected because it needs a migration, because the preference must also be settable by a guest
on the landing page (which a column cannot be), and because a *story id on a user row* would silently
become a fallback scope: a row would name a story that may since have moved, been deleted, or become
inaccessible, and the request path would have to re-authorize it anyway. The cookie keeps the stored
value obviously ephemeral and forces the re-authorization to be part of reading it.

### A session that survives sign-out

Rejected outright. It is the simplest thing that could work and it contradicts an existing deliberate
behaviour: the session story map is wiped on every session boundary precisely so an account switch
does not inherit a working context. Persisting it would undo that and would also mean signing out does
not really sign out of the workspace.

### Falling back to the universe's first story

Rejected, and this one is not a close call. ADR 0001 already rules it out, and a universe holds any
number of stories, so "the first" would be an arbitrary pick among equally valid ones. The remembered
value is the only story that may be a landing page, and only because the reader chose it.

### Folding it into Appearance or Language

Rejected. Both sections are display state and say so on the page. A reader who opened **Appearance**
to change their theme is not asking where a sign-in should go, and describing it there would make the
setting's scope untrue.

### Changing `/` to redirect to the remembered story

Rejected. `/` is the universes index: it is where a universe is chosen and created, and the brand links
to it. Redirecting it away would remove the only place those two things happen, and would make the
universes index unreachable while the preference was on.

## Related documentation

- [`../features/settings.md`](../features/settings.md)
- [`../architecture.md`](../architecture.md)
- [`../development.md`](../development.md)
- [0001](0001-universe-and-story-scope.md)
- [0013](0013-platform-settings-and-browser-theme.md)
- [0016](0016-internationalization-and-browser-locale.md)