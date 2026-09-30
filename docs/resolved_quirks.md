# Resolved Quirks & Tech Debt

Entries that used to live in [known_quirks.md](known_quirks.md) and are **fixed now**. They are
kept for history: what the problem was, how it bit you, and how it was solved — that is why the
code looks the way it does today. Only *open* oddities belong in
[known_quirks.md](known_quirks.md).

Each entry is organized around the original problem and its resolution.
Index of all docs: [README.md](README.md).

## Resolved vestigial code

### `ApplicationController#default_url_options` was a no-op (fixed)

**Then:** `ApplicationController` overrode `default_url_options` and called `super.merge()` with no
options, while the universe slug was supplied by Rails request recall.

**Fix:** the redundant override was removed. URL helpers continue to use the standard Rails
behavior and request recall; no application-specific `universe_slug` option is needed.

### Unused Hello Stimulus controller (fixed)

**Then:** `app/javascript/controllers/hello_controller.js` was an untouched Rails scaffold
controller. No view or application code used it; the import map's controller glob only made the
unused file discoverable.

**Fix:** the controller was deleted. The Stimulus eager loader now registers only the controllers
used by the application.

### Vestigial current-universe path wrappers (fixed)

**Then:** `SectionsController` and the section/event tag controllers carried private
`current_universe_*_path` wrappers. The plural wrappers were unused, and the singular wrappers
only forwarded to route helpers used to build JSON URLs.

**Fix:** the wrappers were removed. JSON responses now call the appropriate route helper directly,
so URL behavior is unchanged without the dead indirection.

### Root README was Rails scaffold boilerplate (fixed)

**Then:** the root `README.md` still contained the generated Rails placeholder, leaving no useful
entry point for the project.

**Fix:** the root README now provides a concise project overview, quick start, test commands, and
links to the detailed documentation in `docs/`, which remains the source of truth.

### Former quirk #54: taxonomy field-builder duplication (fixed)

**Then:** `app/helpers/modal_fields.rb` held eight near-identical `*_tag_taxonomy_fields` helpers and
`app/helpers/tags_helper.rb` held eight near-identical workspace-config blocks, so adding one field or
URL to every taxonomy meant editing eight copies that could drift from each other and from the routes.
The DataFactor report flagged the duplication as a maintenance drift risk rather than a correctness
finding.

**Fix:** the shared editor fields are now built by `ModalFields#taxonomy_tag_fields` (every taxonomy)
and `ModalFields#content_tag_taxonomy_fields` (the four content tags, which add `show_in_menu`), with
`extra_fields` for the relation tag's `symmetric`/`inverse`. The workspace config is declarative
`TagsHelper` metadata (`UNIVERSE_TAG_METADATA`/`STORY_TAG_METADATA`) with the mechanical keys —
`model_param`, the field-descriptor helper, the tag URLs, the count label — derived from the type name.
Adding a field to every taxonomy is now a change in one helper. The serialized field/JSON contract and
the three UI patterns are unchanged, and the extraction is what let `taggable` and `show_in_menu` land
in one place per helper.

## Resolved conventions

### Positional path-helper arguments in universe routes (resolved as an enforced convention)

**Then:** `universe_story_sections_path(story)` looks like a natural nested-resource call, but
Rails assigns positional arguments to dynamic segments from left to right. The Story is therefore
assigned to `universe_slug`; outside request recall this raises a missing-`story_id` error, and in
some scoped requests it can silently produce a URL with the wrong universe segment.

**Resolution:** the route shape remains explicit (`/u/:universe_slug/s/:story_id/...`) and all
universe-scoped route-helper calls use named keys. `test/routing/universe_route_helper_arguments_test.rb`
parses Ruby and ERB sources and fails CI if an application or test call supplies positional
arguments to a `universe_*_path`/`universe_*_url` helper. Rails still permits positional arguments
in its generic API; this project-level guard prevents that footgun in its own code.

## Resolved correctness issues

### Former quirks #1–#3: Universe authorization and public/private access (fixed)

**Then:** `Ability` was unused and its universe rule referenced the nonexistent `user_id` column.
Universe-scoped controllers had no authorization callback, and `UniversesController` allowed
anonymous access to every universe action. `private: true` therefore hid a universe from the index
but did not protect its slug URL, and anonymous creation fell back to `User.first`.

**Resolution:** Universe Maker now has an explicit three-level access policy. `UniverseMembership`
stores read/write/admin membership for private universes and optional delegated public admins;
the owner is always admin. `Ability` defines the same rules for universes and every universe- or
story-scoped content class, and `UniverseAuthorization` applies them after resolving the universe
but before loading stories or content. Public universes allow guest read and signed-in write;
private universes allow only owners/members, with 404 for every non-member (including guests) and
403 for insufficient collaborator access. Guests attempting public-universe mutations are
redirected to sign in. The membership manager is available to universe admins at
`/u/:universe_slug/members`.

### Former quirk #6: nullable universe visibility failed open (fixed)

**Then:** `universes.private` allowed NULL and the policy treated NULL like false. A hidden universe
could therefore be readable by guests and writable by any signed-in user when reached directly by
slug.

**Resolution:** `Universe` now requires an explicit boolean, only an explicit `false` grants the
public baseline, and any ambiguous legacy value is handled as private by the policy. A schema-only
migration makes the column `NOT NULL`; it deliberately refuses to guess whether an existing NULL
row was public or private, so an older database must have those rows resolved explicitly before
migration. Tests cover validation, the database constraint, and fail-closed instance policy.

### Former quirk #7: HABTM tags could cross universe/story scope (fixed)

**Then:** all seven content/tag HABTM associations were unscoped. Four content models had no
same-scope validation at all, the other three validated only the content-to-tag direction, and
crafted `*_tag_ids` parameters could attach a private-universe tag to public content. Unscoped
inverse reads could also disclose corrupt foreign rows.

**Resolution:** every `HasManyTags` declaration now requires an explicit `:universe_id` or
`:story_id` scope. The concern applies that scope to both association directions and validates the
in-memory target so ID writers and inverse assignments fail normal model/controller saves with a
422 contract. Corrupt foreign join rows are hidden by scoped reads; the separate lack of database
join constraints remains tracked in the open quirks.

### Former quirk #13: anonymous private-universe enumeration (fixed)

**Then:** an unknown slug returned 404, but a guest request for an existing private universe was
redirected to sign-in. The different response disclosed that the slug existed.

**Resolution:** the shared `UniverseAuthorization` concern now converts every private-universe
read denial to the same 404 used for an unknown slug, before any story or content lookup. Public
guest reads remain public, and public guest mutations still use the normal sign-in redirect.

### Former quirk #14: story context survived authentication boundaries (fixed)

**Then:** the Rails session's `current_story_ids` map survived logout, account switching, current-user
password reset, and stale database sessions. A later account on the same browser could inherit a
story selection.

**Resolution:** authentication start, logout, current-user password reset, and stale-cookie handling
now clear the complete remembered-story map. They also remove invalid authentication cookies and
reset `Current.session` where appropriate. Tests preserve ordinary same-session story memory while
covering logout, direct account switching, reset, and stale-session cleanup.

### Former quirk #15: referenced events caused foreign-key 500s (fixed)

**Then:** restrictive self-foreign keys made `destroy!` fail when another event referenced the target
through `before_event`, `after_event`, or `simultaneous_event`. Universe destruction could fail for
the same reason. The self-reference validator compared only foreign-key IDs, so an unsaved event
could evade it.

**Resolution:** `Event` now declares all three incoming reference collections with
`dependent: :nullify`, so normal event and universe destruction releases references before deleting
the target. A referrer that existed only to point at the deleted event is removed first, preserving
`must_be_identifiable` for every retained row. `cannot_reference_self` checks both object identity
and the foreign-key id, while three schema-only check constraints close the insert-time gap where
SQLite assigns the new ID only during the write. Model and request tests cover every reference
direction, relation-only cleanup, universe destruction, unsaved/future-ID self-links, and direct
database writes.

### Universe-scoped content was not authorized (fixed)

**Then:** every content controller only scoped records with `Current.universe`; knowing a universe
slug was enough to read or mutate its content.

**Resolution:** all universe-scoped controllers now pass through the shared universe authorization
callback, and their existing association scopes preserve the universe/story boundary. The
`Ability` object also checks the corresponding content instances, so a permission granted for a
universe applies consistently to all of its components.

### Private universes were readable and mutable by slug (fixed)

**Then:** private universes were excluded from listings but `universes#show`, content routes, and
mutations did not apply visibility, and anonymous universe creation selected the first user as
owner.

**Resolution:** `Universe.visible_to` includes explicit memberships, `set_universe` uses
`find_by!`, private show/content requests pass through the shared policy, and universe creation
requires a real signed-in `Current.user` as owner. Public/private visibility is editable only by a
universe admin.

### `ApplicationHelper#visible?` always returned `true` (fixed)

**Then:** `ApplicationHelper#visible?` (`app/helpers/application_helper.rb`) computed the
controller comparison and discarded it, then returned literal `true`. The redesigned sidebar did
not call the helper, so the bug did not affect current navigation, but it made the helper unsafe
for future visibility decisions.

