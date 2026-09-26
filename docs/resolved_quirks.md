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
