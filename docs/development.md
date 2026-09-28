# Development Guide

Commands, tests, seeding, CI, deployment and a "adding a new model" checklist.
Conventions: [universe_maker_conventions.md](universe_maker_conventions.md) ·
Schema: [data_model.md](data_model.md) · Gotchas: [known_quirks.md](known_quirks.md).

## Prerequisites & running

- Ruby **3.4.10** via [mise](https://mise.jdx.dev) (`mise.toml`); `bundle install`.
- **Google Chrome** (or a compatible browser) for `bin/rails test:system`.
- **Bun** for CSS/JS assets: `bun install`; `bun.lock` is the committed source of truth. Use
  `bun install --frozen-lockfile` in CI and other reproducible environments.
- **Meilisearch**, only if you want search to return anything. Everything else works without it; the
  box says it is unavailable. `bin/dev` starts the engine once it is installed — see **Search
  engine** below.
- Setup & run:

```bash
bin/rails db:prepare          # create + migrate + production-safe seeds only
UNIVERSE=dark bin/rails db:demo:load  # optional development data (development only)
bin/dev                       # web + CSS watcher + Meilisearch, all with logs in one terminal
bin/rails server              # http://localhost:3000, on its own, without the other two
bin/rails console
bun run watch:css             # rebuild CSS on .scss changes (Procfile.dev: foreman start)
```

`bin/dev` is the one to reach for. It runs `web`, `css`, and `meilisearch` together, prefixes each
line with its process name, and stops all three on `Ctrl-C`. Running `bin/rails server` on its own
still works, but that path gets no CSS watcher and no engine, so a `.scss` change appears to do
nothing and search reports itself unavailable until you start them.

- CSS pipeline: `app/assets/stylesheets/application.bootstrap.scss` → sass → postcss/autoprefixer
  → `app/assets/builds/application.css`. Development keeps Propshaft on a dynamic manifest under
  `tmp/assets`, so `bun run watch:css` is immediately visible and a stale `public/assets` manifest
  cannot shadow local changes. The build also runs automatically before the test suite, so tests
  require `node_modules` + bun. Use `RAILS_ENV=production bin/rails assets:precompile` when
  checking the production asset manifest; do not run a development precompile as the local CSS
  workflow.
- Sass modules: the pinned compiler no longer resolves the global built-in module namespaces
  (`color`, `math`, …), so a call like `color.mix` needs an explicit `@use "sass:color";` in the file
  that makes it — as the first rule, because `@use` cannot follow a style rule. The deprecated
  global built-ins (`mix`, `darken`, `lighten`, `transparentize`, …) still work but warn on every
  build, and the compile step only silences the `@import` deprecation.

## Test suite (Minitest)

```bash
bin/rails test                # models, controllers, helpers (runs in parallel, all fixtures)
bin/rails test test/models/section_test.rb
bin/rails test:system         # browser-based system tests
```

Layout:
- `test/controllers`, `test/models`, and `test/integration` — model, request, navigation, and
  workspace coverage; `test/services` — development-data registry/loader coverage; `test/system` —
  browser-level smoke coverage for the primary workspace journeys; `test/helpers` and
  `test/mailers/previews` are effectively empty.
- `test/fixtures/*.yml` — loaded for **all** tests (`fixtures :all`): users, universes,
  **stories** (`story_one`, `story_alt` in universe one, `story_two` in universe two), sections
  (both belong to `story_one`), scenes (three in `story_one`, one in `story_alt`), scene elements and
  scene characters (both belong to `story_one`'s first Scene), all content +
  tag fixtures.
- Sign in with `sign_in_as(users(:user_one))` /
  `sign_out` from `test/test_helpers/session_test_helper.rb`.
- Route helpers in tests must be fully qualified:
  `universe_story_sections_url(universe_slug: @universe.slug, story_id: @story)`.
- `test/routing/universe_route_helper_arguments_test.rb` parses Ruby and ERB call sites and fails
  if an application or test call uses positional arguments with a universe-scoped route helper.
- `RecordNotFound` renders **404** in tests (`show_exceptions = :rescuable`): use
  `assert_response :not_found` to assert cross-scope/unknown-id rejections.
- Unauthenticated access: public universe content is intentionally readable without a session;
  mutations redirect (302) to `/session/new`. Signing in returns the reader to the page they were on,
  whether they opened the sign-in page directly or were redirected from a protected action; only a
  same-host referer is remembered, and an external site cannot choose the destination. Universe-scoped
  controllers allow unauthenticated access only for read actions; the shared authorization callback
  enforces the universe policy.
- Universe authorization tests must cover both public and private universes. Create explicit
  `UniverseMembership` records for read/write/admin cases; do not rely on a public fixture to stand
  in for a private collaboration scenario. Private non-members—including guests—receive 404;
  members with insufficient access receive 403. Public-universe guest mutations still redirect to
  sign-in.
- Authentication tests must verify that remembered stories survive ordinary navigation but are
  cleared on sign-out, when a new account session starts, after current-user password reset, and
  when a stale authentication session is encountered.
- CSRF: the request suite runs with `allow_forgery_protection = false`, so a passing request test
  does **not** mean a token was verified. `test/controllers/csrf_mutation_test.rb` and
  `test/system/csrf_token_test.rb` wrap their own window in `with_forgery_protection` to prove that
  the page's token is accepted, that a missing or forged token is refused with `403` and writes
  nothing, and that both `fetch` implementations really send it. Put a new mutation path in one of
  those two files rather than assuming the fast suite covers it.
- `ApplicationSystemTestCase#visit` waits for the `stimulus-loading` readiness signal after every
  navigation. A native click delivered before Stimulus and Turbo have connected is silently dropped
  on some machines, so a case that forgot the wait failed for a reason that had nothing to do with the
  flow under test. The wait lives in the base class, so a new case does not have to remember it.

## Client-side tests and lint (Bun + Biome)

```bash
bun run lint:js        # Biome, recommended rules, over app/javascript and test/javascript
bun run test:js        # Bun's built-in test runner
bun run check:js       # both
bun test test/javascript/modal_form_controller_test.js   # one file
```

The Stimulus controllers carry the security-sensitive client-side code, so they are unit tested
without booting Rails or a browser:

- `test/javascript/setup.js` registers a DOM (happy-dom) and stubs the two specifiers the
  application serves from the import map rather than `node_modules` (`@hotwired/stimulus`,
  `bootstrap`). Only the base class is needed to instantiate a controller, and no unit test opens a
  dialog. `bunfig.toml` preloads it.
- Cases build a small host element and assign the Stimulus targets the method under test reads
  (`formTarget`, `errorsTarget`, `submitTargets`, `element`, `modalFieldsValue`, …).
- happy-dom's `FormData` does not repeat a multi-select's selected options the way a browser's
  does, so those cases stub `FormData` with the real browser contract instead of asserting against
  the emulation.
- `test/javascript/no_html_sink_test.js` is a gate, not a behavior test: it fails when a new
  `innerHTML`/`outerHTML`/`insertAdjacentHTML`/`document.write` sink appears in `app/javascript`
  without a reviewed exception.
- Biome lints but does not format. The controllers are hand-formatted to the existing house style;
  reformatting them is a separate, deliberate change. `biome.json` limits the check to
  `app/javascript` and `test/javascript`, so vendored assets are never touched.

CI runs `bun run lint:js` and `bun run test:js` in the `js-check` job. The browser suite still owns
what only a browser can show: focus, Turbo navigation, and a real CSRF token on the wire.

## Lint & security scans

```bash
bin/rubocop                  # rubocop-rails-omakase house style
bun run lint:js              # Biome over the Stimulus controllers and their unit tests
bin/brakeman --no-pager      # static security analysis
bin/bundler-audit            # vulnerable gems
bin/importmap audit          # vulnerable JS pins
```

For a locally vendored npm asset, keep a same-line version comment on its importmap pin, for
example `pin "tom-select", to: "tom-select.js" # @2.6.2`. Importmap Audit reads this metadata
from `config/importmap.rb`; it does not infer a version from a version banner inside the
JavaScript file. Keep the comment, `bun.lock`, and the vendored asset synchronized when updating
Tom Select.

## Repository quality and DataFactor follow-up

The 2026-09-25 DataFactor report is a point-in-time snapshot, not a release gate or a reason to
add ceremonial dependencies or Git history. Its actionable recommendations are distilled in
[`data_factor_guidance.md`](data_factor_guidance.md); deferred work is tracked in
[`backlog.md`](backlog.md) and verified gaps are recorded in [`known_quirks.md`](known_quirks.md).
Verify each recommendation against the current tree before acting. In particular, `/up` is already
routed and `bun.lock` is already committed and used with `--frozen-lockfile` in CI and Docker.

The current CI baseline runs RuboCop, Brakeman, Bundler Audit, Importmap Audit, Minitest, checked-in
development-data manifest checks, and a browser smoke suite. It does **not** yet measure coverage, audit the complete Bun/npm graph or
build/boot the production image, provide a one-command Compose setup, or enable structured
request/error tracking. Those are follow-up work, not current capabilities; do not claim them in
release or onboarding copy until they are implemented and documented.

When planning one of those improvements, preserve the development-only data boundary, the
universe/story authorization model, and the no-secrets rules. A value-free `.env.example` may be
committed only after an explicit `.gitignore` exception; real `.env` files, credentials, DSNs, and
deployment keys remain local/secret. Do not use a hardcoded demo password as a fallback, and do not
let a production container run the development data path.

## Seeding / development data

`db/data/` contains checked-in but **disposable development data**. It is not production seed data,
and it is not a fixture source for the Rails test suite; focused service tests validate and
transactionally exercise it. The YAML files are the source of truth for the local demo database, but
Rails does not watch or synchronize them. After **every** add/delete/update under `db/data/**/*.yml`,
validate the changed universe and rebuild the local development database before checking the result
in the app.

### Required workflow after editing demo YAML

Run the read-only check for every changed universe first:

```bash
UNIVERSE=dark bin/rails db:demo:check
UNIVERSE=lotr bin/rails db:demo:check
```

Then reset the disposable database so the change is actually applied. The reset drops the entire
development database, migrates the schema, and loads the named universe:

```bash
CONFIRM_DB_RESET=1 UNIVERSE=dark bin/rails db:demo:reset
```

If both current sample universes should remain available locally, create-only load the other one
after the reset:

```bash
UNIVERSE=lotr bin/rails db:demo:load
```

The reset target may be either registered universe. `db:demo:load` refuses a universe that already
exists; the loader has no update, merge, or UI-export mode. Consequently, a record added or changed
only in the UI is intentionally discarded by a later reset. The project owner accepts that loss for
this disposable local database. Never use these commands on production or any other real database,
and verify the rebuilt database (for example with a scoped Rails query) before reporting demo data as
available in the app.

### One directory per universe

There is one subdirectory per universe, named by its slug:

```text
db/data/
  dark/       # the more complete Dark dataset
  lotr/       # the smaller Lord of the Rings dataset
  star_wars/  # future universe data
```

Each directory contains all data used to exercise that universe: its user/universe record, stories,
sections, section tags, world-building records, taxonomies, and relationships. A universe
directory is not a feature directory. For example, a future `Dialog` model belongs in
`db/data/dark/dialogs.yml` (and in `db/data/lotr/dialogs.yml` when that universe should exercise
it), not in `db/data/dialog/`.

The shared development loader is `Development::UniverseDataLoader`, configured by
`app/services/development/universe_data_registry.rb`. It walks one registry order for every
universe (User → Universe → UniverseMembership → Story → SectionTag → Section → … → Event),
requires every registered YAML file, resolves `Model.slug` references in memory, validates model
order and universe/story scope before writing, and normalizes hierarchical sibling positions from
file order (or validates explicit positions when every sibling supplies one). The Dark and LOTR
directories now use the same format; the old per-universe Ruby loaders have been removed.

New model data must use stable symbolic references and preserve the model's universe/story scope.
If `Dialog` is story-scoped, its records use `story: Story.<slug>`; if it is universe-scoped, they
use `universe: Universe.<slug>`. Include related characters, locations, items, events, sections,
and tags where those associations exist so the browser scenario exercises the real feature graph.
Add the model to the shared registry and provide its file in every registered universe directory,
using `[]` where the model is intentionally not exercised.

### Explicit development data tasks

`db:demo:check` is read-only and may run in development or test. `db:demo:load` and
`db:demo:reset` are write-capable tasks restricted to development:

```bash
UNIVERSE=dark bin/rails db:demo:check
UNIVERSE=dark bin/rails db:demo:load
CONFIRM_DB_RESET=1 UNIVERSE=dark bin/rails db:demo:reset
```

`db:demo:load` is create-only and refuses an existing target universe. `db:demo:reset` requires
`CONFIRM_DB_RESET=1`, drops/recreates/migrates the database, and loads only the named universe;
it never invokes `db:seed`. `db:seed` and `db:prepare` load only production-safe files under
`db/seeds/` and never load `db/data/`. The guarded `db:restart` task resets the schema without
loading demo data.

The Rails test suite uses `test/fixtures/` so automated tests remain deterministic; these mutable
universe files are not its fixture source. `config/ci.rb` validates the checked-in manifests in
test mode instead of replanting demo records.

## Scene delivery (complete: slices 11.1–11.10)

[ADR 0007](adr/0007-story-owned-scenes-and-elements.md) defines the Scene contract, and the epic is
now delivered. Slices 11.1–11.4 have landed the core (`scenes` migration,
`Scene` model, story-scoped routes/controller, canonical list, narrative-order moves, Scene Details
page and its editor form, the real sidebar link with its own cached count), the optional
Section/Event/datetime references with their validation and the URL-backed tab shell, the Section
grouping workspace, and the story-scoped Scene Tag taxonomy/assignment. Slice 11.5 made the shared
modal JSON path reliable. Slices 11.6 and 11.7 landed `scene_elements` with its Dialogue speaker
link, `scene_characters`, the ordered Element list and its modal on Scene Details, and the Characters
tab. Slices 11.8 and 11.9 landed `scene_items` and `scene_locations` with the Items and plural
Locations tabs, so all four workspace tabs are live. Slice 11.10 landed `SceneAppearances` and the
reverse **Appears in scenes** section on the Character, Item, Location, and Event details pages.
The confirmed first-version defaults are: Scene `name` labelled **Title**; Element
`name` required and plain-text `body` optional; Dialogue requires at least one speaker; Narration
has none; Scene uses one optional single-point `datetime` with the current Event storage/editor
precision and timezone semantics, not Event's start/end pair; roles remain nullable; and the ADR's
detailed deletion confirmations are mandatory.

The slice-by-slice record is in [`backlog.md`](backlog.md) and, for the delivered state, in
[`../CHANGELOG.md`](../CHANGELOG.md):

- 11.1 (done) adds the core Scene migration/model, canonical list, ordering controls, editor shell,
  tests, and connected development data.
- 11.2 and 11.3 (done) add the Section/Event/datetime references, the URL-backed tab shell, and the
  Section grouping workspace.
- 11.4 (done) adds the story-scoped Scene Tag schema/model, hierarchical Story Tags workspace,
  optional Scene Details assignment, badges, fixtures, and development data.
- 11.5 (done) makes the shared modal submit JSON, render a `422` in the modal, report a request that
  never lands, and remove a row with its counts, with request and browser regressions for Characters,
  Items, and Events. See [ADR 0011](adr/0011-modal-json-mutation-contract.md).
- 11.6 (done) adds the `scene_elements` schema/model with its flat position, the many-to-many
  Dialogue speaker link, the JSON-only Element controller with `move`, the Element list and modal on
  Scene Details, and the shared modal controller's JSON move action.
- 11.7 (done) adds the `scene_characters` join model, the Characters tab, the derived participant
  view, and the Scenes list's Element and participant counts.
- 11.8 (done) adds the `scene_items` join model and the Items tab.
- 11.9 (done) adds the `scene_locations` join model, the plural Locations tab, and `LocationPaths`.
- 11.10 (done) adds `SceneAppearances`, the reverse section on four record pages, and the
  analyzer-oriented query tests for shared Events and narrative order.

Every slice preserved public/private read-write-admin behavior and updated all model registries,
authorization resolvers, route-helper guards, fixtures, tests, documentation, and changelog.

The new tables shipped as their own create migrations (`CreateSceneElements`, which also creates the
`scene_element_speakers` join, `CreateSceneCharacters`, `CreateSceneItems`, and
`CreateSceneLocations`). See below for why that matters here.

### Amending a shipped migration does not work here

`scenes` already shipped its create migration in slice 11.1, so 11.2/11.3 added the references with
a separate schema-only alter migration (`AddSceneReferencesToScenes`). This is not just tidiness.
Rails 8.1's `ActiveRecord::Tasks::DatabaseTasks.initialize_database` loads `db/schema.rb` when a
database has no `schema_migrations` table, so on a **freshly created** database `db:migrate`,
`db:restart`, and `db:demo:reset` load the checked-in schema instead of executing the migration
files. Editing an applied migration therefore changes nothing on a fresh database, the regenerated
`db/schema.rb` silently keeps the old shape, and the mismatch is only visible when a manifest or a
form references a column that does not exist. Add a new migration for any change to a table that has
already shipped.

### Scene data and manual verification

When data is added, put it in the relevant `db/data/<universe_slug>/` files (`scenes.yml`,
`scene_tags.yml`, `scene_elements.yml`, `scene_characters.yml`, `scene_items.yml`, and
`scene_locations.yml`), not in a
feature directory. Records must use stable symbolic references and demonstrate title-only,
Ungrouped, Section-assigned, independent Event/datetime, shared-Event, tagged/untagged Scene,
Narration, Dialogue, multi-speaker, multi-Location, multi-Item, and blank/populated-role cases at
Epic completion. `scenes.yml` records already reference their story, may now reference `section:`,
`event:`, and `scene_tags:` with `Model.slug` references and an independent `datetime:`, and use
explicit `position` values so the narrative order is visible in the file. The Dark file is the worked
example: three scenes share Season 1 / Episode 1, three scenes are ungrouped (one of them told last
but set in 1953), and each remaining Section keeps a single scene. `SceneTag` is loaded before
`Scene`, and `Scene` is loaded **after** `Event` in `Development::UniverseDataRegistry` because a
symbolic reference may not point at a later model file. The loader proves the Section and every
assigned Scene Tag belong to the Scene's story before writing anything.

`scene_elements.yml`, `scene_characters.yml`, `scene_items.yml`, and `scene_locations.yml` are
**scene-scoped** registry entries: every record
declares its `scene:` with a `Scene.slug` reference, the loader resolves its Universe through that
Scene, and Element `position` values are flat and contiguous **inside their own Scene**. A Dialogue
names its speakers with `characters: [ Character.slug, ... ]`, the same join the app uses. A
`SceneCharacter` declares `character:`, a `SceneItem` declares `item:`, and a `SceneLocation` declares
`location:` — each with an optional `role:`; leave `role:` empty to record the appearance without
one. The Dark manifests deliberately include a Scene with no elements at all, a
Dialogue whose speakers are not stored participants, a one-speaker dialogue, a three-speaker
dialogue, two title-only Element blocks, a populated role and blank roles, the same Item in two
Scenes, two Items in one Scene, one Scene with three linked Locations, a nested Location beside a
top-level one, and Scenes with no Item or Location at all so each tab's empty state is reachable.
The loader's own log names a join record by the records it joins
(`Created SceneItem: scene.secrets -> item.jonas-key`) rather than printing `record`, so a load can
be verified by reading it.

For an already prepared but empty development database, use the explicit
`UNIVERSE=<slug> bin/rails db:demo:load` task. After changing any `scenes.yml`, follow the required
check-and-reset workflow above instead: `load` is create-only and will not update the existing
Dark/LOTR universe. The loader refuses production/test writes and does not load another universe.

Manual verification for the shipped slices:

```bash
CONFIRM_DB_RESET=1 UNIVERSE=dark bin/rails db:demo:reset   # drops/reloads local demo data
UNIVERSE=lotr bin/rails db:demo:load                       # optional second universe
bin/rails server
```

Log in with the documented Dark development user, open `/u/dark/s/<story_id>/scenes`, and check:
the sidebar **Scenes** entry links to the selected story and shows the scene count; the list is in
narrative order with position pills; each row shows its nested Section path or **Ungrouped**; Move
up/Move down reorder the sequence and are disabled at the boundaries; the delete confirmation
states the full ADR 0007 consequences; and a guest or read-only member sees the list and details
with no mutation controls. The Dark data has several Scenes in Season 1 / Episode 1, several
ungrouped Scenes, and one Scene per remaining Section, so grouping and narrative order are visibly
different things.

On the same page check the **Find scenes** area: it narrows the list by title/description text, by
Section (including **Ungrouped**), by Scene Tag, and by an inclusive in-world date range; the active
filters stay in the URL and **Clear filters** restores the full list; a narrowed row still shows its
real narrative position and story total, and Move up/Move down stay enabled whenever the scene
really has a neighbour; a filter that matches nothing says **No scenes match these filters** and is
never confused with a story without scenes; a filter value that no longer exists (another story's
section, an unreadable date) is reported instead of quietly emptying the list; and reordering or
deleting inside a narrowed list returns to the same filter.

The universe page, the top bar, the sidebar's scoped blocks, and the record details pages can be
checked the same way: the top bar shows only the **Universe Maker** brand, **Universe: …**, and
**Story: …** as plain links (no universe or story dropdown), and the brand lands on the universes
list where **New universe** lives; the universe page lists the universe's stories with an **Open**
action and keeps **New story** and **All stories** in the header, so it is where stories are switched
and created; the left sidebar reads current universe → Universe Bible → current story →
Story workspace with one hue per scope, and the right utility sidebar reads its green **Universe
tools** context block → Configuration → Collaboration → Analytics → AI, with **Tags** (and, for an
admin, **Members**) in Configuration; every list row — the left sidebar's Universe Bible lists aside,
the left column's Sections, and every `_tag` row — shows a plain name with its tags and a count
pill on the left that names what it counts ("(4 characters)") and an always-visible **Details** link
plus an always-visible `[…]` menu on the
right, and following Details lands on the record's own read-only page (a tag lists
the records carrying it, a Section lists the scenes grouped under it). Placeholder navigation in the
right utility sidebar stays flat gray with no hover emphasis, and a guest or read-only member sees
the same pages with no mutation controls.

Open **Settings** from the top bar's account menu (it is rendered for a guest too, and it is not a
Configuration link in the right sidebar) and check: the page has no workspace shell, its vertical navigation shows
**Appearance** as the only section, and the **Theme** control offers exactly **Light** and **Dark** as
labelled cards with the current one selected. Choosing **Dark** and pressing **Save theme** repaints
the page immediately with no flash of the light palette, the choice is still selected when you come
back, and it still applies after navigating to a universe page and to the landing page — it is
remembered in this browser, so a signed-out visitor has it too. Switching back to **Light** restores
the original palette. In dark mode the universe, story, and tools sidebar blocks keep their own hue,
surfaces are dark rather than near-white, and tag badges keep the colors stored on the record. See
[ADR 0013](adr/0013-platform-settings-and-browser-theme.md).

