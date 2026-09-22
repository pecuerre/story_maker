# Development Guide

Commands, tests, seeding, CI, deployment and a "adding a new model" checklist.
Conventions: [universe_maker_conventions.md](universe_maker_conventions.md) ·
Schema: [data_model.md](data_model.md) · Gotchas: [known_quirks.md](known_quirks.md).

## Prerequisites & running

- Ruby **3.4.10** via [mise](https://mise.jdx.dev) (`mise.toml`); `bundle install`.
- **bun** for CSS/JS assets: `bun install` (both `bun.lock` and a stale `yarn.lock` exist —
  prefer **bun**, see [known_quirks.md](known_quirks.md)).
- Setup & run:

```bash
bin/rails db:prepare          # create + migrate + seed (first run)
bin/rails server              # http://localhost:3000
bin/rails console
bun run watch:css             # rebuild CSS on .scss changes (Procfile.dev: foreman start)
```

- CSS pipeline: `app/assets/stylesheets/application.bootstrap.scss` → sass → postcss/autoprefixer
  → `app/assets/builds/application.css` (Propshaft serves it). The build also runs automatically
  before the test suite, so tests require `node_modules` + bun.

## Test suite (Minitest)

```bash
bin/rails test                # models, controllers, helpers (runs in parallel, all fixtures)
bin/rails test test/models/section_test.rb
bin/rails test:system         # currently empty — CI still runs the job
```

Layout:
- `test/controllers`, `test/models` — the real coverage; `test/helpers`, `test/integration`,
  `test/mailers/previews` are effectively empty.
- `test/fixtures/*.yml` — loaded for **all** tests (`fixtures :all`): users, universes,
  **stories** (`story_one`, `story_alt` in universe one, `story_two` in universe two), sections
  (both belong to `story_one`), all content + tag fixtures.
- Sign in with `sign_in_as(users(:user_one))` /
  `sign_out` from `test/test_helpers/session_test_helper.rb`.
- Route helpers in tests must be fully qualified:
  `universe_story_sections_url(universe_slug: @universe.slug, story_id: @story)`.
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

## Seeding / demo data

`bin/rails db:seed` (`db/seeds.rb`) does two things:

1. loads every `db/seeds/**/*.rb` (directory currently empty);
2. loads the demo universes from a **hardcoded list** `["dark", "lotr"]`:
   - `db/data/dark/dark.rb` — generic YAML loader. It walks `models_in_order`
     (User → Universe → **Story** → SectionTag → Section → … → Event), reads
     `db/data/<model>.yml`, resolves reference strings `"Model.some_slug"` with
     `Model.find_by(slug: …)` (arrays too; a `"Tag.*"` reference also records the tag slug for
     the colored output). References therefore need the target model to have a **slug column**
     (this is why `stories.slug` exists).
   - `db/data/lotr/lotr.rb` — plain Ruby: user, universe, **story** ("The Lord of the Rings"),
     section tags, three book sections.

Other notes:
- Seeding is **not idempotent** (`create!` each run) — re-running duplicates data.
- `bin/rails db:restart` (`lib/tasks/db.rake`) = drop + create + migrate + seed.
- Tests do **not** use seeds; they use fixtures only.

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

| Job | Command |
|---|---|
| `scan_ruby` | `bin/brakeman --no-pager`, `bin/bundler-audit` |
| `scan_js` | `bin/importmap audit` |
| `lint` | `bin/rubocop -f github` (cached) |
| `test` | `bin/rails db:test:prepare test` |
| `system-test` | `bin/rails db:test:prepare test:system` (no system tests yet; uploads screenshots on failure) |

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

1. Migration in `db/migrate/` — `universe_id` FK (+ `parent_id`/`position`/`slug` if it is a
   hierarchical/positioned model). Update `db/schema.rb` via `bin/rails db:migrate`.
2. Model in `app/models/` — `include HasSlug` (+ `Hierarchical`, `HasManyTags`,
   `has_many_tags :foo_tag` / inverse `has_many_tagd :foo`, `HasColor` for tags), `belongs_to
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
6. Sidebar link in `app/views/layouts/_left_sidebar.html.erb` (`icon_text_count` + `active_if`).
7. Fixtures in `test/fixtures/` (dashed slugs), controller + model tests.
8. Demo data: YAML entry handled by the loader (add the model to `models_in_order` in
   `db/data/<name>/<name>.rb`) or Ruby seed.