**Fix:** the stray test-only `true` was removed. The helper now returns the result of
`controllers.include?(controller.controller_name)`.

### HasSlug treated generated slugs as explicit on updates (fixed)

**Then:** `HasSlug#set_slug` checked `slug.present?` before checking whether `name` changed. Every
persisted record normally has a slug, so renaming any model normalized and preserved its old slug;
the `name_changed?` regeneration branch was effectively unreachable. This affected all models
that include `HasSlug`.

**Fix:** the callback now uses Rails 8 dirty tracking. A slug explicitly changed on the current save
wins; otherwise a changed name regenerates the slug; unrelated saves preserve the existing slug.
Unslugifiable values receive a random fallback so the non-null database constraint is respected.

### Relation/Ownership composite slugs were bypassed by HasSlug (fixed)

**Then:** `Relation` and `Ownership` registered their composite-slug callbacks after
`HasSlug#set_slug`. For unnamed records, the generic callback assigned a random slug first, so the
intended `character-tag-character` / `character-tag-item` slug was usually never generated.

**Fix:** both callbacks now run with `prepend: true`, before the generic `HasSlug` callback. Omitted
and blank names produce the documented composite slug, untagged records omit the optional tag
segment, and an explicitly supplied slug still wins for that save. Composite slugs remain
creation-time snapshots when endpoints or tags change; a name change follows the normal
name-based slug rule.

### Event name drifted when its title was renamed (fixed)

**Then:** `Event#set_name` ran only on create, so changing an event's `title` left the legacy
`name` field at its original value. `HasSlug` also ran before `set_name` during creation, which
could make a new event receive a random slug instead of one derived from its title.

**Fix:** `set_name` now runs before `HasSlug` on create and whenever the title changes. The title is
copied to `name`, and `HasSlug` regenerates the slug when that name changes.

### Former quirk #26: a duplicate universe name raised an uncaught uniqueness exception (fixed)

**Then:** a universe's slug is its public address (`/u/<slug>`) and is global, and `HasSlug`
derives it from the name. Two universes whose names slugify alike therefore collide — as does a
name that happens to derive an address another universe already holds. `universes.slug` carries a
partial unique index, but `Universe` validated nothing about it, so `UniversesController#create`
and `#update` let the index raise `ActiveRecord::RecordNotUnique` out of an ordinary save and the
author got a `500` instead of a stated reason. The form offered no way out either: it accepted no
slug, so the only recovery was to invent a different universe name.

**Fix:** `Universe` validates `slug` uniqueness with the same `deleted_at IS NULL` condition the
index uses (as `Story` already did for its own partial index), so a taken address is an ordinary
`:slug` field error — a `422` that renders in the shared error summary, or the documented `422`
error hash in the JSON contract — instead of a driver exception. The universe form gained an
optional **Address slug** field so the collision is answerable without renaming the world, and
`universes_controller`'s strong parameters accept it.

**The field is blank on both forms, and that is the whole point.** `HasSlug` already gives an
explicitly supplied slug priority for the save on which it is supplied, so a filled field republishes
the universe where the author asked, while a blank one leaves the callback to derive the address
from the name. The alternative — prefilling the field with the current address — would have shown a
value that the callback silently replaces on a rename, and forwarding the blank field as a cleared
attribute would have been worse: `HasSlug` would regenerate the slug from the name on an
*unrelated* save, so ticking **Private universe** would republish the universe under a new address
and invalidate every path stored below it. A blank slug is therefore dropped in
`universe_params` and the attribute is never assigned, and a request test pins that behaviour. A
refused save is the one case that shows a value: the form keeps the address the author typed, since
this field is the answer to the error being shown, and discards a derived one it never received.

### CI system-test job had no tests (fixed)

**Then:** the CI workflow ran `test:system`, but the repository had no `test/system` directory.
The command had no browser tests to execute (and could not load the missing test directory), so it
could not provide browser-level coverage and the screenshot artifact had nothing to capture.

**Fix:** added `test/application_system_test_case.rb` and an initial system-test suite covering
sign-in/sign-out, universe and story creation, story-scoped section navigation, character creation
through the modal editor, and workspace navigation to the timeline. The existing CI job now runs
real browser tests and retains its failure screenshots.

### System tests reused Chrome profile state (fixed)

**Then:** system tests reused one browser process across cases. Chrome's password/autofill state could
survive the Capybara session reset and intermittently clear the sign-in fields, producing a failure at
the intermediate email-field assertion.

**Fix:** `ApplicationSystemTestCase` now quits the browser after each test, before Capybara resets
its session pool. Each case starts with a fresh Chrome profile while preserving the normal Rails
screenshot teardown order.

### Building on an association leaked unsaved records into views (fixed)

**Then:** `Current.universe.stories.new(...)` added the new, unsaved `Story` to the `has_many`
association's in-memory target. A view that iterated the association during the same request could
encounter the object with `id: nil` and fail while generating a story URL.

**Fix:** `StoriesController` now builds the form object with
`Story.new(universe: Current.universe)` in both `new` and `create`, assigning the parent without
mutating `Current.universe.stories`. A controller regression test loads the association and verifies
that the unsaved form object is absent from its target.

### Sections URL did not make the story scope explicit (fixed)

**Then:** the story-scoped sections refactor left the universe-level `/u/:universe_slug/sections`
path as a dead end, while the replacement used the verbose `/stories/:story_id` segment.

**Fix:** stories are mounted at the short `/s` path, and sections and section tags are available
only at explicit story-scoped URLs such as `/u/:universe_slug/s/:story_id/sections`. The
universe-level sections URL is intentionally not routed; no compatibility alias is provided.

### Sidebar issued COUNT queries on every page (fixed)

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

### Default-tag assignment crashed on tagless universes (fixed)

**Then:** `CharactersController#create` (and the location/item equivalents) did
`...character_tags.order(:id).first.id if ids.empty?` — a `NoMethodError` on `nil` when the
universe had no tags yet (tag fixtures/seeds normally prevented this), and it force-tagged
records the user had deliberately left untagged. `SectionsController#create` used
`Story#default_section_tag`, which lazily created a tag named *"Section"*.

**Fix:** tags became optional on every content model, so all default-tag fallbacks were removed
and `Story#default_section_tag` was deleted as dead code. Creating a record without tags simply
saves it untagged — a tagless universe (or story) is now a normal state, not a crash.

### Two lockfiles and a mismatched CSS watcher (fixed)

**Then:** `bun.lock` and `yarn.lock` coexisted, while `package.json` and the Rails CSS build used
Bun. `Procfile.dev` still launched the watcher with `yarn watch:css`, creating two possible package
managers and requiring Yarn for a workflow whose actual build commands call Bun.

**Fix:** Bun is now the only JavaScript package manager. `yarn.lock` was removed, `Procfile.dev`
uses `bun run watch:css`, Bun is pinned in `mise.toml`, and the development documentation names
`bun.lock` as the source of truth. CI and the Docker build install the pinned Bun version and use
`bun install --frozen-lockfile` in reproducible environments.

### Universes could be saved without a name (fixed)

**Then:** `Universe` had no validations, so a missing or blank name passed validation even
though other named records rejected it.

**Fix:** `Universe` now validates that `name` is present. Model and request tests cover the
validation and reject universe creation without a name; the existing form error handling renders
the validation message.

### Migrations mixed schema changes with application-data work (fixed)

**Then:** two later migrations backfilled and copied live records when moving sections and section
tags under stories. Those migrations referenced application models (`Story`, `Section`, and
`SectionTag`), so old migrations could break when model code changed. The database also had a
multi-step schema history rather than one current definition per model.

**Fix:** database data is disposable and is reconstructed from `db/data/`, so migrations are now
schema-only and the history is consolidated into one create migration per persisted model. The
story slug and the `story_id` foreign keys are defined directly in the corresponding create
migrations; the record-copying migrations were removed. Existing databases must be recreated with
`bin/rails db:restart`, which migrates the schema and then reloads `db/data/` through `db:seed`.
This historical workflow was later replaced by [ADR 0008](adr/0008-explicit-development-universe-loader.md):
`db:restart` is now schema-only and `db:demo:reset` is the explicit data-loading reset.

### Deleting a section tag silently un-tagged its sections (fixed, in two steps)

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
breaks at the next save, and no controller force-assigns a default tag to compensate.

### Fixture slugs did not match the normalized slug format (fixed)

**Then:** fixture rows explicitly stored underscore-separated slugs such as `section_one`, while
`HasSlug.slugify` normalizes underscores to dashes. Because fixtures load directly, a class-level
finder such as `Section.section_one` searched for `section-one` and could not find the row.

**Fix:** all fixture `slug` values now use the same dash-separated format as application-created
records. Fixture labels and association references remain unchanged, and a regression test verifies
that a fixture is reachable through its normalized class-level finder.

### `404` vs `RecordNotFound` in tests (resolved as a test convention)

**Then:** `config.action_dispatch.show_exceptions = :rescuable` causes an out-of-scope
`ActiveRecord::RecordNotFound` raised during a request to be rendered as HTTP 404, so an
`assert_raises` expectation around the request would not observe the exception.