Open a Scene and check: the **Scene Details** tab is active while **Characters** is a live link and
**Items** and **Locations** are `aria-disabled` placeholders rather than dead links; Details shows
the Section
group, Scene Tag badges, the linked event, and the in-world time as separate labelled values; and
the editor's **Scene tags**, **Organization**, and **In-world time** fieldsets let you assign or
clear optional tags, set a Section, set an Event, and set a `datetime-local` value without the
narrative position changing. On the Scenes list, the row's title is plain text and the **Details**
link is the way into that page. Each row also shows an Element count and a Characters-taking-part
count; the second is the union of stored participants and dialogue speakers, so a character who
both participates and speaks is counted once.

Below the Scene's facts, check the **Scene elements** list: the ordered blocks are in this Scene's
own sequence, each with its position, kind, content (or an explicit "No content yet"), and — for a
dialogue — its speakers plus the sentence saying the link records who is in the conversation and not
which line belongs to whom. **Add element** opens the modal; a narration saves with only a title; a
dialogue reveals the speaker picker and refuses to save without a speaker, keeping the modal open
and rendering the server's own message on the Speakers control. Switching a dialogue that has
speakers to narration reveals the **Remove the speakers and make this narration** confirmation and
only then saves. Move up/Move down reorder the blocks and are disabled at the boundaries; the delete
confirmation says the content and speaker links go but characters do not.

