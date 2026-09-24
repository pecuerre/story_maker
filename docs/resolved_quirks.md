# Resolved Quirks & Tech Debt

Entries that used to live in [known_quirks.md](known_quirks.md) and are **fixed now**. They are
kept for history: what the problem was, how it bit you, and how it was solved — that is why the
code looks the way it does today. Only *open* oddities belong in
[known_quirks.md](known_quirks.md).

Original entry numbers are kept ("former #8") so old references and commits still make sense.
Index of all docs: [README.md](README.md).

## Resolved vestigial code

### Former #9 — `ApplicationController#default_url_options` was a no-op (fixed)

**Then:** `ApplicationController` overrode `default_url_options` and called `super.merge()` with no
options, while the universe slug was supplied by Rails request recall.

**Fix:** the redundant override was removed. URL helpers continue to use the standard Rails
behavior and request recall; no application-specific `universe_slug` option is needed.

### Former #10 — Unused Hello Stimulus controller (fixed)

**Then:** `app/javascript/controllers/hello_controller.js` was an untouched Rails scaffold
controller. No view or application code used it; the import map's controller glob only made the
unused file discoverable.

**Fix:** the controller was deleted. The Stimulus eager loader now registers only the controllers
used by the application.

### Former #11 — Vestigial current-universe path wrappers (fixed)

**Then:** `SectionsController` and the section/event tag controllers carried private
`current_universe_*_path` wrappers. The plural wrappers were unused, and the singular wrappers
only forwarded to route helpers used to build JSON URLs.

**Fix:** the wrappers were removed. JSON responses now call the appropriate route helper directly,
so URL behavior is unchanged without the dead indirection.

### Former #12 — Root README was Rails scaffold boilerplate (fixed)

**Then:** the root `README.md` still contained the generated Rails placeholder, leaving no useful
entry point for the project.

**Fix:** the root README now provides a concise project overview, quick start, test commands, and
links to the detailed documentation in `docs/`, which remains the source of truth.

## Resolved correctness issues

### Former #17 — Sections URL did not make the story scope explicit (fixed)

**Then:** the story-scoped sections refactor left the universe-level `/u/:universe_slug/sections`
path as a dead end, while the replacement used the verbose `/stories/:story_id` segment.

**Fix:** stories are mounted at the short `/s` path, and sections and section tags are available
only at explicit story-scoped URLs such as `/u/:universe_slug/s/:story_id/sections`. The
universe-level sections URL is intentionally not routed; no compatibility alias is provided.

### Former #18 — Sidebar issued COUNT queries on every page (fixed)

**Then:** the left sidebar called `.count` for sections, characters, relations, locations, events,
items, and ownerships on every rendered page. A selected story therefore caused seven database
count queries on every request, even though the values changed only when content changed.

**Fix:** `Universe#menu_counts` now stores all six universe-level values together in one
`Rails.cache` entry, while `Story#menu_section_count` stores the selected story's value in a second
entry. `InvalidatesMenuCounts` expires the affected entry from model `after_commit` callbacks when
a counted record is created or destroyed (and when a record moves to another scope), so controller,
seed, console, and dependent-destroy writes all stay correct. It tracks every intermediate scope
during a multi-save transaction, and cache misses inside open transactions are never written, so
rollbacks cannot leave stale data. Owner destruction removes its own entry, `db:restart` clears the
cache after recreating the database, and a one-hour expiry is a safety net for rare cache-fill races
or maintenance writes that bypass callbacks. Production continues to use the existing Solid Cache
store; Redis is not required.

### Former #8 — Default-tag assignment crashed on tagless universes (fixed)

**Then:** `CharactersController#create` (and the location/item equivalents) did
`...character_tags.order(:id).first.id if ids.empty?` — a `NoMethodError` on `nil` when the
universe had no tags yet (tag fixtures/seeds normally prevented this), and it force-tagged
records the user had deliberately left untagged. `SectionsController#create` used
`Story#default_section_tag`, which lazily created a tag named *"Section"*.