**Resolution:** request tests assert the externally visible response with
`assert_response :not_found`; only direct model or lower-level lookups assert
`ActiveRecord::RecordNotFound`. The test configuration remains `:rescuable` because it reflects
the response behavior users receive.

### Former quirk #4: Disposable universe data was coupled to `db:seed` (resolved)

**Then:** `db/seeds.rb` loaded a hard-coded Dark/LOTR list, Dark and LOTR had separate Ruby/YAML
loaders, missing or unknown data files were not governed by one registry, and the development
loader bypassed the documented sibling-position contract. A fresh `db:prepare` could therefore
load temporary users and data into a database that was not being used for local development.

**Resolution:** `db/seeds.rb` now loads only production-safe files under `db/seeds/`.
`Development::UniverseDataLoader` uses the shared `Development::UniverseDataRegistry` for model
order, file names, and supported universes; it validates references and scope before writing,
normalizes hierarchical positions, and is invoked only through explicit tasks. `db:demo:check` is
read-only in development/test, while `db:demo:load` and `db:demo:reset` require development.
The old per-universe Ruby loaders were removed and LOTR now uses the same YAML format as Dark.

### Former quirk #16: `db:restart` had no environment or confirmation guard (resolved)

**Then:** `db:restart` dropped, recreated, migrated, and seeded without checking `Rails.env` or an
explicit acknowledgement. The task description alone could not prevent a production invocation.

**Resolution:** `db:restart` now runs only in development with `CONFIRM_DB_RESET=1` and resets schema
without loading demo data. `db:demo:reset` has the same explicit confirmation and additionally
requires a registered `UNIVERSE` before dropping the database; it never invokes `db:seed`.

### Importmap Audit ignored the local Tom Select pin (fixed)

**Then:** `config/importmap.rb` mapped the bare `tom-select` import to
`vendor/javascript/tom-select.js` without a version annotation. Although the vendored file
identified itself as Tom Select `v2.6.2`, `bin/importmap audit` does not read version banners from
JavaScript files. It printed an "Ignoring tom-select" notice and did not include the direct package
in its npm advisory request.

**Resolution:** the local pin now carries the recognized `# @2.6.2` metadata comment.
`test/importmap_audit_test.rb` verifies that Importmap Audit sees the version and no longer emits
the warning. This closes the direct Tom Select audit blind spot; complete Bun/npm graph coverage,
vendored-file provenance checks, and Dependabot configuration remain separate follow-up work.

## Resolved security and interaction findings (2026-09-25)

### Former quirk #5: Kamal secrets were tracked (repository containment fixed; rotation pending)

The current tree adds `/.kamal/secrets` to `.gitignore`, removes the path from the Git index while
preserving the local file, restricts the local file to mode `0600`, and adds a CI guard that fails
if the path is tracked. The secret value was never read or reproduced. This does not rotate the
master key or remove prior copies from Git history, forks, CI artifacts, or backups; those are
explicit owner actions before deployment and remain recorded in `known_quirks.md`.

### Former quirk #8: taxonomy stored DOM XSS (fixed)

The taxonomy Stimulus controller now constructs options, fields, nodes, labels, descriptions, and
ARIA values with DOM APIs. User-controlled values are assigned as text or attributes and are never
interpolated into `innerHTML`. The browser regression stores a hostile option name, reopens another
node's editor, and verifies that the name remains text with no injected image/marker element.

### Former quirk #9: password-reset tokens in Rails request logs (fixed for application logs)

`PasswordResetPathFilter` redacts the dynamic `/passwords/:token` path segment in Rails' filtered
request path, including failed update targets, while ordinary `/passwords/new` remains readable.
Password-reset responses also set `Cache-Control: no-store` and `Referrer-Policy: no-referrer`.
Upstream proxy/access logs and browser history remain deployment responsibilities and are called
out in the production documentation.

### Former quirks #10 and #11: placeholder mail/URL and unenforced TLS (fixed in configuration)

Production now fails closed without `APP_HOST`, `MAILER_FROM`, and `SMTP_ADDRESS`; uses HTTPS
mailer URLs, explicit SMTP settings, and a non-placeholder sender; enables `assume_ssl` and
`force_ssl`; restricts the host allowlist; preserves `/up`; and sets the session cookie `Secure`.
A dummy production boot and configuration assertions passed. Real certificate/proxy setup and SMTP
provider delivery were not run and remain deployment verification steps.

### Former quirk #22: positioned sibling gaps and partial normalization (fixed for application paths)

`PositionedResourceOrder` now owns transactional create, move, reparent, and destroy maintenance,
locks the persisted scope owner, supports explicit flat mode, and is covered by service and
controller regressions. `Hierarchical` also normalizes siblings after direct model destroys. Raw
SQL/import and future flat direct-model paths remain a documented residual under
`known_quirks.md`; ADR 0009 records the boundary.

### Former quirk #25: blank password reset false success (fixed)

Password reset updates now use strong parameter expectations. Blank/malformed submissions return a
bad-request response without changing the digest or destroying sessions, and the controller test
covers that behavior.

### Former quirks #41–#44: stale taxonomy state and inaccessible insertion/reordering (fixed)

Successful taxonomy mutations now perform a same-URL Turbo visit, refreshing serialized
parent/tag descriptors, hierarchy state, page counts, and sidebar counts. Separators use their
actual list and position, including first/last boundaries. Native rename buttons support Enter and
Space; Move up/Move down and Insert before/Insert after provide pointer, touch, and keyboard paths;
touch media rules expose the controls and use 44px insertion targets. Browser regressions cover
hostile names, stale options/counts, root boundaries, keyboard activation, and narrow viewports.

### Former quirks #17 and #40: the flat-list modal committed behind a 406 and left stale rows (fixed)

**Then:** `modal_form_controller.js` only rewrote the form's action and method, so a browser create
or update reached a JSON-only controller as HTML. `respond_to` raised
`ActionController::UnknownFormat` **after** the record had been saved: the write committed, the
caller received `406 Not Acceptable`, validation errors never reached the form, and a retry created a
duplicate. Separately, the shared row Delete was a Turbo `button_to` against a destroy action that
answered a bare `204 No Content`, so Turbo had no replacement to apply and the row plus its counts
stayed in the DOM until a manual reload. The browser suite passed anyway, because the Character smoke
test asserted the row after a later navigation instead of looking at the mutation.

**Fix:** [ADR 0011](adr/0011-modal-json-mutation-contract.md) defines the shared modal contract. A
modal page declares `data-modal-form-response-value="json"|"html"`; in `json` mode the controller
submits the form itself as `application/x-www-form-urlencoded` with `Accept: application/json` and
the CSRF token, using the form's `_method` for the verb. A `422` error hash is rendered in a focused
summary and next to the control that caused it (association errors resolve to their foreign-key
field), the modal stays open with the entered values, and the submit button is never left disabled. A
request that never landed, a `403`, a `5xx`, and an unreadable body each report their own message.
Delete is issued by the same controller and a successful create, update, or delete performs a
same-URL Turbo visit, so rows, page counts, and cached sidebar counts come from one server render.
`RequiresJsonMutationFormat` makes the four flat-list and Scene Tag controllers refuse a non-JSON
mutation with `406` **before** writing, so the original duplicate-on-retry hazard cannot come back.
The mandatory deletion consequences now travel in `data-modal-form-confirm` on the new control.

`test/controllers/modal_json_contract_test.rb` pins the declared mode, the error region, the submit
target, and the row's delete control for all five modal workspaces, and asserts that an HTML mutation
to a JSON-only endpoint changes nothing. `test/system/modal_json_flow_test.rb` covers the browser
behavior: a real JSON create with refreshed counts, a record-level `422`, a field error rendered on
its control, a request that never reaches the server, a delete that fails and one that removes the row
and its counts, clearing the last tag, and a 390px viewport. Two smaller defects were found by that
coverage and fixed in the same change: the modal filled Rails' hidden companion field instead of the
multi-select (so a tag picker looked empty), and a multi-select name that already ends in `[]` was
given a second `[]`, which made the "clear the last tag" blank unparseable and left the old
assignment in place.

The taxonomy editor's rejection copy and the relation/ownership re-render still do not show a field
error summary; that gap is still open in
[`known_quirks.md`](known_quirks.md).

### Former quirk #18: mutation failures were not rendered in every editor (fixed)

**Then:** three editors reported a rejected save in three different inadequate ways. The taxonomy
tree's modal announced "The changes could not be saved." and closed nothing, but never rendered the
error hash it had been sent, and its single-field paths (inline rename, create, move, delete) used
the same generic wording for every server message. Relations and ownerships re-rendered their index
with `422` and nothing else: no model error summary, and the rejected entry discarded, so an author
had to retype it.

**Fix:** the one error-rendering contract now covers all of them.
`taxonomy_tree_controller.js` renders a `422` inside the editor the same way the flat-list modal
does — a focused `danger` summary plus the message on the control that caused it, resolving an
association error to its foreign-key field, because the hierarchy scope validation reports on
`:parent` while the field is `parent_id`. Its inline paths announce the server's own message when
the body carries one. The relations and ownerships workspaces keep the HTML re-render flow, and now
render the shared `shared/_error_summary` twice: once on the page the author lands on and once
inside the editor, with the rejected values serialized into the trigger that reopens it — the **Add**
trigger for a rejected create, and only the row being edited for a rejected update, so no other row
is affected.

