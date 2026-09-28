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
remain open under backlog item 18. No destructive database, container, deployment, or browser
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

## Follow-up verification (2026-09-25, Scene core slice 11.1)

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
changed in this slice), `db:demo:reset`/`db:demo:load` (destructive, needs approval), a browser
manual pass against loaded development data, Docker/Kamal deployment, and any production SMTP or
proxy verification.

## Follow-up verification (2026-09-25, Scene references and grouping slices 11.2/11.3)

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

## Follow-up verification (2026-09-25, Scene Tag slice 11.4)

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
recorded in the 11.2/11.3 verification section.

## Follow-up verification (2026-09-25, Dark story-name test fix)

- `bin/rails test` — 440 tests, 2,552 assertions, 0 failures, 0 errors, 0 skips. This clears the
  standing failure recorded in the 11.2/11.3 and 11.4 verification sections above. The assertion
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

## Follow-up verification (2026-09-26, shared modal JSON reliability — slice 11.5)

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
or vendored asset changed in this slice), `db:demo:reset`/`db:demo:load` (destructive, needs
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
