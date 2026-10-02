# Development Guide

Commands, tests, seeding, CI, deployment and a "adding a new model" checklist.
Conventions: [conventions.md](conventions.md) ·
Schema: [data_model.md](data_model.md) · Gotchas: [known_quirks.md](known_quirks.md).

## Clarifying a request before coding

An agent settles the shape of a request before it writes code, because a request can be two tasks
dressed as one, or one task large enough that finishing it in a single pass is the wrong call.

Two shapes require a question first:

- **Unrelated items named together.** If A and B do not belong together — different models, areas,
  files, or bugs with no shared code path — ask: *"A and B are not related. Do you want to proceed
  with both, or only one now?"* Name the one you would do first. Listing both in one sentence is
  not approval to do both.
- **One large item that divides.** If an item touches several different areas of the project
  (model, migration, routes, controller, views, JavaScript, tests, demo data, docs) and can be
  delivered in independent pieces, ask: *"Do you want to do everything now, or do you want to split
  this task into slices/parts/chunks?"* Bring the proposed slices with the question, each with what
  it contains, instead of asking the question open-ended.

The question is skipped when the items are the same feature or code path, when the request already
answers it ("only A", "all at once", "split into three"), or when the answer is obvious from the
repository and the assumption can be stated in the hand-off summary instead. It is asked with the
agent's question tool: concrete options, one at a time, short wording, after reading enough of the
code to know what the real decision is. One answer settles it — the same scope, slicing, or ordering
is not asked again later in the same task, and "just do it" is a standing answer for the rest of
the request.

This is separate from the **NOW / LATER / NEVER** decision in
[`backlog.md`](backlog.md), which covers work found outside the requested scope. Intake comes
first; NOW/LATER/NEVER applies to whatever extra turns up afterwards. The rules are summarized in
[`../AGENTS.md`](../AGENTS.md), which is the always-loaded version.

## Prerequisites & running