Two things the browser coverage caught while doing this. The new taxonomy method
`errorFieldLabel` was first named `fieldLabel`, which silently replaced the controller's existing
`fieldLabel(field, id, className)` label builder; every taxonomy editor that opened raised
`TypeError: ((intermediate value) || attribute).replace is not a function` and no modal appeared at
all, which looked like flaky input rather than a name collision. And Bootstrap's focus trap focuses
the dialog when a modal finishes opening, so a save rejected during the opening transition lost the
error summary's focus; the editor now claims it back on `shown.bs.modal`.

Request coverage asserts the `422` error-hash shape and that a rejected entry reaches the trigger
that reopens the editor. Browser coverage lives in `test/system/modal_html_flow_test.rb` and
`test/system/taxonomy_tree_test.rb`.

### Former quirk #32: browser coverage was concentrated on the taxonomy tree (fixed)

**Then:** the browser suite exercised the taxonomy tree and the Scenes workspaces, so the flat-list
modals, relations, ownerships, memberships, and the password-reset journey were untested. The one
flat-list test passed even while its mutation was committed and answered `406`, because it asserted
the row after a later navigation.

**Fix:** each of those journeys now has a focused file or case:
`modal_json_flow_test.rb` (JSON create with refreshed counts, a record-level `422`, a field error on
its control, a request that never reaches the server, a delete that fails, a delete that removes the
row and its counts, clearing the last tag, and a 390px viewport), `modal_html_flow_test.rb` (a
rejected relation that reopens with its values, an ownership created through the modal, and the
row/editor at a 390px viewport), `membership_access_test.rb` (granting a level, an unknown address
refused with its reason, a granted member writing without reaching the Members page, and a read-only
member seeing the access notice and no mutation), `password_reset_test.rb` (the whole reset journey,
the mismatched confirmation, and an invalid token), and a rejected taxonomy edit in
`taxonomy_tree_test.rb`.

The suite grew from 39 to 50 browser tests. The request tests keep the exact status codes, which a
browser cannot see: `page.status_code` is only implemented by Capybara's rack-test driver, so the
membership browser test asserts the visible refusal instead and the request test owns the `403`.
Membership and password-reset browser coverage proves the visible behavior only; the request and
model tests remain the authority for authorization, tokens, and rate limiting.

### Hover-only row actions and an `aria-current`-less top bar (fixed)

**Then:** two related accessibility gaps shared one entry in
[`known_quirks.md`](known_quirks.md). A taxonomy row (Locations, Sections, and every tag tree)
revealed its action menu only on hover, through a `opacity: 0; pointer-events: none` rule that a
focus/touch media query had to undo. The top bar's universe and story dropdowns marked the current
item with a visual `.active` class and no `aria-current` on the link, so the current scope was
announced by color alone. The Scenes list also had no Details link, and the taxonomy Details link
carried its count as parenthesized text.

**Fix:** the top bar is now three links — the brand to the universes landing page, plus
**Universe:** and **Story:** as plain links to their own pages — with no switcher dropdown, and a
scope link carries `.active` together with `aria-current="page"` only on the page it points at.
Every list row follows one shape: a plain-text name with its tags and a `.record-count` pill on the
left, and an always-visible **Details** link followed by the action menu on the right. The count
moved out of the link into `record_count_badge`, which names what it counts ("(4 characters)"), and
the taxonomy node serializes that text onto the node
so the tree controller can restore the rename button exactly as the server rendered it when a rename
is cancelled. Browser regressions cover the no-hover visibility of both halves of the row, the
count's return after a cancelled rename, and the read-only Scene row.

Tag-color contrast validation remains open and is recorded in
[`known_quirks.md`](known_quirks.md).

### Former quirk #45: read-only empty taxonomy pages instructed users to add or drag records (fixed)

**Then:** the shared `shared/_taxonomy_tree` partial had a read-only empty-state fallback, but the
Locations and taxonomy views passed explicit writer copy containing "Add"/"drag" instructions, so
guests and read-only members saw mutation instructions even though no mutation controls were rendered.
The Sections workspace had already been fixed by passing both `empty_description` and the new
`read_only_empty_description` local; the remaining callers still needed it.

**Fix:** every remaining `shared/taxonomy_tree` caller now passes `read_only_empty_description`, so an
empty taxonomy shows mutation copy only to writers and a read-only "No … are defined yet." message to
guests and read-only members. A system regression signs in as a read-only member of a private universe
with no tags and asserts the read-only copy appears while the writer copy does not.

## Resolved Timeline findings (2026-09-29)

### Former quirk #24: Timeline output could contradict its layer ordering (fixed)

**Then:** `TimelineLayout` built a DAG of "happens no later than" relations, refused any edge that
would close a cycle (`reachable?`), and layered the events by longest path. It then threw that graph
away and rebuilt `@edges` from the raw `before_event`/`after_event`/`simultaneous_event` associations,
so the arrows the view drew did not have to agree with the rows it drew them across. Three
reachable contradictions, all confirmed by probe before the fix:

- An event whose dates ordered it after another, while declaring itself *before* that other, was
  placed on the lower row by the dates and then drawn with an arrow running back up the page.
- Two events each naming the other (`A.after_event = B`, `B.after_event = A`) produced **both**
  directions as drawn arrows: a cycle in the drawing that the graph had already refused.
- An event that was `simultaneous_event` with another *and* declared a sequence relation to it was
  drawn on the same row with both a dashed "same time" line and a solid one-directional arrow.

Nothing validated against this, and no test covered conflicting dates and relations, so the drawing
was the only place the contradiction could surface.

**Fix:** `@layers` is the single source of the rendered order, and `@edges` is now read back off it.
`build_edges`/`push_edge` emit a sequence edge only when the two events ended up on **strictly
different** rows with `from` above `to`, and a simultaneous edge only when they share a row — which
union-find guarantees. A relation the graph refused is therefore not drawn at all. It is deliberately
**not** drawn reversed to "match" the rows: reversing would invent a relation the author did not
declare and hide the conflict. A relation named from both sides is de-duplicated, so it draws one
arrow rather than two.

No model validation was added, on purpose. A `before_event` contradicting the dates is a legitimate
author state — dates are frequently approximate in a story bible, and the declared relation is often
the truer one. Rejecting it at save time would refuse data the application previously accepted; the
documented confidence order (full ranges → start dates → end dates → explicit relations) already
says which signal wins, and the drawing now simply follows it.

`test/models/timeline_layout_test.rb` grew from 4 to 11 cases. The new ones cover: a relation the
dates contradict (drawn nothing, layers unchanged), a relation the dates agree with (still drawn),
a mutual `after_event` cycle (exactly one arrow, asserted against the row indices rather than a
literal), simultaneous-plus-sequence on the same pair (only the simultaneous edge), a relation named
from both sides (one arrow), and a reference to an event outside the layout. The suite asserts
direction by looking up each endpoint's row, so a future change to the layering fails the test rather
than quietly invalidating it.

### Former quirk #46: Timeline nodes had no accessible name, and the docs promised pan/zoom (fixed)

**Then:** each node rendered only the record's numeric id inside a focusable `<div tabindex="0">`,
with no role and no accessible name — a screen reader announced a bare number for every event on the
page. The popover that carried the real description opened only on `hover focus`. Separately,
`architecture.md` and the conventions both described a pan/zoom interaction for
`timeline_controller.js` that **never existed**: the controller only ever drew SVG edges and
popovers, from its first commit (`fef94d1`) onward. The docs described an intended feature as
shipped behavior.

**Fix**, in two halves because the finding bundled two unrelated things:

- **The accessible name.** A node is now a real `<button>` with an `aria-label` built by
  `TimelineHelper#event_node_aria_label` from the same `event_popover_title` the popover header uses,
  so the label and the popover cannot describe different events. The button's UA chrome (padding,
  border) is reset in `_timeline.scss` so the node keeps its documented 40px circle and the author's
  tag colors; a `:focus-visible` outline was added since the node is now genuinely focusable. The
  popover trigger became `hover focus click`: a `<div>` could rely on hover, but a control that is
  meant to be operated needs a click path too, and a touch pointer never hovers.
- **The docs.** `architecture.md` and the conventions no longer claim pan/zoom; both now state that
  the Timeline is a static layered view. Per the owner's decision the pan/zoom interaction itself is
  **not** built — it is recorded as pending work in [`backlog.md`](backlog.md) rather than left as a
  false claim in the docs.

Coverage, per [ADR 0012](adr/0012-client-side-verification-and-csrf.md): four request cases in
`test/controllers/timeline_controller_test.rb` assert the node is a `button` with the expected label,
that the id-placeholder fallback is labelled correctly for a title-less event, that no `tabindex` is
left behind, and that the trigger includes `click`; the Spanish label is asserted in
`workspace_locale_test.rb`. The new `test/system/timeline_test.rb` covers what only a browser can
show: tabbing forward from the control before the timeline really lands focus on the node
(`document.activeElement`), the popover opens on focus alone, it opens on click, and an empty
timeline draws no nodes. `timeline_controller.js` itself is unchanged, so its `bun test` cases still
cover the drawn geometry unchanged.