Then follow the **Characters** tab and check: the rows are one per character in the union of the two
participation sources; a stored participant is badged **Participant** and shows its role or **No role
recorded**; a character who only speaks is badged **Speaks in N element(s)**, names the elements, and
offers no edit or remove menu; a character who is both carries both badges on one row. **Add
character** adds a link with an optional role, **Edit role** changes it, and **Remove** takes the
link away without removing the character or changing who speaks. Choosing a character that is already
in the scene is reported in the modal instead of creating a second row. A guest or read-only member
sees the same list with no controls.

Open **Configuration → Tags → Story Tags → Scene tags** and check: the story-scoped Scene Tag
hierarchy can be created, renamed, colored, nested, moved, inserted, and deleted with the shared
keyboard/touch controls; a public guest or read-only member sees the tree without mutation controls;
and the same tags appear as optional badges on the Scenes list and Details page.

### Menu tags and grouping tags

After loading the Dark demo universe, open **Characters** and check that the workspace tabs include
**Characters**, **Relations**, **Factions**, and **Family Nielsen**. Opening **Factions** from that
tab keeps the workspace tabs visible and shows characters grouped under **Sic Mundus** and
**Erit Lux**, without an include-descendants checkbox. Opening **Family Nielsen** from its tab also
keeps the tabs and retains the ordinary flat record list and checkbox. Open the same Family Nielsen
tag through **Configuration → Tags → Character tags → Details** and confirm the workspace tabs are
absent. The taxonomy Details URL does not infer navigation from the browser Referer.