- Ruby **3.4.10** via [mise](https://mise.jdx.dev) (`mise.toml`); `bundle install`.
- **Google Chrome** (or a compatible browser) for `bin/rails test:system`.
- **Bun** for CSS/JS assets: `bun install`; `bun.lock` is the committed source of truth. Use
  `bun install --frozen-lockfile` in CI and other reproducible environments.
- **An image library**, for record photos. Either **libvips** or **ImageMagick**: `PhotoProcessing`
  prefers `ImageProcessing::Vips` and falls back to `ImageProcessing::MiniMagick` when libvips is not
  installed, so one of the two is enough. libvips is installed in the `Dockerfile` and in CI;
  ImageMagick is the usual workstation install. Without either, uploading a photo fails with an
  ordinary "could not be read as an image" field error rather than a stack trace. The photo tests
  read a stored file's size through `PhotoDimensions`, which asks those same two libraries in the
  same order, so no test needs an image tool the application itself does not use.
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

### Test coverage

Coverage is measured on every run and gated in CI. It is required from `test/coverage_helper.rb`
**before** `config/environment`, because SimpleCov only measures what is loaded after it starts and
Rails loads application code while booting.

```bash
bin/rails test            # writes tmp/coverage/index.html and tmp/coverage/coverage.json
CI=1 bin/rails test       # the same, plus the line/branch thresholds
bundle exec simplecov uncovered --input tmp/coverage/coverage.json --top 20 --missing
```

- `tmp/coverage/` is inside the already-ignored `tmp/`, so no generated report is ever committed. The
  HTML report is uploaded from CI as the `coverage` artifact.
- Measured with branch coverage on, over this application's own Ruby only:
  `app/{channels,controllers,helpers,jobs,mailers,models,services}/**/*.rb` and `lib/**/*.rb`.
  `cover` also reports files nothing loaded, so a file no test reaches reads as 0% instead of
  silently not appearing. `app/javascript` is excluded: the Stimulus controllers have their own
  runner and their own gate (`bun run test:js`), and one number must not cover two toolchains.
- The thresholds are **90% line / 75% branch**, set from a measured baseline (94.59% / 80.99% on
  2026-10-01) with a few points of headroom. They exist to catch a *drop*, not to reward adding
  assertions, and they are only enforced when `CI` is set. A single-file or `-n`-filtered run
  measures a fraction of the application by design and would fail spuriously, so it reports without
  gating; `CI=1 bin/rails test` reproduces the CI check locally.
- Consecutive runs within 10 minutes are **merged**, so a single-file run started right after a full
  one reports the union of both. Merging only ever adds covered lines, so the number is never
  understated and the gate cannot be weakened by it — but delete `tmp/coverage/` first if you want
  one run's own figure.
- `merge_subprocesses` is on because `parallelize(workers:)` forks one process per worker. Without it
  the report holds only the parent process's own execution and reads a few percent with nothing to
  explain it.
- The browser suite writes its **own** report to `tmp/coverage-system/` and sets no threshold. It is
  a smoke suite whose total (about 70% line) is not comparable with the request suite's, and the two
  run in separate processes and separate CI jobs.
- A line percentage is not evidence that the behavior that matters is covered. Authorization,
  cross-universe scope, the JSON/HTML response contracts, and failure paths can all be untested
  behind a high number, and the browser suite is a smoke suite rather than exhaustive UI coverage.
  The three files with the lowest coverage after this measurement are
  `app/services/development/database_reset.rb` (it runs in its own process in
  `test/services/development/database_reset_test.rb`, which the report cannot see),
  `app/models/search/client.rb` (the engine is verified out of band by
  `test/search/meilisearch_integration_test.rb`), and `app/controllers/concerns/universe_authorization.rb`
  (its guest branches are unreachable while every controller still runs `require_authentication`
  first). Treat a gap as a question about behavior, not a number to fill.

Layout:
- `test/controllers`, `test/models`, and `test/integration` — model, request, navigation, and
  workspace coverage; `test/services` — development-data registry/loader coverage; `test/jobs` and
  `test/channels` — the queued search writes and the websocket connection's session rules;
  `test/system` — browser-level smoke coverage for the primary workspace journeys.
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
  same-host referer is remembered, and an external site cannot choose the destination. A sign-in or
  password page is never a destination: a wrong password reopens the form and the browser offers that
  form as the referer of the reload, which used to loop a successful sign-in back to the form. With
  no destination left, sign-in lands on the universe list. Universe-scoped controllers allow
  unauthenticated access only for read actions; the shared authorization callback enforces the
  universe policy.
- Signing in to a remembered page that the new account still cannot read answers with the universe
  list and an alert, because a bare 403/404 there reads as "the sign-in did nothing". That exception
  covers only the single request after the sign-in; assert `assert_response :not_found` /
  `:forbidden` for every ordinary refusal, as usual.
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
  dialog. `bunfig.toml` preloads it. It also installs the English string blob (`i18n.use`), so a
  controller under test reads the same words a real English page would.
- Bun runs every file in `test/javascript/` in **one** process, in the order the filesystem hands
  them over, which is not the same on every machine. Module state is therefore shared: a file that
  installs its own `i18n` table must put the real blob back when it finishes (`afterAll`), or every
  file that happens to run after it asserts against a raw key instead of a reader's sentence. This
  is why `i18n_test.js` restores `test/javascript/fixtures/client_strings.en.json`.
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
bun audit                    # vulnerable packages in the whole committed Bun graph
```

The two JavaScript checks answer different questions, and neither replaces the other.
`bin/importmap audit` reads the packages `config/importmap.rb` names, which is the right check for a
locally vendored asset. `bun audit` reads `bun.lock`, which is the only check that sees anything below
the direct dependencies; it exits non-zero on a finding, so it works as a CI gate, and
`bun audit fix` upgrades only the vulnerable packages, to the lowest version that still satisfies
every dependent's range. Both need the pinned Bun from `mise.toml`, because `bun audit` reads the
lockfile through the same Bun that wrote it: an unpinned `bun` on `PATH` audits a differently
resolved graph.

For a locally vendored npm asset, keep a same-line version comment on its importmap pin, for
example `pin "tom-select", to: "tom-select.js" # @2.6.2`. Importmap Audit reads this metadata
from `config/importmap.rb`; it does not infer a version from a version banner inside the
JavaScript file, and it never looks at the file's bytes. `config/vendored_javascript.yml` records
where each vendored asset lives inside its npm package, and `test/vendored_javascript_test.rb`
closes that gap:

- every file in `vendor/javascript/` is declared in the manifest;
- the pin's `# @version` comment, the version `bun.lock` resolves, and the range `package.json`
  declares are one version;
- `bun.lock` records a `sha512` integrity for the package, which is what makes the next check
  meaningful;
- the vendored bytes are byte-identical to the same file inside `node_modules`, which Bun extracted
  from the tarball whose digest `bun.lock` pins. That is a real provenance answer and needs no
  network call. It **skips** when `node_modules` is absent, but only locally: the CI job installs
  the dependencies before the suite runs, so a missing file there fails instead.

Keep the manifest, the pin comment, `bun.lock`, and the vendored asset synchronized when updating
Tom Select.

`bin/brakeman` deliberately omits the `--ensure-latest` flag the Rails-generated binstub adds. That
flag makes the scan a tripwire: Brakeman exits before scanning as soon as any newer version is
published, so an unrelated upstream release silently stops the security scan locally and in CI while
the command still looks like it ran. Keep the flag out; upgrade the pinned gem in its own change.

## Repository quality and DataFactor follow-up

The 2026-09-25 DataFactor report is a point-in-time snapshot, not a release gate or a reason to
add ceremonial dependencies or Git history. Its actionable recommendations are distilled in
[`data_factor_guidance.md`](data_factor_guidance.md); deferred work is tracked in
[`backlog.md`](backlog.md) and verified gaps are recorded in [`known_quirks.md`](known_quirks.md).
Verify each recommendation against the current tree before acting. In particular, `/up` is already
routed and `bun.lock` is already committed and used with `--frozen-lockfile` in CI and Docker.

The current CI baseline runs RuboCop, Brakeman, Bundler Audit, Importmap Audit, `bun audit` over the
committed lockfile, Minitest with a line/branch coverage gate, checked-in development-data manifest
checks, a from-zero migration run, a browser smoke suite, and a production-image build/boot check
against `/up` that also inspects the image for leftover test and build artifacts. Structured request
and error logging is implemented and needs no CI job: it is a middleware and an initializer that
run in every environment, covered by `test/integration/request_log_middleware_test.rb` and
`test/lib/error_tracking_test.rb`. Optional error **forwarding** is off unless
`ERROR_TRACKING_DSN` is set, and no CI job exercises it against a real collector — do not claim it
does. It does **not** provide a one-command Compose setup. That is follow-up work, not a current
capability; do not claim it in release or onboarding copy until it is implemented and documented.

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
  dark/       # the more complete Dark dataset, and three stories in one universe
  lotr/       # the smaller Lord of the Rings dataset
  star_wars/  # future universe data
```

Sample images live beside that tree rather than inside it, in `db/photos/<universe_slug>/`. A
`photos.yml` entry names one of those files through the virtual `source_file` attribute
(`source_file: portrait.jpg`), and the loader puts its bytes through exactly the same processing an
upload does — so a sample photo arrives as a 300×300 square and the stored file is never the source
asset. The checked-in images are deliberately **not** square, so a stored square proves the crop
happened rather than passing through unchanged.

Each directory contains all data used to exercise that universe: its user/universe record, stories,
sections, section tags, world-building records, taxonomies, and relationships. A universe
directory is not a feature directory. For example, a future `Dialog` model belongs in
`db/data/dark/dialogs.yml` (and in `db/data/lotr/dialogs.yml` when that universe should exercise
it), not in `db/data/dialog/`.

`dark` holds **three stories in one universe** — `netflix-dark`, `netflix-darker`, and
`bethesda-dark` — so the login → universe → story flow and a universe that is not a single story are
both exercisable by hand. The three share the universe's Characters, Locations, Items, and Events and
differ in everything story-scoped: each declares its own sections, section tags, scene tags, and scene
sequence, and each scene's `position` starts again at `0` rather than continuing a universe-wide
numbering. `netflix-dark` is first in `stories.yml` so it stays the Story a reader is offered first,
and its slug-prefixed manifest entries (`s1`, `s1e1`, `secrets`, …) are the ones the rest of the
narrative sample data refers to. `bethesda-dark` carries no photo, so the "a Story without one"
state is visible without inventing a record.

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

Both writing tasks report the local sign-in they created: the accounts that now exist and the
password they got. No manifest states a password — the loader takes it from
`UNIVERSE_MAKER_DEV_PASSWORD` or generates one for the load and prints the export command.
[`db/data/README.md`](../db/data/README.md#development-credentials) owns that contract; the
`docs/smoke_test_stories.sh` section below is its only other consumer.

Both destructive tasks rebuild through `Development::DatabaseReset`, and the way it rebuilds is
load-bearing rather than incidental:

- **Every phase gets its own connection lifecycle.** `db:drop` unlinks the SQLite file while the
  process still holds a connection to it, and SQLite keeps that deleted inode alive for every open
  handle — so the create and migrate that follow write to a file that no longer has a name. This is
  invisible in a default development setup for an accidental reason: `db:create` also creates the
  *test* database, and connecting to that second file disconnects the first, so the next phase
  reopens the new development file by name. Add a `DATABASE_URL`, or set `SKIP_TEST_DATABASE`, and
  nothing reconnects — the reset then reports success and leaves **no database at all**. Because the
  reset touches the development database only (below), there is no second database left to lean on,
  so the reset releases its connections around the drop and around the create. The behaviour does
  not depend on which other databases happen to be configured.
- **The migrations run; `db/schema.rb` is not loaded instead.** On a database with no
  `schema_migrations` table, `db:migrate` loads the checked-in schema dump, which records every
  version as applied. Amending a shipped migration would then change nothing on a fresh database.
  See [Amending a shipped migration does not work here](#amending-a-shipped-migration-does-not-work-here).
- **The result is verified, and verified from the file.** The reset re-reads the database through a
  connection opened after the last handle was released, and fails if the file is missing, has no
  `schema_migrations` table, is missing a migration version, or has no `universes` table. An
  in-process check could not see this class of failure, because the stale handle answers from the
  deleted inode.
- **Scope is the development database only.** The drop and the create go through the
  per-configuration `ActiveRecord::Tasks::DatabaseTasks.drop`/`create` over the current
  environment's configurations, not through `drop_current`/`create_current`: Rails' own versions
  widen to the *test* environment in development (`each_current_environment` appends it), so a reset
  also emptied `storage/test.sqlite3`. The approval behind either task covers the disposable
  development database and never the test or production one, so the scope is now stated where it is
  enforced — in `Development::DatabaseReset.db_configs` — rather than being a side effect of which
  other databases happen to be configured.

The Rails test suite uses `test/fixtures/` so automated tests remain deterministic; these mutable
universe files are not its fixture source. `config/ci.rb` validates the checked-in manifests in
test mode instead of replanting demo records.

## Scene delivery (complete)

The Scene domain, its confirmed defaults (Title labelling, a single-point `datetime`, nullable roles,
Dialogue needing a speaker, the mandatory deletion confirmations), its workspace tabs, and its
deletion contract are in [features/scenes.md](features/scenes.md). The Scene-owned tables shipped as
their own create migrations (`CreateSceneElements`, which also creates the `scene_element_speakers`
join, `CreateSceneCharacters`, `CreateSceneItems`, and `CreateSceneLocations`), which matters for the
reason given below.

The delivery history — what each slice added, in order — is in
[`delivery_history.md`](delivery_history.md), which is the durable record of it. A planned slice
number is not a durable reference, so none is kept here. Every delivery preserved public/private
read-write-admin behavior and updated all model registries, authorization resolvers, route-helper
guards, fixtures, tests, documentation, and changelog.

### Amending a shipped migration does not work here

`scenes` already shipped its create migration with the core delivery, so the references arrived in a
separate schema-only alter migration (`AddSceneReferencesToScenes`). This is not just tidiness.
Rails 8.1's `ActiveRecord::Tasks::DatabaseTasks.initialize_database` loads `db/schema.rb` when a
database has no `schema_migrations` table, so on a **freshly created** database `db:migrate` loads
the checked-in schema instead of executing the migration files. Editing an applied migration
therefore changes nothing on a fresh database built that way, the regenerated `db/schema.rb`
silently keeps the old shape, and the mismatch is only visible when a manifest or a form references
a column that does not exist. Add a new migration for any change to a table that has already
shipped.

The two development reset tasks are the exception, and deliberately so: `Development::DatabaseReset`
runs the migration files with `skip_initialize: true`, so `db:restart` and `db:demo:reset` execute
the migrations from zero rather than loading the dump. Everything else — `db:migrate`, `db:prepare`,
`db:setup`, and the CI `migrations-from-zero` job — still loads `db/schema.rb` on a fresh database,
which is why the rule above still applies to them. See
[Explicit development data tasks](#explicit-development-data-tasks).

### Scene data and manual verification

When data is added, put it in the relevant `db/data/<universe_slug>/` files (`scenes.yml`,
`scene_tags.yml`, `scene_elements.yml`, `scene_characters.yml`, `scene_items.yml`, and
`scene_locations.yml`), not in a
feature directory. Records must use stable symbolic references and demonstrate title-only,
Ungrouped, Section-assigned, independent Event/datetime, shared-Event, tagged/untagged Scene,
Narration, Dialogue, multi-speaker, multi-Location, multi-Item, and blank/populated-role cases.
`scenes.yml` records reference their story and may reference `section:`, `event:`, and
`scene_tags:` with `Model.slug` references and an independent `datetime:`, and use
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

Sign in with the Dark development user and the password the load reported (see
[`db/data/README.md`](../db/data/README.md#development-credentials)), open `/u/dark`, and check
that all three stories are listed with **Open** actions, that **None selected** is the sidebar's
story state until one is opened, and that switching between them changes the Sections and Scenes
under the Story while Characters, Locations, Items, and Events stay the same records.

Then open `/u/dark/s/<story_id>/scenes` and check:
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

Open a Scene and check: the **Scene Details** tab is active while **Characters**, **Items**, and
**Locations** are live links rather than dead links; Details shows the Section
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

This section is the *verification* workflow; the rules it verifies are in
[features/tags.md](features/tags.md) (the DSL, the tree, the editor) and
[conventions.md](conventions.md#controllers) (`MaintainsSiblingPositions`, `PositionedResourceOrder`,
and the flat-versus-hierarchical modes).

- Run `test/system/taxonomy_tree_test.rb` for hostile-name, stale-state, boundary insertion,
  keyboard, and narrow/touch regressions, and confirm that a mutation refreshes the same URL so
  parent/tag options and counts stay server-authoritative.
- Run `test/services/positioned_resource_order_test.rb` plus the positioned controller tests after
  changing ordering behavior.
- Do not reintroduce hover-only controls, or `innerHTML` for a user-controlled value.

## Testing record photos

The photo **contract** is in [features/photos.md](features/photos.md). This section is only the
test workflow.

A record may carry one photo, and the photo is always optional. The stored file is only ever the
finished 300×300 square: the browser cropper sends a `data:` URL and the server crops and re-encodes
it again, so a request that skipped the cropper cannot store something else, and the original upload
is never written to disk. [ADR 0015](adr/0015-record-photos.md) is the decision;
[`data_model.md`](data_model.md#photos) is the schema.

Coverage is split by what each layer can prove:

- `test/models/photo_test.rb` — the model's own rules, including that `Photo::OWNER_CLASS_NAMES`
  equals the models that include `HasPhoto` (a missing entry is a photo destroyed while another
  record still shows it).
- `test/models/has_photo_test.rb` — the concern: optionality, the two virtual writers, the
  same-universe rule, and that a rejected save never takes the existing photo away.
- `test/services/photo_processing_test.rb` — the 300×300 square, metadata stripping, the
  content-signature allowlist, and the size bound.
- `test/controllers/photo_mutation_test.rb` — that all eighteen controllers accept the fields.
- `test/controllers/record_photo_details_test.rb` — the details-page layout with and without a photo.
- `test/controllers/photo_field_test.rb` — that the field is rendered where a mutation control
  belongs, and offered to no one else.
- `test/javascript/photo_crop_controller_test.js` — the cropper's own logic, without a browser.
- `test/system/photo_crop_test.rb` — what only a browser can show: choosing a file opens a square,
  the square moves with the keyboard alone, the finished crop is what the record ends up showing, and
  a read-only member is offered no cropper at all.

`Photo` cannot use a fixture attachment, so tests build one through `create_photo` in
`test/support/photo_test_helper.rb` rather than through `test/fixtures/photos.yml`.

To verify by hand:

```bash
CONFIRM_DB_RESET=1 UNIVERSE=dark bin/rails db:demo:reset   # loads db/data/dark + db/photos/dark
UNIVERSE=lotr bin/rails db:demo:load                       # optional second universe
bin/rails server
```

Open a Dark character that has a photo and check: its details page shows the square on the left of
the surface card; a character without one looks exactly as it did before photos existed. Edit it,
choose a file, move the square with the arrow keys or the move buttons, and press **Use this
photo** — the saved record's stored file is 300×300 whatever the source aspect ratio was. Press
**Cancel** in the cropper instead and the record is unchanged. Check **Remove the current photo** and
save to go back to no photo. A guest reading a public universe, and a read-only member, see the photo
and no editor.

## Database migrations

The database is intentionally disposable: schema migrations only define the structure. Demo
records are reconstructed from the per-universe files under `db/data/`; they are not backfilled by
migrations. Keep one schema-only create migration per persisted model, including any HABTM join
table owned by that model. Once that create migration has shipped, add **new** migrations for later
column changes: on a freshly created database Rails 8.1's `initialize_database` loads
`db/schema.rb` rather than executing the migrations, so editing an applied migration has no effect
there (see [Amending a shipped migration does not work here](#amending-a-shipped-migration-does-not-work-here)).
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
# with a server on :3000
PASSWORD='<the password db:demo:reset printed>' bash docs/smoke_test_stories.sh
```

It has no default credential. `PASSWORD` (or `UNIVERSE_MAKER_DEV_PASSWORD`) must carry the
development password, and the script fails with that instruction when neither is set; it never
prints or stores the value. `BASE` and `EMAIL` still default to `http://localhost:3000` and
`lotr@lotr`.

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
| `scan_js` | `bin/importmap audit`, then `bun install --frozen-lockfile` and `bun audit` |
| `lint` | `bin/rubocop -f github` (cached) |
| `js-check` | `bun run lint:js`, `bun run test:js` |
| `test` | `bin/rails db:test:prepare test` with `CI=1` (the coverage gate), then `UNIVERSE=dark bin/rails db:demo:check` and `UNIVERSE=lotr bin/rails db:demo:check`; uploads the `coverage` artifact from `tmp/coverage` |
| `migrations-from-zero` | `bin/rails db:drop`, `bin/rails db:create`, `schema_migration.create_table`, `bin/rails db:migrate` as four separate processes, then a guard that the migrations ran, `bin/rails db:migrate:status`, and `git diff --exit-code db/schema.rb` |
| `system-test` | `bin/rails db:test:prepare test:system` (browser-based smoke tests; uploads screenshots on failure). No `CI`, so it writes its own report to `tmp/coverage-system` and gates nothing |
| `production-boot` | `docker build` the production image, assert the image carries no test or build artifacts, run it with throwaway environment variables, and require `GET /up` to answer `200`. Fails within 120 seconds, and prints the container log on failure |

`CI=1` is set explicitly in the `test` job rather than relying on GitHub Actions' own `CI`, because a
run that silently lost the gate would still be green. `production-boot` uses only locally-unusable
values: `APP_HOST` and `MAILER_FROM` are on the reserved `.invalid` TLD, `SMTP_ADDRESS` is never
contacted, and `SECRET_KEY_BASE` is `openssl rand` output for that run. It boots the container
exactly as the entrypoint does, so the first request also proves the production schema, the Solid
Cache/Queue/Cable databases, and the precompiled assets came up.

The artifact check in `production-boot` is what makes the Dockerfile's pruning enforceable rather
than aspirational. It asserts that `/rails/node_modules` and `.git` are absent and that none of the
development/test gems (Capybara, Selenium, SimpleCov, Brakeman, RuboCop, Bundler Audit, debug,
web-console) reached the image — and, in the same pass, that `application-*.css`,
`bootstrap.bundle.min-*.js` and `fonts/bootstrap-icons-*.woff2` **are** in `public/assets`. The last
part is what keeps the `node_modules` removal honest: the stylesheet, the Bootstrap bundle, and the
icon font can only be resolved while `node_modules` exists, so if they were missing from
`public/assets` the image would serve a broken stylesheet in production and nothing else would fail.

`assets:precompile` boots the production environment, and `config/environments/production.rb` refuses
to boot without `APP_HOST`, `MAILER_FROM`, and `SMTP_ADDRESS`. The Dockerfile therefore passes those
three names to that one build step as `ARG`s defaulting to `.invalid` hosts. They are build-time
arguments, not image environment variables, so the running container still has to be given real
values; the digests in `public/assets` do not depend on them.

The migration commands must be separate processes. `db:drop` unlinks the SQLite file while the
process still holds a connection to it, so one `bin/rails db:drop db:create db:migrate` migrates the
deleted inode, leaves the recreated database empty, and the next command reports that the schema
migrations table does not exist.

`schema_migrations` is created before migrating, and that is the step that makes the job mean what
its name says. On a database without that table `db:migrate` loads `db/schema.rb` instead of
executing the migrations and records every version as applied, so `db:migrate:status` would report
all 36 `up` and `git diff --exit-code db/schema.rb` would compare the dump against itself. Creating
the table first makes Rails treat the database as initialized, so the migration files run. The job
then asserts that no `schema_sha1` was recorded in `ar_internal_metadata` — that row is written only
by `DatabaseTasks.load_schema` — so a future Rails change that makes the pre-creation ineffective
fails the job instead of quietly turning it into a no-op.

Verified by amending a shipped migration to add a column: the previous sequence reported all 36
migrations `up` and left `db/schema.rb` unchanged, so it passed; the current one runs the migration,
puts the column in the database, and fails on the schema diff. See
[Amending a shipped migration does not work here](#amending-a-shipped-migration-does-not-work-here)
and [Explicit development data tasks](#explicit-development-data-tasks).

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

Dependabot config: `.github/dependabot.yml`. Four ecosystems: `bundler`, `bun`, `docker`, and
`github-actions`. The JavaScript entry is **`bun`, not `npm`**: this repository installs with
`bun install --frozen-lockfile` and commits `bun.lock`, and Dependabot's npm ecosystem does not
reliably rewrite a Bun lockfile, which turns every update PR into a failing frozen install. Dependabot
does not run Bun security updates, so `bun audit` in CI is what covers advisories. A `docker` PR that
moves the base image also has to be reconciled with the pins that must agree with it — `mise.toml` for
Ruby, `package.json`'s `packageManager` for Bun, and the `bun-version` each CI job installs Bun with.
Those four are the same version and are not derived from one another, so a PR that moves one has to
move all of them.

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
- **Runtime logging.** `RequestLogMiddleware` (`lib/request_log_middleware.rb`) writes one JSON
  `request` event per completed request and `ErrorTracking` (`lib/error_tracking.rb`) writes one
  JSON `error` event per reported exception, both on the tagged production `STDOUT` stream. The
  request id is the correlation key across the log tag, the `request_id` field, and the
  `X-Request-Id` response header. Both events are allowlists: no client IP, cookie, session,
  parameter, or account is emitted. Rails' own `Started GET …` line still prints the client IP, so
  configure log retention accordingly. See
  [architecture.md](architecture.md#runtime-logging-and-observability) for the full contract,
  including why no metrics endpoint exists.
- **Optional error tracking.** Set `ERROR_TRACKING_DSN` to an **https** URL to forward unhandled
  errors to a collector. Without it, nothing is initialized and nothing leaves the process — the
  `error` events are still logged. There is **no dependency**: delivery is a `Net::HTTP` POST of the
  redacted payload. A malformed value fails the boot rather than being ignored. Only unhandled
  errors are forwarded; recovered errors stay in the log. Never commit the value: it is a
  credential, and it is scrubbed out of the log.
- **Health check.** `GET /up` answers **200** and is the deployment's liveness probe. It is pinned
  by `test/integration/health_check_test.rb`; CI's `production-boot` job proves it inside the built
  image.
- `ERROR_TRACKING_DSN` is **optional**: absent (the default) means error tracking is off and error
  events are only logged; present and a valid https URL means unhandled errors are forwarded there.
- `config/deploy.yml` must receive the variables above through its `env.clear`/`env.secret` lists,
  backed by the host environment or an approved secret store. Do not run `bin/kamal config` in
  shared CI or paste its output into tickets: the resolved configuration can contain secrets.
  `test/deployment/kamal_configuration_test.rb` is the safe substitute — it loads the file through
  Kamal's own loader, which runs the same ERB rendering, YAML parsing, and schema validation
  `bin/kamal config` runs, and asserts on structure only. A mistyped key fails the suite instead of
  the deploy, and the test proves that by requiring Kamal to reject a deliberately invalid file.
- `Dockerfile` builds the app (comments show `docker build -t universe_maker .`); the image runs
  Rails behind **thruster**; volume `universe_maker_storage:/rails/storage` persists Active
  Storage (local disk per `config/storage.yml`). The image excludes the `development` and `test`
  bundle groups and drops `node_modules` after precompiling, and CI's `production-boot` job asserts
  both. A real deploy to a real host is still unverified; the image build, its contents, and `/up`
  are what CI proves.
- A MySQL accessory is sketched in `deploy.yml` but commented; the app itself is SQLite.

## Adding a new content model (checklist)

1. One schema-only create migration in `db/migrate/` — `universe_id` FK (+ `parent_id`/`position`/
   `slug` if it is a hierarchical/positioned model), plus any HABTM join table. Never include data
   operations or application-model references. Update `db/schema.rb` via `bin/rails db:migrate`.
2. Model in `app/models/` — `include HasSlug` (+ `Hierarchical`, `HasManyTags`,
   `has_many_tags :foo_tag, scope: :universe_id` / inverse
   `has_many_tagged :foo, scope: :universe_id`, `HasColor` for tags — the scope is mandatory and
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