## Resolved interaction findings (2026-09-29)

### Former quirk #60: four browser assertions in the tag and taxonomy suites were stale (fixed)

**Then:** `bin/rails test:system` was red before any new work started, from four assertions in
`test/system/tag_improvements_test.rb` and `test/system/taxonomy_tree_test.rb` that no longer
matched documented behavior. They reproduced in isolation on an idle machine, so they were not the
load sensitivity in quirk 58, and a red browser suite is exactly the state in which a real
regression cannot be told from an old failure.

- `tag_improvements_test.rb:16` asserted the canonical tag path after clicking a workspace menu-tag
  tab. A workspace tag link deliberately carries `from=workspace`
  ([conventions](conventions.md), flat-list pattern) so the tag page can preserve that
  navigation without trusting a `Referer` header. The app was right; the expectation was stale.
- `tag_improvements_test.rb:60` and `taxonomy_tree_test.rb:302` called
  `find("button[aria-expanded='false']")` inside a `li[data-node-id]`. A tag with children nests the
  child's `li` — and therefore the child's own collapsed row menu — inside the parent's, so the
  scope matched two toggles and raised `Capybara::Ambiguous`. The row grew a second control when
  grouping tags began listing their own children; the selector was never narrowed.
- `taxonomy_tree_test.rb:22` expected a page-header `.badge` of `3` where the page shows `4`. The
  badge is the taxonomy's own tag count (`TagsHelper` passes `count: ordered_records.length`), and
  `character_tag_one`, `character_tag_two`, and the nested `character_tag_child` are three tags
  before the test creates a fourth, so the header was correct and the literal was stale.

**Fix:** all four were test-side; no application code changed.

- The workspace tab is asserted with the `from=workspace` link it actually renders, and the test
  then follows the taxonomy tree's **Details** link for the same tag to confirm the canonical path
  is the same page without the origin. Both navigation styles are now covered where the
  convention is recorded.
- Every `find("button[aria-expanded='false']")` in the taxonomy suites is scoped to
  `li[data-node-id] > .taxonomy-row`, matching the existing convention in the same files, so a
  parent node's click cannot land on a child's menu. The four sites that used the bare node scope
  were narrowed, not only the two that were raising.
- The header badge is asserted against `universe.character_tags.count` and its `aria-label`, instead
  of a literal, so the test states the contract — the count is the taxonomy's tags, nested children
  included, and it tracks live creation because a create performs a same-URL Turbo visit.

The header count's meaning is now stated where it is documented, in
[conventions](conventions.md) under the taxonomy-tree pattern: the badge is every tag
in the taxonomy, children included, not the number of root rows.

### Former quirk #59: deleting a Character, Item, or Location announced none of the consequences ADR 0007 records (fixed)

**Then:** `shared/_row_actions` defaults to the short `Delete <name>?` confirmation, and the
Characters and Items workspaces passed no `confirm_text` of their own, so the mandatory templates in
[ADR 0007](adr/0007-story-owned-scenes-and-elements.md) were never rendered for those two.
Locations is a taxonomy tree and passed no `confirm_message`, so its delete fell back to the tree
controller's generic `Delete <name> and its children?`, which names the record and its descendants
but not the Scene presence links. Events, Scenes, Sections, and the Story and tag pages already
rendered their full templates.

The deletes themselves were correct: each model declares its own cascade, and a Character, Item, or
Location already soft-deleted its descendants, ownerships or relations, and presence links. Only the
confirmation a reader saw was silent, which is the exact unannounced-cascade risk the `confirm_text`
partial was written to prevent. The ADR's 2026-09-27 execution note had already narrowed its
"every confirmation template above is live" claim to the four that were.

**Fix:** all three surfaces now render the ADR's sentences, unchanged.

- Characters and Items pass `confirm_text` to `shared/_row_actions`, which serializes it as the modal
  controller's `data-modal-form-confirm` — the same channel Events already used.
- Locations passes a `confirm_message` lambda, which `shared/_taxonomy_tree` serializes per node as
  `data-confirm-message` for `taxonomy-tree#remove` to confirm on. That is the channel Section and
  SceneTag already used, so no JavaScript changed and the controller's generic message stays as the
  fallback for an unrendered node.
- The copy lives at `characters.delete_confirm`, `items.delete_confirm`, and
  `locations.delete_confirm`, beside the workspace that is its only reader, and each is the ADR
  sentence with `%{name}` interpolated. The record name is the author's own data, so it is
  interpolated rather than translated; both locales carry each string.