After changing the Dark YAML, validate and rebuild the local development data with:

```bash
UNIVERSE=dark bin/rails db:demo:check
CONFIRM_DB_RESET=1 UNIVERSE=dark bin/rails db:demo:reset
```

Open `/u/dark/s/<story_id>/sections` and check: the Section tree is still there and each row's count
pill names what it counts ("(3 scenes)"); **Ungrouped scenes**
lists only the scenes that belong to no Section under a badge that says how many that is
("2 ungrouped scenes"), says how many are grouped, and leaves a grouped
scene to its own Section page (follow the row's **Details** link and the three scenes of Episode 1 are
listed there in narrative order); the **Ungrouped scene** → group selector offers only the ungrouped
scenes of that list and moves one into a Section, while the flash states that
the narrative position did not change; a grouped scene is put back to Ungrouped from the scene
editor's Section selector; and the Section delete confirmation says that linked scenes
become ungrouped without their narrative order changing.

## Taxonomy editor and ordering verification

Taxonomy mutations remain JSON-only. The shared tree builds dynamic fields and nodes through DOM
APIs, treats names/descriptions as text, and refreshes the same URL after every successful mutation
so parent/tag options and counts are server-authoritative. Section and Location editors include
scoped parent selectors; Move up/Move down and Insert before/Insert after provide non-drag paths.
Run `test/system/taxonomy_tree_test.rb` for hostile-name, stale-state, boundary insertion,
keyboard, and narrow/touch regressions. Do not reintroduce hover-only controls or `innerHTML` for
user-controlled values.

