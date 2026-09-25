# Development Guide

Commands, tests, seeding, CI, deployment and a "adding a new model" checklist.
Conventions: [universe_maker_conventions.md](universe_maker_conventions.md) ·
Schema: [data_model.md](data_model.md) · Gotchas: [known_quirks.md](known_quirks.md).

## Prerequisites & running

- Ruby **3.4.10** via [mise](https://mise.jdx.dev) (`mise.toml`); `bundle install`.
- **Google Chrome** (or a compatible browser) for `bin/rails test:system`.
- **Bun** for CSS/JS assets: `bun install`; `bun.lock` is the committed source of truth. Use
  `bun install --frozen-lockfile` in CI and other reproducible environments.
- Setup & run:

```bash
bin/rails db:prepare          # create + migrate + production-safe seeds only
UNIVERSE=dark bin/rails db:demo:load  # optional development data (development only)
bin/rails server              # http://localhost:3000
bin/rails console
bun run watch:css             # rebuild CSS on .scss changes (Procfile.dev: foreman start)
```

- CSS pipeline: `app/assets/stylesheets/application.bootstrap.scss` → sass → postcss/autoprefixer
  → `app/assets/builds/application.css`. Development keeps Propshaft on a dynamic manifest under
  `tmp/assets`, so `bun run watch:css` is immediately visible and a stale `public/assets` manifest
  cannot shadow local changes. The build also runs automatically before the test suite, so tests
  require `node_modules` + bun. Use `RAILS_ENV=production bin/rails assets:precompile` when
  checking the production asset manifest; do not run a development precompile as the local CSS
  workflow.

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
  (both belong to `story_one`), scenes (three in `story_one`, one in `story_alt`), all content +
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
  mutations redirect (302) to `/session/new`. Universe-scoped controllers allow unauthenticated
  access only for read actions; the shared authorization callback enforces the universe policy.
- Universe authorization tests must cover both public and private universes. Create explicit
  `UniverseMembership` records for read/write/admin cases; do not rely on a public fixture to stand
  in for a private collaboration scenario. Private non-members—including guests—receive 404;
  members with insufficient access receive 403. Public-universe guest mutations still redirect to
  sign-in.
- Authentication tests must verify that remembered stories survive ordinary navigation but are
  cleared on sign-out, when a new account session starts, after current-user password reset, and
  when a stale authentication session is encountered.

## Lint & security scans

```bash
bin/rubocop                  # rubocop-rails-omakase house style
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
transactionally exercise it. The preferred local lifecycle is to rebuild the disposable database
and then load one universe directory for browser testing.

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

## Scene delivery (slice 11.1 implemented)

[ADR 0007](adr/0007-story-owned-scenes-and-elements.md) and backlog Epic 11 define the Scene
contract. Slice 11.1 has landed the core: the schema-only `scenes` migration, the `Scene` model, the
story-scoped routes/controller, the canonical Scenes list, narrative-order moves, the Scene Details
page and its editor form, the real sidebar link with its own cached count, fixtures, tests, and
connected development data. Section/Event/datetime references, tags, reliable JSON modals,
Elements, and
world-presence links are still pending and are deliberately **not** routed yet. The confirmed
first-version defaults are: Scene `name` labelled **Title**; Element
`name` required and plain-text `body` optional; Dialogue requires at least one speaker; Narration
has none; Scene uses one optional single-point `datetime` with the current Event storage/editor
precision and timezone semantics, not Event's start/end pair; roles remain nullable; and the ADR's
detailed deletion confirmations are mandatory.

Delivery remains staged in [`backlog.md`](backlog.md):

- 11.1 (done) adds the core Scene migration/model, canonical list, ordering controls, editor shell,
  tests, and connected development data.
- Later slices add references and the tab shell, Section grouping, Tags, reliable JSON modals,
  Elements, speaker and presence links, and reverse links in that order.
- Slice 11.5 must fix JSON modal submission/error/delete behavior before Element UI depends on the
  shared modal controller. Do not copy the current 406/stale-DOM behavior into Scene Elements.
- Every slice preserves public/private read-write-admin behavior and updates all model registries,
  authorization resolvers, route-helper guards, fixtures, tests, documentation, and changelog.

When data is added, put it in the relevant `db/data/<universe_slug>/` files (`scenes.yml`,
`scene_tags.yml`, `scene_elements.yml`, and the applicable speaker/presence-link files), not in a
feature directory. Records must use stable symbolic references and demonstrate title-only,
Ungrouped, Section-assigned, independent Event/datetime, shared-Event, Narration, Dialogue,
multi-speaker, multi-Location, and blank/populated-role cases at Epic completion. `scenes.yml`
records already reference their story and use explicit `position` values so the narrative order is
visible in the file. Use the explicit `UNIVERSE=<slug> bin/rails db:demo:load` task for a prepared
development database; the loader refuses production/test writes and does not load another universe.

Manual verification for the shipped slice:

```bash
CONFIRM_DB_RESET=1 UNIVERSE=dark bin/rails db:demo:reset   # destructive: needs approval
bin/rails server
```

Log in with the documented Dark development user, open
`/u/dark/s/<story_id>/scenes`, and check: the sidebar **Scenes** entry links to the selected story
and shows the scene count; the list is in narrative order with position pills; Move up/Move down
reorder the sequence and are disabled at the boundaries; the delete confirmation states the full
ADR 0007 consequences; and a guest or read-only member sees the list and details with no mutation
controls.

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
table owned by that model. Migrations must not read or write application records or reference
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

## CI (`.github/workflows/ci.yml`, runs on PR + push to main)

The test jobs install the pinned Bun version and run `bun install --frozen-lockfile` before
starting Rails, so CSS builds use the same dependency graph as local development.

| Job | Command |
|---|---|
| `scan_ruby` | `bin/brakeman --no-pager`, `bin/bundler-audit` |
| `scan_js` | `bin/importmap audit` |
| `lint` | `bin/rubocop -f github` (cached) |
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
   custom identity rules). Story-scoped tag pairs use `scope: :story_id`. Sections and Scenes are
   the exceptions: they belong to a **story**. A flat ordered sequence uses
   `maintains_flat_positions_for` in its controller and must not include `Hierarchical`.
3. Controller in `app/controllers/` — `Current.universe.<assoc>` scoping,
   `include MaintainsSiblingPositions` + `maintains_sibling_positions_for :model` (or
   `maintains_flat_positions_for` for a parentless sequence) if positioned,
   `params.expect(model: [ … ])`, JSON-only `respond_to` for tree/modal UIs (or HTML flow like
   stories/relations/ownerships/scenes).
4. Route inside `scope "u/:universe_slug", as: :universe` (nest under stories if story-scoped).
   Remember: path helpers need **named** keys.
5. Views — pick one of the three patterns; for modal editors add `*_fields_json` /
   `*_tag_taxonomy_fields` to `app/helpers/modal_fields.rb`.
6. Sidebar link in `app/views/layouts/_left_sidebar.html.erb` using the shared
   `shared/_sidebar_link` pattern; use `shared/_content_tabs` for related records and
   `shared/_tag_workspace_navigation` for taxonomy management. Put the Members access manager in
   the right-side Settings section.
7. Fixtures in `test/fixtures/` (dashed slugs), controller + model tests.
8. Development data: add or update `<model>.yml` in every relevant
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
7. Rebuild/load the disposable development data, open the feature in the browser, and report the
   exact load command, URL, local login, and checks performed. Do not run a destructive rebuild
   without approval.