Four request tests read the rendered confirmation: `characters_controller_test.rb`,
`items_controller_test.rb`, and `locations_controller_test.rb` assert the English copy on the attribute
the page actually ships (`data-modal-form-confirm` for the two flat rows, `data-confirm-message` for
the tree node), and `universe_bible_locale_test.rb` asserts the Spanish Item and Location copy. Two
assertions elsewhere read the old short sentence and were updated to the full template:
`modal_json_contract_test.rb` (which is what pins the JSON-only row's delete copy at all) and the two
`accept_confirm` blocks in `test/system/modal_json_flow_test.rb`, which now accept whatever the row
sends because the copy's content is a request-test concern.

### Former quirk #48: delegated admins could demote or remove themselves into a blank 403 (fixed)

**Then:** the Members workspace rendered the access-level select and the Remove button on every
membership row, including the caller's own, and `MembershipsController#update` and `#destroy` had no
self-membership check. A delegated admin could therefore set their own level down to `write` or `read`,
or soft-delete their own row. The mutation redirected to `universe_memberships_path`, which is
admin-only (`universe_access_for_request` answers `:admin` for every `memberships` action), so the
redirect immediately failed the very authorization the author had just given up: `rescue_from
CanCan::AccessDenied` answers the documented bare `403`, and the browser landed on a bodyless page
with no explanation and no link forward. The owner was never exposed, because the owner is not a
membership at all and its row is hardcoded.

**Fix:** a self-mutation is refused before it is applied. `MembershipsController#own_membership?`
compares the target membership's user with `Current.user`, and both actions redirect to the landing
page with an alert (`memberships.flash.own_change_refused`, `memberships.flash.own_removal_refused`)
instead of redirecting to a page the author can no longer open. The view stops offering the controls
in the first place: the caller's own row keeps its access badge and shows a "You" label where the
change form and the Remove button would be, and another member's row is unaffected. A self-demotion
is now a stated refusal rather than a successful mutation with an unexplained dead end.

The bare `403` is deliberately unchanged for the case it was written for: a signed-in member who is
not an administrator asking for an admin-only page still gets the documented status code. The fix is
that the application no longer *produces* that state through its own UI.

Four request tests in `test/controllers/memberships_controller_test.rb` cover the refused
self-demotion (level unchanged, alert, redirect to the landing page), the refused self-removal (the
row is still there), the absence of change and Remove controls on the caller's own row, and the
presence of both controls on another member's row. No browser test was added: the change is
server-rendered ERB with no client-side path, and the request suite asserts the same markup the
browser would render.

## Resolved client-side verification and CSRF findings (2026-09-27)

### Former quirk #33: client-side code had no tests, no linter, and an unverified CSRF path (fixed)

**Then:** the security-sensitive half of every mutation lived in Stimulus controllers with nothing
checking it. `package.json` had only the CSS build and watch scripts, there were no JavaScript
spec files, and no JavaScript linter, so a controller regression surfaced as a browser test that
already looked green or as a production report. The test environment also disabled
`allow_forgery_protection`, so nothing proved that a `fetch` from those editors carried a token at
all, and Brakeman does not read client-side code.

**Fix:** [ADR 0012](adr/0012-client-side-verification-and-csrf.md) records the decision.

- `bun run test:js` runs Bun's built-in test runner over `test/javascript/`, one file per
  controller, in a happy-dom DOM. `test/javascript/setup.js` provides that DOM and replaces
  `@hotwired/stimulus` and `bootstrap` with minimal stubs, because the application serves both from
  the import map rather than `node_modules`; `bunfig.toml` preloads it. The 62 cases cover the
  request the editors build (token, verb, payload, cleared multi-select), the `422` rendering
  contract, the page-level status region, the drawn Timeline geometry, and the taxonomy row builders
  with a hostile name.
- `bun run lint:js` runs Biome's recommended rules over `app/javascript` and `test/javascript` in
  the new `js-check` CI job. Linting is not formatting: the controllers keep their hand-written
  style.
- `test/javascript/no_html_sink_test.js` fails when a new `innerHTML`/`outerHTML`/
  `insertAdjacentHTML`/`document.write` sink appears in `app/javascript` without a reviewed
  exception, which keeps the DOM-API-only rule from former quirk #8 enforceable.
- `test/controllers/csrf_mutation_test.rb` and `test/system/csrf_token_test.rb` wrap their own
  window in `with_forgery_protection` (`test/test_helpers/forgery_protection_test_helper.rb`).
  Between them they prove that the page's `csrf-token` meta tag is sent by both `fetch`
  implementations, that the server accepts it, and that a missing or forged token is refused with
  `403` and writes nothing — the browser cases do it by removing the meta tag, the request cases by
  replaying the token a real page published.
- A JSON mutation whose token is refused now answers `403` instead of the generic `422` page
  (`ApplicationController`), so the shared editor reports a refusal and keeps the author's input
  rather than claiming the server explained nothing. HTML requests keep Rails' own handling.

The new unit tests also found three defects in the code they were written for, all fixed here:
cancelling an inline taxonomy rename restored the author's unsaved text instead of the name the
server had rendered, a `belongs_to` error keyed on `:parent` was labelled `parent` instead of the
editor's own **Parent tag** label, and a `422` body whose `errors` was not an object was read as an
error on an attribute literally called `errors`. The taxonomy editor's `fetch` also always sent an
`X-CSRF-Token` header, so a page without the meta tag would have sent the literal string
`undefined`; it now omits the header, as the flat-list modal already did. The linter's first run
reported the two self-assigning reload fallbacks and ten `forEach` callbacks that returned a value,
all replaced with `window.location.reload()` and braced bodies.

The deliberately unchanged part: `allow_forgery_protection` is still off for the fast request suite,
so a new mutation path has to be added to one of the two CSRF files on purpose. The browser suite
also remains an initial smoke suite, not exhaustive UI coverage.

## Verification history

The dated runs below recorded what was checked after each resolved entry. They are kept as evidence
that a fix was verified, not as a description of today's capabilities; the current commands are in
[`development.md`](development.md).

## Follow-up verification (2026-09-27, client-side verification and CSRF — quirk 33)

- `bun run lint:js` (Biome 2.5.14, recommended rules) — clean over 13 files. Its first run reported
  12 real findings, all fixed in this change.
- `bun run test:js` — 62 tests, 170 assertions, 0 failures, across 4 files.
- `bin/rails test` — 526 tests, 3,185 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test:system` — 54 tests, 636 assertions, 0 failures, 0 errors, 0 skips
  (`SE_CHROME_NO_SANDBOX=1`, which this machine needs).
- `bin/rubocop` — 215 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings.
- `bin/bundler-audit`, `bin/importmap audit`, `bun audit` — no known vulnerabilities; `bun audit`
  now covers 116 packages including the two new dev dependencies.
- `bun install --frozen-lockfile` — clean against the updated `bun.lock`, which is what CI uses.

Not run: `UNIVERSE=dark|lotr bin/rails db:demo:check` (no `db/data` manifest, schema, or seed file
changed), a destructive `db:demo:reset`/`db:load`, Docker/Kamal build or deployment, production SMTP
delivery, a clean migration-from-zero job, and a browser pass against loaded development data. The
`js-check` CI job itself was not executed here: the same two commands were run locally with the
pinned Bun 1.4.2 that the job installs.

## Follow-up verification (2026-09-25)

The explicit development-data loader follow-up was verified after ADR 0008:

- `bin/rails test` — 280 tests, 1,701 assertions, 0 failures/errors/skips.
- `bin/rubocop` — 166 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings.
- `bin/bundler-audit` — no known vulnerabilities.
- `bin/importmap audit` — no reported vulnerabilities; at this checkpoint vendored Tom Select
  remained ignored (fixed in the follow-up below).
- `UNIVERSE=dark bin/rails db:demo:check` and `UNIVERSE=lotr bin/rails db:demo:check` passed in
  development and test environments.
- `RAILS_ENV=test bin/rails db:seed` passed without loading development data.

Destructive `db:demo:reset`, `db:restart`, Docker/Kamal deployment, production SMTP delivery, a clean
migration-from-zero job, and a live hostile-browser exploit were not run. The loader's transactional
load and rollback paths were covered in the test environment instead.

## Follow-up verification (2026-09-25, Tom Select audit metadata)

The local Tom Select pin was annotated with its locked version and the importmap regression test
was added:

- `bin/importmap packages` reports `tom-select 2.6.2`.
- `bin/importmap audit` reports no vulnerable packages and no longer prints an
  `Ignoring tom-select` notice.
- `bin/rails test test/importmap_audit_test.rb` — 1 test, 4 assertions, 0 failures/errors/skips.
- `bin/rails test` — 281 tests, 1,707 assertions, 0 failures/errors/skips.
- `bin/rubocop` — 167 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings.
- `bin/bundler-audit` — no known vulnerabilities.
- `git diff --check` — clean.

The broader Bun/npm graph audit, vendored-file provenance verification, and Dependabot coverage
remain open under the "Complete dependency, JavaScript, and container supply-chain checks" item in
[`backlog.md`](backlog.md). No destructive database, container, deployment, or browser
operations were run for this tooling-only fix.

## Follow-up verification (2026-09-25, ordering/security/taxonomy hardening)

- `bin/rails test` — 300 tests, 1,781 assertions, 0 failures/errors/skips.
- `bin/rails test:system` — 10 tests, 107 assertions, 0 failures/errors/skips, including the new
  taxonomy hostile-name, stale-state, boundary insertion, keyboard, and narrow/touch coverage.
- `bin/rubocop` — 173 files, no offenses.
- `node --check app/javascript/controllers/taxonomy_tree_controller.js` — passed.
- A production-configuration smoke boot with dummy non-secret settings confirmed HTTPS mailer URL
  options, `force_ssl`, `assume_ssl`, SMTP address, and the production host allowlist. Missing
  `APP_HOST` fails with only the variable name in the error.
- Password-reset path filtering, multipart mail rendering, cookie flags, ordering service, and
  loader tests passed. No destructive database task, Docker/Kamal deployment, real SMTP delivery,
  credential rotation, Git-history rewrite, or proxy/log-retention verification was performed.

## Follow-up verification (2026-09-25, Scene core)

- `bin/rails test` — 341 tests, 2,034 assertions, 0 failures/errors/skips.
- `bin/rails test:system` — 12 tests, 151 assertions, 0 failures/errors/skips, including the new
  Scene narrative-order and read-only browser coverage.
- `bin/rubocop` — 179 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings.
- `UNIVERSE=dark bin/rails db:demo:check` and `UNIVERSE=lotr bin/rails db:demo:check` passed in the
  test environment with the new `scenes.yml` manifests.
- `bin/rails db:migrate` applied the schema-only `CreateScenes` migration and regenerated
  `db/schema.rb`; no data operations were added to the migration.

Not run: `bin/bundler-audit`, `bin/importmap audit`, `bun audit` (no dependency or JavaScript pin
changed in this delivery), `db:demo:reset`/`db:demo:load` (destructive, needs approval), a browser
manual pass against loaded development data, Docker/Kamal deployment, and any production SMTP or
proxy verification.

## Follow-up verification (2026-09-25, Scene references and grouping)

- `bin/rails test` — 405 tests, 2,344 assertions, 1 failure. The single failure is pre-existing and
  unrelated: `UniverseDataLoaderTest#test_loads_the_Dark_universe_and_normalizes_sibling_positions`
  still expects the story name `netflix dark` after commit `0a236a9` renamed it to `Netflix Dark`
  in `db/data/dark/stories.yml`. It was already failing on a clean tree before this work.
- `bin/rails test:system` — 16 tests, 202 assertions, 0 failures/errors/skips, including the new
  Scene Section-grouping, in-world-time, narrow-viewport with a long title/description,
  keyboard-only, and read-only coverage.
- `bin/rubocop` — 187 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings.
- `node --check app/javascript/controllers/taxonomy_tree_controller.js` — passed.
- `UNIVERSE=dark bin/rails db:demo:check` and `UNIVERSE=lotr bin/rails db:demo:check` passed in
  development with the new `scenes.yml` references.
- `CONFIRM_DB_RESET=1 UNIVERSE=dark bin/rails db:demo:reset` and `UNIVERSE=lotr bin/rails
  db:demo:load` rebuilt the local development database from the amended/added migrations, and the
  loaded Dark and LOTR universes were queried to confirm the section paths, event links, and
  independent in-world times. `bin/rails db:migrate:status` shows both Scene migrations applied.

Not run: `bin/bundler-audit`, `bin/importmap audit`, `bun audit` (no dependency or importmap pin
changed in these slices), Docker/Kamal deployment, production SMTP delivery, proxy/log-retention
verification, and a browser manual pass against the reloaded development data. No destructive task
was run beyond the standing `db:demo:reset` approval.

## Follow-up verification (2026-09-25, Scene Tag)

- `bin/rails test` — 440 tests, 2,544 assertions, 1 failure. The remaining failure is the
  pre-existing Dark story-name expectation documented above; the new Scene Tag model, request,
  assignment, loader, authorization, routing, and helper coverage passed.
- `bin/rails test:system` — 18 tests, 225 assertions, 0 failures/errors/skips on the final
  run with a temporary 10-second Capybara wait; the default two-second wait intermittently timed
  out under local browser load. The focused Scene Tag browser file passed with the default wait.
  Coverage includes the Scene Tag taxonomy create/assign journey and read-only path.
- `bin/rubocop` — 196 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings; `bin/bundler-audit`, `bin/importmap audit`, and
  `bun audit` reported no vulnerabilities.
- `UNIVERSE=dark bin/rails db:demo:check` and `UNIVERSE=lotr bin/rails db:demo:check` passed. The
  local development database was rebuilt with the approved Dark reset and LOTR create-only load;
  queries confirmed 8 Dark/5 LOTR Scenes, 4 Scene Tags per Story, nested tags, and tagged/untagged
  Scene assignments. `bin/rails db:migrate:status` shows `CreateSceneTags` applied.
- `git diff --check` — clean.

Not run: Docker/Kamal deployment or boot, production SMTP delivery, proxy/log-retention
verification, and a separate manual browser pass outside the automated system suite. The only
known full-suite failure is the pre-existing `UniverseDataLoaderTest` Dark story-name expectation
recorded in the Scene references and grouping verification section.

## Follow-up verification (2026-09-25, Dark story-name test fix)

- `bin/rails test` — 440 tests, 2,552 assertions, 0 failures, 0 errors, 0 skips. This clears the
  standing failure recorded in the Scene references/grouping and Scene Tag verification sections
  above. The assertion
  count rose by 8 because the previously failing test aborted at its first bad expectation and
  never ran its remaining assertions.
- Root cause: commit `0a236a9` renamed the `dark` universe's development story to `Netflix Dark`
  in `db/data/dark/stories.yml` but wrote the loader test expectation as the lowercase
  `netflix dark`. The manifest value was always correct, so only the assertion was changed. No
  application code, schema, or demo data was touched.
- `UNIVERSE=dark bin/rails db:demo:check` passed; no YAML manifest changed, so the local
  development database did not need a rebuild.

Not run: `bin/rails test:system` (no behavior, view, or JavaScript change), `bin/rubocop`,
`bin/brakeman`, the dependency audits, `db:demo:reset`/`db:demo:load` (destructive, needs
approval), and Docker/Kamal deployment. `db:demo:check` was re-run for the test-only change
because the assertion reads the checked-in Dark manifest.

## Follow-up verification (2026-09-25, cssbundling rake constant warnings)

- `bin/rails test` — 440 tests, 2,552 assertions, 0 failures, 0 errors, 0 skips, run three
  consecutive times with no `already initialized constant` output. The count is unchanged from the
  Dark story-name fix above; this change only removes the noise.
- `bin/rubocop` — 196 files, no offenses.
- Root cause was in the test suite, not the gem. `DevelopmentDataTasksTest`'s `setup` block called
  `Rails.application.load_tasks` before each of its three tests. That re-runs the Rakefile and
  re-loads every bundled gem's rake file, and `cssbundling-rails` 1.4.3's
  `lib/tasks/cssbundling/build.rake` assigns `Cssbundling::Tasks::LOCK_FILES` without an
  idempotency guard, so every re-load re-defined the constant and warned. Because the parallel
  test workers are separate processes that start with an empty Rake registry, the
  `unless Rake::Task.task_defined?("db:demo:check")` guard never short-circuited and the number of
  warnings varied run to run.
- Fix: the test now loads only this application's own `lib/tasks/**/*.rake`, memoized once per
  process, which is the only thing it asserts about. Gem rake files are never loaded, so no gem
  constant is redefined. `db:demo:check`, `db:demo:load`, and `db:demo:reset` are still registered
  and asserted exactly as before.
- Not a gem upgrade: `cssbundling-rails` stays pinned at 1.4.3, because the application never
  double-loads rake tasks in normal operation. Fixing the constant redefinition inside the gem was
  judged out of scope.

Not run: `bin/rails test:system`, `bin/brakeman`, `bin/bundler-audit`, `bin/importmap audit`,
`bun audit` (no behavior, view, JavaScript, dependency, or schema change), and Docker/Kamal
deployment.

## Follow-up verification (2026-09-26, shared modal JSON reliability)

- `bin/rails test` — 516 tests, 3,110 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test:system` — 39 tests, 492 assertions, 0 failures, 0 errors, 0 skips on three
  consecutive full runs, including the new Character/Item/Event modal regressions.
  `SE_CHROME_NO_SANDBOX=1` was used because this machine blocks Chrome's user namespace. During
  development one run behaved as if no real mouse input reached the page (dropdown and button clicks
  were ignored) and was not reproducible afterwards; the same symptom appeared in the untouched
  taxonomy suite, so it was an environment problem, not an application one. That work uncovered two
  real races in the new error path, both fixed and both covered: the browser moves focus off a
  submit button that has just been disabled, and Bootstrap's own focus trap focuses the dialog when
  a modal finishes opening, so a save rejected during the opening transition lost the error
  summary's focus to it.
- `bin/rubocop` — 209 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings.
- `node --check app/javascript/controllers/modal_form_controller.js` — passed.
- `git diff --check` — clean.

Not run: `bin/bundler-audit`, `bin/importmap audit`, and `bun audit` (no dependency, importmap pin,
or vendored asset changed in this delivery), `db:demo:reset`/`db:demo:load` (destructive, needs
approval; no `db/data` manifest changed either), Docker/Kamal deployment, and a manual browser pass
outside the automated system suite.

## Follow-up verification (2026-09-26, error UI in every editor, quirks 18 and 32)

- `bin/rails test` — 521 tests, 3,149 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test:system` — 50 tests, 596 assertions, 0 failures, 0 errors, 0 skips, on four
  separate full runs of the final code (with `SE_CHROME_NO_SANDBOX=1`, which this machine needs).
  The suite grew by 11 browser tests.
- `bin/rubocop` — 212 files, no offenses.
- `bin/brakeman --no-pager` — 0 security warnings.
- `node --check` for `modal_form_controller.js` and `taxonomy_tree_controller.js` — passed.
- `git diff --check` — clean.

Two notes for whoever reads the failure history of this file, because both were real and only one
of them was the application's fault. First, a long stretch of intermittent browser failures in this
session was diagnosed as dropped input and turned out to be a method-name collision in the new
taxonomy code: the three tests that click **Edit** in a row menu failed every time, which looks like
an input problem and was not. Second, a genuinely intermittent input problem also exists here: in
some full runs Chrome delivers no `mousedown`/`click` to the page at all, and the affected failures
land in pre-existing tests (`SceneTagsTest`, `WorkspaceNavigationTest`) with "the row/modal never
appeared" symptoms. A recurrence of that shape should be re-run once before it is believed.

The browser suite can also only assert what a browser can see: `page.status_code` exists only on
Capybara's rack-test driver, so the membership browser test asserts the visible refusal and the
request test owns the exact `403`.

Not run: `bin/bundler-audit`, `bin/importmap audit`, and `bun audit` (no dependency, importmap pin,
or vendored asset changed), `bun run build:css` (no SCSS change), `db:demo:reset`/`db:demo:load`
(destructive, needs approval; no `db/data` manifest changed), Docker/Kamal deployment, and a manual
browser pass outside the automated suite.

## Follow-up verification (2026-09-29, stale browser assertions — quirk 60)

- `PARALLEL_WORKERS=1 bin/rails test test/system/tag_improvements_test.rb
  test/system/taxonomy_tree_test.rb` — before: 17 runs, 185 assertions, 2 failures, 2 errors. After:
  17 runs, 208 assertions, 0 failures, 0 errors, 0 skips. The extra assertions are the
  `from=workspace` href, the canonical Details-link path, and the badge `aria-label`.
- `PARALLEL_WORKERS=2 bin/rails test:system` — 117 tests, 1,524 assertions, 0 failures, 0 errors,
  0 skips. The full browser suite is green, which is the point of the entry: a regression in a later
  change is now distinguishable from one of these four.
- `bin/rubocop test/system/tag_improvements_test.rb test/system/taxonomy_tree_test.rb` — 2 files,
  no offenses.

Not run: `bin/rails test` and `bin/rails test:system`'s non-browser companions were not extended
because no application, model, or view code changed — the four edits are test expectations and
selectors, and the full browser suite is the suite that covers them. Also not run:
`bin/brakeman --no-pager`, `bin/bundler-audit`, `bin/importmap audit`, and `bun audit` (no
authorization rule, route, dependency, importmap pin, or schema changed), `bun run check:js` (no
client-side code changed), `UNIVERSE=dark|lotr bin/rails db:demo:check` (no `db/data` manifest
changed), and `db:demo:reset`/`db:restart`/Docker/Kamal deployment (destructive, needs approval).

## Follow-up verification (2026-09-29, membership self-mutation — quirk 48)

- `bin/rails test` — 1,060 tests, 6,338 assertions, 0 failures, 0 errors, 7 skips.
- `bin/rails test test/controllers/memberships_controller_test.rb` — 14 tests, 60 assertions,
  0 failures, 0 errors, 0 skips.
- `bin/rubocop` — 324 files, no offenses.
- `git diff --check` — clean.

Not run: `bin/rails test:system` (the fix is server-rendered ERB with no client-side path, and the
request suite asserts the markup the browser would render), `bin/brakeman`, `bin/bundler-audit`,
`bin/importmap audit`, and `bun audit` (no authorization rule, route, dependency, importmap pin, or
schema changed in this delivery), `UNIVERSE=dark|lotr bin/rails db:demo:check` (no `db/data`
manifest changed), and `db:demo:reset`/`db:restart`/Docker/Kamal deployment (destructive, needs
approval).

## Follow-up verification (2026-09-29, universe address uniqueness — quirk 26)

- `bin/rails test` — 1,074 tests, 6,395 assertions, 0 failures, 0 errors, 7 skips.
- `bin/rails test test/models/universe_test.rb test/models/translations_test.rb` — 24 tests,
  195 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test test/controllers/universes_controller_test.rb` — 28 tests, 101 assertions,
  0 failures, 0 errors, 0 skips.
- `bin/rails test test/controllers/workspace_locale_test.rb` — 26 tests, 310 assertions,
  0 failures, 0 errors, 0 skips.
- `PARALLEL_WORKERS=2 bin/rails test:system` — 117 tests, 1,501 assertions, **2 failures, 2 errors**,
  0 skips. All four are pre-existing and in a surface this change does not touch, and they were
  recorded as the stale browser assertions finding in [`known_quirks.md`](known_quirks.md) and
  fixed the same day; see [Former quirk #60](#former-quirk-60-four-browser-assertions-in-the-tag-and-taxonomy-suites-were-stale-fixed)
  and its verification section below.
  (`test/system/tag_improvements_test.rb:16,60` and `test/system/taxonomy_tree_test.rb:22,302`:
  a workspace tab link that deliberately carries `from=workspace`, a taxonomy row that now holds two
  collapsed toggles, and a page-header badge that counts the tag the test itself creates). Both
  files reproduce all four on their own
  (`PARALLEL_WORKERS=2 bin/rails test test/system/tag_improvements_test.rb test/system/taxonomy_tree_test.rb`
  — 17 tests, 185 assertions, 2 failures, 2 errors), and none of them creates, renames, or updates a
  universe. An earlier full run on the same day also reported three further errors that did not
  reappear, which is the load sensitivity known quirk 58 describes.
- `PARALLEL_WORKERS=1 bin/rails test test/system/universe_story_test.rb` — 2 tests, 27 assertions,
  0 failures, 0 errors, 0 skips. The first run failed the pre-existing creation journey on an
  "All stories" navigation that never arrived; the identical run passed on re-run with no change,
  which is the flake recorded as known quirk 58 and the reason a single browser run is not read as
  a verdict.
- `bin/brakeman --no-pager` — 1 weak-confidence SQL-injection warning in
  `app/models/concerns/has_many_tags.rb:109`, a string-interpolated `joins` of table and column
  names taken from the model's own reflections. Pre-existing, and unrelated to this change.
- `bin/rubocop` — 324 files, no offenses.
- `git diff --check` — clean.

Not run: a manual browser pass outside the automated suite (no browser was attached to the
session that made this change), `bin/bundler-audit`, `bin/importmap audit`, and `bun audit` (no
dependency, importmap pin, or vendored asset changed), `bun run check:js` (no client-side code
changed), `UNIVERSE=dark|lotr bin/rails db:demo:check` (no `db/data` manifest changed; the two
registered universes keep distinct addresses), and `db:demo:reset`/`db:restart`/Docker/Kamal
deployment (destructive, needs approval).

## Follow-up verification (2026-09-29, Timeline layering and node accessibility — quirks 24 and 46)

- `bin/rails test` — 1,084 tests, 6,428 assertions, 0 failures, 0 errors, 7 skips.
- `bin/rails test test/models/timeline_layout_test.rb` — 11 tests, 23 assertions, 0 failures,
  0 errors, 0 skips (4 tests before this change).
- `bin/rails test test/controllers/timeline_controller_test.rb` — 4 tests, 14 assertions, 0 failures,
  0 errors, 0 skips.
- `bin/rails test test/controllers/workspace_locale_test.rb` — includes the new Spanish
  `aria-label` assertion; green.
- `bun run check:js` — 137 tests across 8 files, 0 fail, 361 assertions.
  `timeline_controller.js` is unchanged, so its drawn-geometry cases are the same six as before.
- `bun run build:css` — Sass + PostCSS/autoprefixer clean; the built `.timeline-node` rule carries
  the `padding: 0` reset. `app/assets/builds/` is gitignored and was not edited by hand.
- `bin/rubocop` — 325 files, no offenses.
- `bin/brakeman --no-pager` — the one pre-existing weak-confidence SQL-injection warning in
  `app/models/concerns/has_many_tags.rb:109`, a string-interpolated `joins` of the model's own
  reflected table and column names. Unrelated to this change and already recorded above.
- `PARALLEL_WORKERS=1 bin/rails test test/system/timeline_test.rb` — 4 tests, 39 assertions,
  0 failures, 0 errors, 0 skips. Covers keyboard focus landing on the node, the popover opening on
  focus and on click, the node's computed geometry, and the empty timeline.
- `PARALLEL_WORKERS=1 bin/rails test test/system/timeline_test.rb test/system/workspace_navigation_test.rb`
  — 6 tests, 80 assertions, 0 failures, 0 errors, 0 skips.
- `PARALLEL_WORKERS=2 bin/rails test:system` — 120 tests, ~1,550 assertions, 1 failure and 1 error
  across the two runs, and **not the same two each time**: the first run failed
  `scene_locations_test.rb` (a Role field that appended to its existing value instead of replacing
  it), the second failed `scene_elements_test.rb` (a truncated Content field and a missing
  `.entity-row`). Both files are unmodified by this change and neither touches the Timeline; each
  reproduces green in isolation
  (`PARALLEL_WORKERS=1 bin/rails test test/system/scene_elements_test.rb test/system/scene_locations_test.rb`
  — 11 tests, 149 assertions, 0 failures, 0 errors, 0 skips). This is the load sensitivity recorded as
  known quirk 58: the shape is a partially-typed field and a row that never appeared, and the
  affected files move between runs, which is what distinguishes it from a real regression. Do not
  "fix" a test that failed this way — re-run it with fewer workers first.

Not run: `bin/bundler-audit`, `bin/importmap audit`, and `bun audit` (no dependency, importmap pin,
or vendored asset changed), `UNIVERSE=dark|lotr bin/rails db:demo:check` and
`db:demo:reset`/`db:restart` (no `db/data` manifest changed; the reset tasks are destructive and
need approval), Docker/Kamal deployment, and a manual browser pass outside the automated suite. The
pan/zoom interaction was not built, so there was no client-side interaction to verify beyond the
node's own focus/click/geometry coverage.

## Follow-up verification (2026-09-30, deletion confirmations — quirk 59)

- `bin/rails test` — 1,128 tests, 6,876 assertions, 0 failures, 0 errors, 7 skips.
- `bin/rails test test/controllers/characters_controller_test.rb test/controllers/items_controller_test.rb
  test/controllers/locations_controller_test.rb test/controllers/modal_json_contract_test.rb
  test/controllers/universe_bible_locale_test.rb test/models/translations_test.rb` — 78 tests,
  801 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test test/docs_test.rb` plus the five other locale/ADR-adjacent controller suites
  (`sections`, `workspace_locale`, `events`, `universe_bible_locale`, `translations`) — 137 tests,
  1,275 assertions, 0 failures, 0 errors, 0 skips. `translations_test` is the check that matters most
  here: the three new keys exist in both locale files, carry the same `%{name}` interpolation, and
  the Events comment that claimed it was "the one delete confirmation of these six workspaces that
  states its own cascade" is no longer a claim.
- `PARALLEL_WORKERS=2 bin/rails test test/system/modal_json_flow_test.rb` — 8 tests, 107 assertions,
  0 failures, 0 errors, 0 skips. Its two delete journeys now accept whatever confirmation the row
  sends; the confirmation's content is a request-test concern, and the request tests read it.
- `PARALLEL_WORKERS=2 bin/rails test:system` — 121 tests, 1,559 assertions, 0 failures, **1 error**:
  `scene_locations_test.rb:79`, a `.modal.show` that never opened while typing into the Location
  picker. That file is unmodified and does not touch a delete confirmation; it reproduces green on
  its own (`PARALLEL_WORKERS=1 bin/rails test test/system/scene_locations_test.rb` — 6 tests,
  73 assertions, 0 failures, 0 errors, 0 skips), which is the load sensitivity known quirk 58
  describes and the same shape recorded in the Timeline verification above.
- `bun run check:js` — 137 tests across 8 files, 0 fail, 361 assertions. No JavaScript changed:
  `taxonomy_tree_controller.js` reads the same `data-confirm-message` attribute Section and SceneTag
  already read, and the Locations page now populates it.
- `bin/rubocop` — 327 files, no offenses.
- `bin/brakeman --no-pager` — 0 errors and the one pre-existing weak-confidence SQL-injection warning
  in `app/models/concerns/has_many_tags.rb:109`, a string-interpolated `joins` of the model's own
  reflected table and column names. Unrelated to this change and already recorded above.

Not run: `bin/bundler-audit`, `bin/importmap audit`, and `bun audit` (no dependency, importmap pin,
or vendored asset changed), `UNIVERSE=dark|lotr bin/rails db:demo:check`,
`db:demo:reset`/`db:restart`, Docker/Kamal deployment (no `db/data` manifest or schema changed; the
reset tasks are destructive and need approval), and a manual browser pass outside the automated suite.
The three changed confirmations were not observed in a hand-driven browser: the copy is server-rendered
into an attribute and every suite that reads it asserts the rendered value, so a browser could only
show the modal controller passing that attribute to `window.confirm`, which
`test/system/modal_json_flow_test.rb` already exercises for a Character row.