Positioned controller mutations use `PositionedResourceOrder` and ADR 0009. Run
`test/services/positioned_resource_order_test.rb` plus the positioned controller tests after
changing ordering behavior. The service supports explicit flat mode, which the Story-owned Scene
sequence now uses with `@story` as scope owner; the same flat mode is reserved for Scene Elements.
`MaintainsSiblingPositions#position_parent_id_for` omits the ordering parent in flat mode, so a flat
record does not need a `parent_id` column. It does not make `section_id` an ordering parent.

## Database migrations

The database is intentionally disposable: schema migrations only define the structure. Demo
records are reconstructed from the per-universe files under `db/data/`; they are not backfilled by
migrations. Keep one schema-only create migration per persisted model, including any HABTM join
table owned by that model. Once that create migration has shipped, add **new** migrations for later
column changes: Rails 8.1's `initialize_database` loads `db/schema.rb` when a database has no
`schema_migrations` table, so editing an applied migration has no effect on a freshly created
database (see [Amending a shipped migration does not work here](#amending-a-shipped-migration-does-not-work-here)).
Migrations must not read or write application records or reference
application models. The `universes.private` NOT NULL migration deliberately refuses to guess how
legacy NULL rows should be classified; resolve each such row explicitly before migrating an older
database. The Event self-reference check-constraint migration likewise fails rather than deleting
or rewriting an existing corrupt loop. After changing a schema, use
`CONFIRM_DB_RESET=1 UNIVERSE=<slug> bin/rails db:demo:reset` with approval when the disposable
universe should be rebuilt and reloaded. The guarded `db:restart` task resets schema only.

## Smoke test (end-to-end over HTTP)

`docs/smoke_test_stories.sh` — logs in over curl (CSRF token + signed cookie), then checks the
Stories index, creates a story, and opens its sections:

```bash
# with a server on :3000 (defaults BASE=http://localhost:3000 EMAIL=lotr@lotr PASSWORD=lotr)
bash docs/smoke_test_stories.sh
```

It was moved from `/tmp/opencode/` into `docs/` so it is tracked by git. Note: it creates a real
story in the development DB and deletes it again at the end.

## Search engine

The top-bar search answers from **Meilisearch**. It is optional: with no engine configured, the rest
of the application works normally and the box states that search is unavailable — it never falls back
to SQL, because two ranking behaviours behind one question is worse than one honest answer.
[ADR 0014](adr/0014-global-search-with-meilisearch.md) records the decision.

Run a local engine (a single binary, no cluster). `bin/dev` starts it for you — see **The engine under
`bin/dev`** below for the one-time setup and for running it by hand.

```bash
docker run --rm -p 7700:7700 \
  -e MEILI_MASTER_KEY=local_development_key \
  -e MEILI_NO_ANALYTICS=true \
  getmeili/meilisearch:v1.54
```

Without Docker — a host that will not run a container, or will not let you install one — the same
pinned version is a static binary that needs no privileges. `sudo` is required for rootful Docker, and
rootless Docker, Podman, and rootlesskit all need unprivileged user namespaces, which a locked-down
host denies (`unshare: write failed /proc/self/uid_map`); check that before choosing the binary route:

```bash
curl -sSL -o ~/.local/bin/meilisearch \
  https://github.com/meilisearch/meilisearch/releases/download/v1.54.0/meilisearch-linux-amd64
chmod +x ~/.local/bin/meilisearch
meilisearch --version   # 1.54.0
```

That release publishes no checksum file, so verify the version (`meilisearch --version`) rather
than a hash. The container and the binary are the same engine on the same port with the same key.
Install the binary somewhere on your `PATH` — `~/.local/bin` is the usual choice — because
`Procfile.dev` names the bare command `meilisearch` and nothing else. That is deliberate: a tracked
file must not carry one machine's absolute path, and this way the Procfile reads correctly for a
Homebrew install, a `cargo` install, or a hand-placed binary equally. Nothing here lives in `/tmp`,
which is cleared on reboot and would take the engine with it.

Then point the application at it and build the index:

```bash
export MEILISEARCH_URL=http://127.0.0.1:7700
export MEILISEARCH_API_KEY=local_development_key
bin/rails search:reindex     # required once per engine: creates the index, applies its settings, writes every document
bin/rails search:status      # URL, key presence, index name, health, index presence, document count
```

### The engine under `bin/dev`

`Procfile.dev` has a third process, so `bin/dev` supervises the engine alongside `web` and `css`:

```
meilisearch: meilisearch --http-addr 127.0.0.1:7700 --db-path tmp/meili-data --master-key local_development_key --no-analytics
```

The engine used to be a separate, manually launched background process, which meant three recurring
problems: a stale engine outliving the session that started it, an engine silently missing after a
reboot, and two engines fighting over port 7700. Under foreman it starts, logs, and stops with
everything else, and `Ctrl-C` leaves nothing behind.

- The **data path is `tmp/meili-data`**, relative to the repository root, so the index lives with the
  project and stays out of git (`.gitignore` covers `/tmp/*`). It is derived data: deleting it is
  safe, and the next `search:reindex` rebuilds it. `bin/rails tmp:clear` does delete it.
- The `--master-key` on that line is the same local-only value the `web` line passes as
  `MEILISEARCH_API_KEY`, so the two cannot drift apart. It is never a deployed credential, and a real
  key does not belong in a tracked file.
- `web` and `meilisearch` start concurrently, so a request in the first moments of a session can
  reach the app before the engine is listening and get the honest "Search is not available" state.
  Nothing breaks and nothing falls back to SQL; retry once the `meilisearch.1` line says
  `Server listening on`.
- Running the engine by hand is still fine when you are not using `bin/dev` — run the command above
  in its own terminal. Do not run both: the second one to bind port 7700 exits immediately.

`Procfile.dev` already sets both variables on its `web` line, so `bin/dev` needs no `export` first.
There is no `.env` loader here — `bin/dev` runs foreman with `--env /dev/null` — so a variable
exported in one shell is invisible to a `bin/dev` session, and a bare `bin/rails server` sees neither
the Procfile nor your shell. Run the same command the Procfile specifies, or export the variables
yourself. The key in `Procfile.dev` is the same local-only value used above; it is never a deployed
credential, and a real key does not belong in a tracked file.

| Variable | Required | Purpose |
|---|---|---|
| `MEILISEARCH_URL` | for search at all | Engine base URL. Unset means search is unavailable. |
| `MEILISEARCH_API_KEY` | for writing | Any key allowed to search **and** index. A read-only key serves the application; `search:reindex` then refuses and says so. |
| `MEILISEARCH_INDEX_PREFIX` | no | Index name prefix, default `universe_maker`. The environment is appended, so development, test, and production never share an index. |

The index is **derived data**, rebuilt from the database, and it must be rebuilt after a fresh engine
starts, after restoring a database, and after any period in which the application could not reach
the engine. Indexing itself is queued (`Search::IndexRecordJob`), so a save never waits on it:

- `bin/rails search:reindex` — full rebuild. Reports what it wrote, and fails loudly if the engine
  refused anything.
- `bin/rails search:reindex_universe[<slug>]` — one universe, which is the repair after a universe
  rename (every document under it stores that universe's slug in its path).
- `bin/rails search:status` — whether the engine is reachable, whether the index exists, and how many
  documents it holds. This is the first thing to run when search returns nothing.

Never commit a key or a real `.env` file; `.env*` is already ignored. A value-free `.env.example` is
a documented template, not yet added — see the credential-hygiene item in
[`backlog.md`](backlog.md).

Verifying the engine itself, which the default suite deliberately does not do:

```bash
SEARCH_INTEGRATION=1 MEILISEARCH_URL=... MEILISEARCH_API_KEY=... bin/rails test test/search
```

`test/search/meilisearch_integration_test.rb` is skipped without `SEARCH_INTEGRATION=1`. It is the
only coverage of the engine's own contract — that it accepts our document ids, that our settings are
appliable, that a filter works once they are — and every one of those was found to be wrong at least
once while this was built.

## CI (`.github/workflows/ci.yml`, runs on PR + push to main)

The test jobs install the pinned Bun version and run `bun install --frozen-lockfile` before
starting Rails, so CSS builds use the same dependency graph as local development.

| Job | Command |
|---|---|
| `scan_ruby` | `bin/brakeman --no-pager`, `bin/bundler-audit` |
| `scan_js` | `bin/importmap audit` |
| `lint` | `bin/rubocop -f github` (cached) |
| `js-check` | `bun run lint:js`, `bun run test:js` |
| `test` | `bin/rails db:test:prepare test` |
| `data-check` | `UNIVERSE=dark bin/rails db:demo:check` and `UNIVERSE=lotr bin/rails db:demo:check` |
| `system-test` | `bin/rails db:test:prepare test:system` (browser-based smoke tests; uploads screenshots on failure) |

The system-test job passes the exact Chrome and ChromeDriver paths emitted by
`browser-actions/setup-chrome` to Selenium as `SE_CHROME_PATH` and `SE_CHROMEDRIVER`. Do not rely
only on `google-chrome` or `chromedriver` from `PATH`: GitHub-hosted Ubuntu images can contain a
different preinstalled Chrome than the version installed by the setup action. The CI job also
sets `SE_CHROME_NO_SANDBOX=1`, which makes the system-test driver add `--no-sandbox` because
Ubuntu 24.04+ AppArmor policy can prevent the setup action's Chrome for Testing binary from creating
an unprivileged user namespace. This option is limited to the explicitly configured CI browser;
local system tests keep Chrome's normal sandbox behavior. The workflow also performs a headless
launch smoke check so a browser startup failure is reported during setup rather than only as a
Selenium test error. System tests quit the browser after each test so Chrome profile state, including
password/autofill data, cannot leak from one test into the next.

Dependabot config: `.github/dependabot.yml`.

## Deployment (Kamal)

- `config/deploy.yml`: service/image `universe_maker`, target host `192.168.0.1`, image registry
  `localhost:5555`, `asset_path: /rails/public/assets`, amd64 builder, and a local-only
  `.kamal/secrets` file. The secrets file is ignored, must be mode `0600` or stricter, and must
  never be committed. If it was ever exposed, rotate the Rails master key, the affected
  `secret_key_base`/signed artifacts, and any credentials protected by it before deployment;
  untracking the file does not rotate it or remove it from history.
- Production requires these explicit environment variables (names only; never put values in this
  repository): `APP_HOST`, `MAILER_FROM`, and `SMTP_ADDRESS`; `SMTP_PORT` defaults to `587`,
  `SMTP_DOMAIN` defaults to `APP_HOST`, and `SMTP_USERNAME`/`SMTP_PASSWORD` must be supplied as a
  pair when authentication is used. `SMTP_ENABLE_STARTTLS_AUTO` defaults to `true`, and
  `SMTP_OPENSSL_VERIFY_MODE` defaults to `peer`.
- Search additionally needs `MEILISEARCH_URL` and a key with search and index rights, and a reachable
  Meilisearch instance. The instance holds the universe's descriptions and scene prose in a second
  store, so where it runs is a deployment decision: run it on the same host or a private network, and
  do not point a deployed environment at a public hosted instance. The key is server-side only and is
  never sent to a browser. Without those variables the application still boots and every page still
  renders — search reports itself unavailable — so a missing engine cannot take a deployment down.
  `bin/rails search:reindex` is part of a fresh deployment, not an optional step.
- Production enables `assume_ssl` and `force_ssl`, uses HTTPS for generated mailer URLs, restricts
  the host allowlist to `APP_HOST`, keeps `/up` available to the health check, and marks the
  signed session cookie `Secure`. The deployment must provide a TLS-terminating proxy; do not
  expose the container directly to untrusted HTTP traffic.
- `config/initializers/filter_parameter_logging.rb` redacts password-reset path segments from
  Rails request logs. Password-reset pages also send `Cache-Control: no-store` and
  `Referrer-Policy: no-referrer`. Configure proxy/access-log retention separately; application
  filtering cannot erase a token from an upstream proxy or browser history.
- `config/deploy.yml` must receive the variables above through its `env.clear`/`env.secret` lists,
  backed by the host environment or an approved secret store. Do not run `bin/kamal config` in
  shared CI or paste its output into tickets: the resolved configuration can contain secrets.
- `Dockerfile` builds the app (comments show `docker build -t universe_maker .`); the image runs
  Rails behind **thruster**; volume `universe_maker_storage:/rails/storage` persists Active
  Storage (local disk per `config/storage.yml`). A clean production image/Kamal boot remains a
  separate verification item.
- A MySQL accessory is sketched in `deploy.yml` but commented; the app itself is SQLite.

## Adding a new content model (checklist)

1. One schema-only create migration in `db/migrate/` — `universe_id` FK (+ `parent_id`/`position`/
   `slug` if it is a hierarchical/positioned model), plus any HABTM join table. Never include data
   operations or application-model references. Update `db/schema.rb` via `bin/rails db:migrate`.
2. Model in `app/models/` — `include HasSlug` (+ `Hierarchical`, `HasManyTags`,
   `has_many_tags :foo_tag, scope: :universe_id` / inverse
   `has_many_tagd :foo, scope: :universe_id`, `HasColor` for tags — the scope is mandatory and
   tags remain optional), `belongs_to :universe`, `validates :name, presence: true` (unless it has
   custom identity rules). Story-scoped tag pairs use `scope: :story_id`; Section/SectionTag and
   Scene/SceneTag are the current examples. Sections, Scenes, and their tag definitions are
   the exceptions: they belong to a **story**. A flat ordered sequence uses
   `maintains_flat_positions_for` in its controller and must not include `Hierarchical`.
   A record narrower than those — anything a Scene or a Section owns — must resolve its Universe
   through `UniverseScopeResolver`: give it its own `#universe` that delegates to its owner, or give
   it an owner association named `story`, `scene`, or `section`. Register it in
   `Ability::CONTENT_CLASS_NAMES` as well, and validate any shared scope in the model rather than
   trusting a foreign key.
3. Controller in `app/controllers/` — `Current.universe.<assoc>` scoping,
   `include MaintainsSiblingPositions` + `maintains_sibling_positions_for :model` (or
   `maintains_flat_positions_for` for a parentless sequence) if positioned,
   `params.expect(model: [ … ])`, JSON-only `respond_to` for tree/modal UIs (or HTML flow like
   stories/relations/ownerships/scenes).
4. Route inside `scope "u/:universe_slug", as: :universe` (nest under stories if story-scoped).
   Remember: path helpers need **named** keys.
5. Views — pick one of the three patterns; for modal editors add `*_fields_json` /
   `*_tag_taxonomy_fields` to `app/helpers/modal_fields.rb`.
6. Sidebar link using the shared `shared/_sidebar_link` pattern — in
   `app/views/layouts/_left_sidebar.html.erb` for universe/story content, or in
   `app/views/layouts/_right_sidebar.html.erb` under **Configuration** for universe configuration
   tools and the Members access manager; use `shared/_content_tabs` for related records,
   `shared/_tag_workspace_navigation` for taxonomy management, and
   `shared/_settings_navigation` for a new platform settings section.
7. Fixtures in `test/fixtures/` (dashed slugs), controller + model tests.
8. Search, if the model is something a reader would look for: `include Searchable` and one
   `searchable kind:, title:, body:, route:, scope:` declaration next to the model's fields, plus an
   entry in `Search::Registry::MODELS`. A story-scoped model without its own `story_id` (reached
   through an owner, like a Scene Element) also needs its own `search_scope`. `test/models/
   searchable_test.rb` then builds the document and holds it to the engine's rules — see **Search
   engine**.
9. Development data: add or update `<model>.yml` in every relevant
   `db/data/<universe_slug>/` directory, update the shared model order/registry, and include
   representative records connected to existing universe/story/character/location/item/event
   records. Do not create a feature-level directory such as `db/data/dialog/`; a future Dialog
   model belongs in `db/data/dark/dialogs.yml` and the corresponding files for other universes.
   If the feature changes access or persistence, also update `universe_memberships.yml` where a
   sample universe should exercise private or delegated-admin access.

### Full-stack data contract for a new model

When the owner asks for a new model, treat the request as a complete feature rather than stopping
at the migration and model class:

1. Decide and document the ownership scope (universe, story, section, or a deliberate exception)
   and the associations, tags, and relationship validations it needs.
2. Add the schema-only migration and model, keeping the existing naming, slug, hierarchy, and
   scope conventions.
3. Add the route, controller, views/helpers/navigation, and the appropriate JSON or HTML response
   pattern.
4. Add model, request, and browser-level tests where the feature warrants them. Keep the automated
   suite fixture-based.
5. Add connected development data to every universe directory that should exercise the model. A
   Dialog record, for example, should point to the actual universe/story scope and relevant
   characters, locations, events, sections, and tags rather than being an isolated placeholder.
6. Update the shared loader order/registry and the documentation that describes the new model or
   relationship.
7. If the model should be findable, make it searchable in the same change (step 8 of the checklist
   above) and run `bin/rails search:reindex` when verifying by hand.
7. Validate every changed YAML manifest, rebuild/load the disposable development data, verify the
   rebuilt rows with a scoped query, open the feature in the browser, and report the exact reset/load
   commands, URL, local login, and checks performed. The owner has granted standing approval for a
   local development `db:demo:reset` used to apply `db/data/**/*.yml`; that approval never extends
   to production, test, or another real database.
