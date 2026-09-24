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
bin/rails db:prepare          # create + migrate + current transitional seed (first run)
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
  workspace coverage; `test/system` — browser-level smoke coverage for the primary workspace
  journeys; `test/helpers` and `test/mailers/previews` are effectively empty.
- `test/fixtures/*.yml` — loaded for **all** tests (`fixtures :all`): users, universes,
  **stories** (`story_one`, `story_alt` in universe one, `story_two` in universe two), sections
  (both belong to `story_one`), all content + tag fixtures.
- Sign in with `sign_in_as(users(:user_one))` /
  `sign_out` from `test/test_helpers/session_test_helper.rb`.
- Route helpers in tests must be fully qualified:
  `universe_story_sections_url(universe_slug: @universe.slug, story_id: @story)`.
- `test/routing/universe_route_helper_arguments_test.rb` parses Ruby and ERB call sites and fails
  if an application or test call uses positional arguments with a universe-scoped route helper.
- `RecordNotFound` renders **404** in tests (`show_exceptions = :rescuable`): use
  `assert_response :not_found` to assert cross-scope/unknown-id rejections.
- Unauthenticated access: some controllers use `allow_unauthenticated_access`; a request without
  a session cookie redirects (302) to `/session/new`.

## Lint & security scans

```bash
bin/rubocop                  # rubocop-rails-omakase house style
bin/brakeman --no-pager      # static security analysis
bin/bundler-audit            # vulnerable gems
bin/importmap audit          # vulnerable JS pins
```

## Seeding / development data

`db/data/` contains checked-in but **disposable development data**. It is not production seed data,
and it is not loaded by the test suite. The preferred local lifecycle is to rebuild the disposable
database and then load one universe directory for browser testing.

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

The current implementation has two different loaders:

- `db/data/dark/dark.rb` is a generic YAML loader. It walks `models_in_order`
  (User → Universe → **Story** → SectionTag → Section → … → Event), reads
  `db/data/<model>.yml`, and resolves reference strings such as `"Model.some_slug"` with
  `Model.find_by(slug: …)`. Arrays are supported, and a `"Tag.*"` reference is also recorded for
  colored output. Referenced models therefore need a stable **slug**.
- `db/data/lotr/lotr.rb` is plain Ruby containing the user, universe, story, section tags, and
  three book sections.

The intended model order is shared by the universe data rather than duplicated as a
feature-specific loader. The current Dark loader keeps that order in `dark/dark.rb`; the LOTR Ruby
loader is a smaller transitional exception. New model work should centralize the shared order in
the development loader/registry. New model data must use stable symbolic references and preserve
the model's universe/story scope. If `Dialog` is story-scoped, its records use
`story: Story.<slug>`; if it is universe-scoped, they use `universe: Universe.<slug>`. Include
related characters, locations, items, events, sections, and tags where those associations exist
so the browser scenario exercises the real feature graph.

### Current and target execution paths

`bin/rails db:seed` currently loads `db/seeds/**/*.rb` and then the hardcoded list
`["dark", "lotr"]` from `db/seeds.rb`. This is transitional. The loaders use `create`/`create!` on
every run, so the demo data is not safe to rerun; that is acceptable for disposable data only when
the database is deliberately rebuilt. It must not be treated as a production seed path.

The intended replacement is an explicit, environment-guarded development task, conceptually:

```bash
bin/rails db:demo:check UNIVERSE=dark       # proposed; validate without committing data
bin/rails db:demo:load UNIVERSE=dark        # proposed; load one universe directory
bin/rails db:demo:reset UNIVERSE=dark       # proposed; rebuild, migrate, and load it
```

These task names are a design target and are not implemented yet. The eventual task must refuse
to run in production, and `db:seed`/`db:prepare` must not load temporary development records.
Until that separation is implemented, use `bin/rails db:restart` only with approval; it currently
drops, recreates, migrates, and seeds the development database.

The Rails test suite uses `test/fixtures/` so automated tests remain deterministic; these mutable
universe files are not its fixture source. The local `config/ci.rb` still contains a transitional
`db:seed:replant` check, which should be revisited when the seed boundary is separated.

## Database migrations

The database is intentionally disposable: schema migrations only define the structure. Demo
records are reconstructed from the per-universe files under `db/data/`; they are not backfilled by
migrations. Keep one schema-only create migration per persisted model, including any HABTM join
table owned by that model. Migrations must not read or write application records or reference
application models. After changing a schema, rebuild the development database and reload the
relevant universe data with approval; do not run `bin/rails db:restart` without approval.

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
| `system-test` | `bin/rails db:test:prepare test:system` (browser-based smoke tests; uploads screenshots on failure) |

Dependabot config: `.github/dependabot.yml`.

## Deployment (Kamal)

- `config/deploy.yml`: service/image `universe_maker`, target host `192.168.0.1`, image registry
  `localhost:5555`, `asset_path: /rails/public/assets`, amd64 builder, secrets from
  `.kamal/secrets`, sample hooks in `.kamal/hooks/`.
- `Dockerfile` builds the app (comments show `docker build -t universe_maker .`); the image runs
  Rails behind **thruster**; volume `universe_maker_storage:/rails/storage` persists Active
  Storage (local disk per `config/storage.yml`).
- Production config highlights (`config/environments/production.rb`): `solid_cache` store,
  `solid_queue` adapter (separate `queue` DB), 1-year cache headers for public assets,
  `assume_ssl`/`force_ssl` present but **commented out**.
- A MySQL accessory is sketched in `deploy.yml` but commented; the app itself is SQLite.

## Adding a new content model (checklist)

1. One schema-only create migration in `db/migrate/` — `universe_id` FK (+ `parent_id`/`position`/
   `slug` if it is a hierarchical/positioned model), plus any HABTM join table. Never include data
   operations or application-model references. Update `db/schema.rb` via `bin/rails db:migrate`.
2. Model in `app/models/` — `include HasSlug` (+ `Hierarchical`, `HasManyTags`,
   `has_many_tags :foo_tag` / inverse `has_many_tagd :foo`, `HasColor` for tags — tags are
   optional, `has_many_tags` adds no presence validation), `belongs_to
   :universe`, `validates :name, presence: true` (unless it has custom identity rules).
   Sections are the exception: they belong to a **story**.
3. Controller in `app/controllers/` — `Current.universe.<assoc>` scoping,
   `include MaintainsSiblingPositions` + `maintains_sibling_positions_for :model` if positioned,
   `params.expect(model: [ … ])`, JSON-only `respond_to` for tree/modal UIs (or HTML flow like
   stories/relations/ownerships).
4. Route inside `scope "u/:universe_slug", as: :universe` (nest under stories if story-scoped).
   Remember: path helpers need **named** keys.
5. Views — pick one of the three patterns; for modal editors add `*_fields_json` /
   `*_tag_taxonomy_fields` to `app/helpers/modal_fields.rb`.
6. Sidebar link in `app/views/layouts/_left_sidebar.html.erb` using the shared
   `shared/_sidebar_link` pattern; use `shared/_content_tabs` to connect related content and its
   corresponding tag taxonomy. Keep the Configuration section for future organization/settings.
7. Fixtures in `test/fixtures/` (dashed slugs), controller + model tests.
8. Development data: add or update `<model>.yml` in every relevant
   `db/data/<universe_slug>/` directory, update the shared model order/registry, and include
   representative records connected to existing universe/story/character/location/item/event
   records. Do not create a feature-level directory such as `db/data/dialog/`; a future Dialog
   model belongs in `db/data/dark/dialogs.yml` and the corresponding files for other universes.

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