**Fix:** tags became optional on every content model, so all default-tag fallbacks were removed
and `Story#default_section_tag` was deleted as dead code. Creating a record without tags simply
saves it untagged — a tagless universe (or story) is now a normal state, not a crash.

### Former #19 — Two lockfiles and a mismatched CSS watcher (fixed)

**Then:** `bun.lock` and `yarn.lock` coexisted, while `package.json` and the Rails CSS build used
Bun. `Procfile.dev` still launched the watcher with `yarn watch:css`, creating two possible package
managers and requiring Yarn for a workflow whose actual build commands call Bun.

**Fix:** Bun is now the only JavaScript package manager. `yarn.lock` was removed, `Procfile.dev`
uses `bun run watch:css`, Bun is pinned in `mise.toml`, and the development documentation names
`bun.lock` as the source of truth. CI and the Docker build install the pinned Bun version and use
`bun install --frozen-lockfile` in reproducible environments.

### Former #21 — Universes could be saved without a name (fixed)

**Then:** `Universe` had no validations, so a missing or blank name passed validation even
though other named records rejected it.

**Fix:** `Universe` now validates that `name` is present. Model and request tests cover the
validation and reject universe creation without a name; the existing form error handling renders
the validation message.

### Former #22 — Migrations mixed schema changes with application-data work (fixed)

**Then:** two later migrations backfilled and copied live records when moving sections and section
tags under stories. Those migrations referenced application models (`Story`, `Section`, and
`SectionTag`), so old migrations could break when model code changed. The database also had a
multi-step schema history rather than one current definition per model.

**Fix:** database data is disposable and is reconstructed from `db/data/`, so migrations are now
schema-only and the history is consolidated into one create migration per persisted model. The
story slug and the `story_id` foreign keys are defined directly in the corresponding create
migrations; the record-copying migrations were removed. Existing databases must be recreated with
`bin/rails db:restart`, which migrates the schema and then reloads `db/data/` through `db:seed`.

### Former #24 — Deleting a section tag silently un-tagged its sections (fixed, in two steps)

**Then:** section tags were universe-wide while sections were story-scoped, so a tag could be
deleted even though stories still referenced it.

**Fix, step 1 (scoping):** tags belong to a story — the `CreateSectionTags` migration defines
`story_id` directly, plus a `Section` validation that all `section_tags` share the section's story.
A tag can no longer be deleted from under *another* story.

**What remained:** deleting a tag still dropped the join rows of its own story, and the
affected sections only noticed at their **next save** (`section_tags` presence validation) —
a deferred, silent failure. The same applied to every tag model (character/location/item/event/
relation/ownership tags).

**Fix, step 2 (no presence validation):** `HasManyTags` no longer adds
`validates association, presence: true`, so tags are optional on **every** content model.
Deleting a tag simply leaves its records untagged, which is valid — no deferred failure, nothing
breaks at the next save, and no controller force-assigns a default tag to compensate
(see former #8).

### Former #15 — Fixture slugs did not match the normalized slug format (fixed)

**Then:** fixture rows explicitly stored underscore-separated slugs such as `section_one`, while
`HasSlug.slugify` normalizes underscores to dashes. Because fixtures load directly, a class-level
finder such as `Section.section_one` searched for `section-one` and could not find the row.

**Fix:** all fixture `slug` values now use the same dash-separated format as application-created
records. Fixture labels and association references remain unchanged, and a regression test verifies
that a fixture is reachable through its normalized class-level finder.

### Former #16 — `404` vs `RecordNotFound` in tests (resolved as a test convention)

**Then:** `config.action_dispatch.show_exceptions = :rescuable` causes an out-of-scope
`ActiveRecord::RecordNotFound` raised during a request to be rendered as HTTP 404, so an
`assert_raises` expectation around the request would not observe the exception.

**Resolution:** request tests assert the externally visible response with
`assert_response :not_found`; only direct model or lower-level lookups assert
`ActiveRecord::RecordNotFound`. The test configuration remains `:rescuable` because it reflects
the response behavior users receive.
