# Universe Maker — Agent Instructions

This file is the short, always-loaded operational guide for coding agents working in this
repository. The detailed domain documentation in [`docs/`](docs/) remains the source of truth;
do not duplicate or contradict it here.

## Project overview

Universe Maker is a Rails application for building and maintaining consistent story universes.
It tracks characters, locations, events, items, relationships, sections, and tags so writers can
manage continuity as a universe grows.

Stack:

- Ruby 3.4.10 and Rails 8.1
- SQLite with database-backed Solid Cache, Solid Queue, and Solid Cable
- Hotwire, Turbo, Stimulus, and import maps
- Bun, Sass, PostCSS, Bootstrap, and Tom Select
- Minitest, RuboCop, Brakeman, Bundler Audit, and Importmap Audit
- Kamal and Thruster for deployment

## Read before changing code

The documentation is a **lookup index, not a book**. It is far too long to read end to end, and
nobody does; a change is prepared by reading the one or two documents that own the subject. Look up
the subject and read its owner:

| Your change is about | Read |
|---|---|
| Request lifecycle, `Current`, callbacks, auth/sessions, access policy, test-env behavior, production boundary, caching | [`docs/architecture.md`](docs/architecture.md) |
| Tables, columns, indexes, constraints, validations, hierarchies, positions, slugs, soft delete, `db/data/**` manifests | [`docs/data_model.md`](docs/data_model.md) |
| Code patterns: models, controllers, routes, the three page patterns, list rows, record details pages, helpers, Stimulus controllers | [`docs/conventions.md`](docs/conventions.md) |
| Colors, tokens, light/dark, typography, shell, responsive behavior, accessibility, the painted treatment of a view | [`docs/visual_design.md`](docs/visual_design.md) |
| **Scenes**, Elements, participation, the Scene filter, the deletion contract | [`docs/features/scenes.md`](docs/features/scenes.md) |
| The tag DSL, taxonomies, the tree and its editor, tagged-record counts | [`docs/features/tags.md`](docs/features/tags.md) |
| Global search and its dropdown | [`docs/features/search.md`](docs/features/search.md) |
| The navbar and both workspace sidebars | [`docs/features/navigation.md`](docs/features/navigation.md) |
| Record photos and the cropper | [`docs/features/photos.md`](docs/features/photos.md) |
| Events and the Timeline algorithm | [`docs/features/events.md`](docs/features/events.md) |
| Translations and writing a translatable string | [`docs/features/i18n.md`](docs/features/i18n.md) |
| The platform Settings page and its two preferences | [`docs/features/settings.md`](docs/features/settings.md) |
| Setup, commands, test suites, CI, demo-data workflow, deployment | [`docs/development.md`](docs/development.md) |
| Verified open oddities, dead code, tech debt — **read before touching shared code** | [`docs/known_quirks.md`](docs/known_quirks.md) |
| A foundational design decision, or a change that makes one necessary | [`docs/adr/`](docs/adr/) |

A feature's rules live in exactly one `docs/features/` document. When a change touches a feature,
read that feature's document rather than searching the whole directory.

Two rules keep that index trustworthy, and both are enforced by `test/docs_test.rb`:

- **One fact, one home.** A fact is stated in the document that owns its subject; every other
  document links to it instead of restating it. Several subjects are currently owned by more than
  one document, which is recorded duplication debt and is exactly how a past fact went stale in one
  place while another place stayed correct. Do not add a second owner.
- **A wrong duplicate is worse than a missing fact.** A confident, well-written, wrong paragraph
  gets acted on; an absent fact sends you to the code. When the docs and the code disagree, the
  code wins and the docs are fixed in the same change.

Add a new ADR for a decision that changes the project's structure, domain boundaries, or long-term
workflow; do not rewrite an accepted ADR to hide its history. When behavior changes, update the
document that owns the subject, in the same change.

## Task intake: clarify before starting

Ask the owner before editing files when a request has one of these two shapes. Do not start work,
and do not guess, until the answer is given.

- **Several unrelated items at once.** "Work on A and B", where A and B do not belong together —
  different models, areas, files, or bugs with no shared code path — is two tasks, not one. Ask:
  _"A and B are not related. Do you want to proceed with both, or only one now?"_ Say which one
  you would do first and why. Being named in the same sentence is not approval to do both.
- **One large item that divides.** When the requested item touches several different areas of the
  project — model, migration, routes, controller, views, JavaScript, tests, demo data, docs — and
  can be delivered in independent pieces, it is large. Ask: _"Do you want to do everything now, or
  do you want to split this task into slices/parts/chunks?"_ Answer with a concrete proposal — the
  pieces you would cut along and what each one contains — rather than an open question.

Do not ask when:

- the items are the same feature or the same code path;
- the request already answers it ("only A", "all of it now", "split it into three", "in this
  order");
- answering costs more than proceeding, because the split or the relation is obvious from the
  repository and the assumption can simply be stated in the hand-off summary.

How to ask:

- Use the question tool with concrete options, one question at a time, short wording.
- Read the code before asking; never ask something the repository answers cheaply. Ask about the
  decision that is genuinely the owner's.
- One answer covers the decision. Do not ask again about the same scope, slicing, or ordering
  later in the same task.
- If the owner says "no questions" or "just do it", treat that as the standing answer for the rest
  of the request and state the assumption you made in the hand-off summary.

This is a different decision from **NOW / LATER / NEVER** in
[`docs/backlog.md`](docs/backlog.md): intake settles the shape of the request, and NOW/LATER/NEVER
then applies to anything extra that turns up during the work.

## Changelog discipline

There are two files, with two different jobs. Keep them that way.

- The root [`CHANGELOG.md`](CHANGELOG.md) is the **short form**: a date-based project history whose
  entries are one or two sentences naming the subject, and **never a paragraph**. The project does
  not currently use release versions, so do not invent a versioning scheme. This is the file agents
  and the owner cite, so its value is that a whole year of history can be skimmed in one sitting.
- [`docs/delivery_history.md`](docs/delivery_history.md) is the **long form**: the reasoning behind a
  change, the alternatives that were rejected, and the verification it went through, plus the quirks
  and tech debt that have been resolved. It is a frozen historical record in the same way an ADR is:
  it may disagree with the code today, and it is never rewritten to match.
- Every change to application code, site/UI behavior, schema or development data, tests,
  documentation, configuration, security, or tooling must add or update a short changelog entry in
  the same work, using the actual calendar date of the change.
- **An entry is one or two sentences, not a paragraph.** This is the rule that breaks first,
  because the reasoning is still fresh and genuinely interesting, and it belongs somewhere else: in
  the `docs/` document that owns the subject if it is a fact about the system, or in
  `docs/delivery_history.md` if it is the reasoning behind a past change. A 60-word ceiling is
  enforced by `test/docs_test.rb`, and it is a symptom, not the definition — two sentences of setup
  before the subject arrives is already too long, and an entry that only says what changed without
  naming the subject is too short. When a change genuinely needs more than one entry, write more
  entries, each one line, rather than one longer entry.
- Write the long form into `docs/delivery_history.md` in the same change **only** when the reasoning
  is worth keeping and no live document owns it. A fact that a document in `docs/` already states
  belongs there, not in the history file — restating it creates the second source of truth that the
  one-fact-one-home rule exists to prevent.
- Group related changes under one date and use a concise label such as `[added]`, `[changed]`,
  `[fixed]`, `[security]`, `[docs]`, `[chore]`, or `[planned]`. Do not rewrite a historical entry's
  meaning — add a new entry when behavior changes again. Reducing an old entry to the length rule
  is the one edit that is always allowed, because it loses nothing the long form does not keep; that
  normalization has now been done twice, for 299 entries on 2026-09-30 and 27 on 2026-10-03.
- Inside a date, each label is its own `###` heading with that label's entries as a plain `- ` list
  below it: the label is named once per date by its heading, never repeated at the start of an entry.
  Keep the headings in the order listed in the changelog's label legend, put each new entry at the
  top of its label group, which is newest-first, and never add a blank line between two entries of
  the same label. A blank line surrounds every heading, and one separates two date sections, so
  every `##` date heading and every `###` label heading has one above and below it.
- When reconstructing the first historical entries, use the repository's Git history and existing
  documentation. Mark future work as `[planned]` rather than describing it as implemented. Do not
  invent detail that the repository does not contain; where an early entry is thin, point at the
  document that owns the fact now.

## Repository quality and DataFactor guidance

The DataFactor report received on 2026-09-25 is a point-in-time snapshot, not a product
specification, an offer guarantee, or a target to game. Read
[`docs/data_factor_guidance.md`](docs/data_factor_guidance.md) and
[`docs/adr/0006-data-factor-quality-guidance.md`](docs/adr/0006-data-factor-quality-guidance.md)
before work involving CI, tests, coverage, dependencies, containers, onboarding, logging,
observability, security, or large shared helpers. Verify every report claim against the current
tree; some findings (notably the existing
`/up` health route and committed `bun.lock`) are already stale.

- Continue with small, real, useful changes. Pair behavior with Minitest coverage in the same
  change, keep the matching docs current, and add the required dated `CHANGELOG.md` entry.
- Prefer security, authorization, data integrity, privacy, and reproducible operations over score
  improvements. The higher-severity findings in [`docs/known_quirks.md`](docs/known_quirks.md)
  take priority over automated quality signals.
- Put deferred quality work in [`docs/backlog.md`](docs/backlog.md) and use the existing
  **NOW / LATER / NEVER** decision. Do not silently add services, dependencies, refactors, release
  tags, or deployment actions just because a report suggests them.
- When a backlog item is finished, add its `CHANGELOG.md` entry and then delete the item, the same
  way a fixed known quirk leaves `docs/known_quirks.md` for the history file. The backlog holds
  pending work only: do not leave "completed" prose, an archive heading, or a status marker behind,
  and do not renumber the remaining items.
- Before starting work on a [`docs/backlog.md`](docs/backlog.md) item, check
  [`docs/known_quirks.md`](docs/known_quirks.md) for a related open quirk — same model, table,
  controller, route, or code path — and ask the owner whether to fix it **NOW** (in the same change,
  with the item's tests and changelog entry) or **LATER** (leave it open). Do not silently bundle
  unrelated fixes into the item, and do not ignore a related quirk once it has been noticed.
- Do not fabricate history, alter author identities, backdate commits, or create cosmetic releases.
  Genuine teammate contributions should retain their own identities. Never commit credentials,
  tokens, DSNs, Rails keys, or real `.env` files. A value-free `.env.example` is documentation,
  not a secret.
- When adding coverage, structured logs, health/metrics, error tracking, or a container setup,
  define redaction, privacy, failure behavior, clean-environment verification, and rollback/stop
  behavior before implementation. Do not assume a clean Brakeman run covers browser or log paths.

## Setup and verification commands

Install the pinned tools and dependencies:

```bash
mise install
bundle install
bun install
bin/rails db:prepare
```

Useful commands:

```bash
bin/rails test                         # all Minitest tests
bin/rails test test/path/to/file_test.rb
bin/rails test:system                  # browser-based smoke tests (requires Chrome)
bin/rubocop                            # Ruby style
bun run check:js                       # Biome lint + Bun unit tests for app/javascript
bin/brakeman --no-pager                # Rails security analysis
bin/bundler-audit                      # vulnerable gems
bin/importmap audit                    # vulnerable JavaScript pins
bun run build:css                      # Sass -> PostCSS/autoprefixer
bun run watch:css                      # CSS watcher
```

Use the smallest relevant test while iterating, then run the full relevant suite before
finishing shared model, controller, routing, authorization, or shared JavaScript changes.
A client-side change is covered by `bun run check:js` first and a `test/system` case for
whatever only a browser can show; both are required before such a change is finished. Report
every check that was not run. The CSS build requires the JavaScript dependencies to be
installed.

Do not run `bin/rails db:restart` or `db:demo:reset` without approval: both are destructive. The
owner has granted standing approval to reset the **local development database** with
`CONFIRM_DB_RESET=1 UNIVERSE=<slug> bin/rails db:demo:reset` when needed to apply a change under
`db/data/**/*.yml`; that approval never extends to production, test, or any real database. The
former task resets schema only; `db:demo:reset` drops, recreates, migrates, and loads one explicitly
named development universe.

## Domain and architecture invariants

- Characters, locations, items, events, relations, ownerships, and their tag taxonomies belong
  to a universe and are shared by that universe's stories.
- Universe access is read/write/admin: public universes allow guest read and signed-in write;
  private universes require owner or membership. A user's access applies to every story and
  component in that universe.
- Sections, scenes, section tags, and scene tags belong directly to a story. Their URLs must
  include the story scope.
- A story becomes current only when explicitly selected or remembered; never fall back to the
  universe's first story.
- Tags are optional on every content model. Do not add default-tag creation or tag presence
  validation without an explicit product decision.
- Preserve the `ApplicationController` before-action order and the `Current` request lifecycle.
  Do not cache `Current` objects across requests.
- Content queries must preserve the correct universe/story scope. Cross-scope checks are
  application-level rules; do not assume SQLite foreign keys enforce them.
- Pass nested route keys explicitly. For example, use
  `universe_story_sections_path(story_id: story)`, not a positional story argument.
- Use `params.expect(...)` for strong parameters.
- Choose the established response pattern deliberately: taxonomy, character, location, item,
  event, and section mutations are JSON-only; universes, stories, relations, ownerships, and
  universe memberships use the HTML redirect/re-render flow. Do not silently mix the two.
- New hierarchical or positioned controllers use the existing concerns and sibling-position
  conventions.
- Use the existing three view patterns: taxonomy tree, flat list with modal, or plain full-page
  form. Add the corresponding helper/controller support rather than inventing a parallel UI
  pattern.

## Migrations and seed data

- Keep migrations schema-only. Do not reference application models or create/update application
  records from a migration.
- Keep one schema-only create migration per persisted model, including HABTM join tables where
  applicable.
- Generate `db/schema.rb` through Rails migrations; do not edit it manually.
- Demo data lives under `db/data/<universe_slug>/`: one subdirectory per universe. The current
  examples are `db/data/dark/` and `db/data/lotr/`; a universe directory contains all data used to
  exercise that universe, including its memberships, stories, sections, tags, world-building
  records, and relationships.
- Do not create a feature directory such as `db/data/dialog/`. If a new `Dialog` model is added,
  its development data belongs in `db/data/dark/dialogs.yml` and in the corresponding file for
  every other universe directory where it should be exercised; update the shared model
  order/registry as well.
- `db/data/` is disposable, development-only data. It may be changed freely to exercise new
  features and relationships; do not put temporary demo records in migrations or production
  seed/deploy paths. `db/seeds.rb` and `db/seeds/` are reserved for production-safe, idempotent
  bootstrap data.
- Treat `db/data/**/*.yml` as the source of truth for demo data, not as files that Rails hot-reloads.
  After **any** YAML addition, deletion, or update, run `UNIVERSE=<slug> bin/rails db:demo:check`
  and then rebuild/reset the local development database so the checked-in data is actually loaded.
  UI-only records are not exported or merged back into YAML and are intentionally lost on reset.
  Never tell the owner that a data change is available in the app until the rebuilt database has
  been queried or otherwise verified.
- When both registered universes should remain available locally, reset one and then create-only
  load the other, for example:
  `CONFIRM_DB_RESET=1 UNIVERSE=dark bin/rails db:demo:reset` followed by
  `UNIVERSE=lotr bin/rails db:demo:load`. A second `db:demo:load` fails if that universe already
  exists; there is no update/merge mode.
- When adding or changing a model, table, association, or persisted field, update every relevant
  `db/data/<universe_slug>/` data file, the shared loader order/registry, and the documentation in
  the same change. Sample data must include representative records connected to existing
  universe/story/character/location/item/event records where those relationships exist; isolated
  rows do not satisfy the feature workflow.
- Treat “create a new model” as a full-stack request: implement the model, schema migration,
  routes/controller, views/helpers/navigation, fixtures and request/model tests, a browser-
  reachable universe data directory, and the relevant docs. The data must provide a known
  development login, scoped URL, and exact load/rebuild command so it can be verified manually.
- The preferred data lifecycle is explicit and environment-guarded: rebuild or reset the disposable
  development database, then load one named universe directory. Do not rely on a production seed
  task to load temporary demo data, and never run a destructive database rebuild without approval.
- The current `db:seed`/`db:restart` wiring is no longer a development-data path. `db:demo:check`,
  `db:demo:load`, and `db:demo:reset` are the explicit development-only entry points; `db:seed`
  and `db:prepare` load production-safe seeds only. Never run a destructive reset without approval.

## Testing conventions

- Add or update tests for behavior changes.
- Use the existing fixtures. Request tests use `sign_in_as` / `sign_out`; system tests use the
  real sign-in form when authentication behavior is part of the scenario. `db/data` is not a test
  fixture source; `config/ci.rb` validates the checked-in development manifests in test mode.
- In the test environment, cross-scope `ActiveRecord::RecordNotFound` requests render as HTTP
  404; assert `assert_response :not_found` rather than expecting an exception.
- Keep route helpers fully qualified in tests when the current request does not provide the
  universe slug.
- Client-side changes follow [ADR 0012](docs/adr/0012-client-side-verification-and-csrf.md): a
  `bun test` case in `test/javascript/` beside the controller, plus a `test/system` case for what
  only a browser can show. Build DOM with DOM APIs — a new `innerHTML`-style sink fails
  `no_html_sink_test.js` unless it is a reviewed, commented exception. A new mutation path also
  belongs in `test/controllers/csrf_mutation_test.rb` or `test/system/csrf_token_test.rb`, because
  the request suite does not verify CSRF tokens.
- Do not claim exhaustive UI coverage from the system-test job: it currently covers the initial
  smoke journeys only.

## Scope, safety, and completion

- Keep changes focused. If another worthwhile improvement is noticed, ask whether it is **NOW**,
  **LATER**, or **NEVER**, following [`docs/backlog.md`](docs/backlog.md).
- Do not silently add refactors, dependency changes, or security fixes outside the requested
  scope.
- Never expose or modify credentials, real `.env` files, Rails keys, or deployment secrets. A
  value-free `.env.example` is allowed only as a documented template with an explicit ignore-file
  exception; never put a real value in it.
- **Never commit or push. The owner makes every commit and every push.** Leave the work in the
  working tree and say plainly which files changed. Do not run `git commit`, `git push`, `git add`,
  `git tag`, `git merge`, `git rebase`, `git checkout --`, or `git stash`: staging, amending, and
  history rewriting are the owner's too, and a `git add`/`git stash` can quietly reshape what they
  are about to commit. Reading history with `git log`/`git diff`/`git status` is expected and
  welcome. Running services, restarting them, and resetting the local development database are
  fine; the repository's history is not the agent's to touch.
- Do not deploy, and do not push, reset, rewrite history, or create release tags.
- Do not edit generated files under `public/assets` or `app/assets/builds` by hand.
- Authorization is defined in `app/models/ability.rb` and enforced by
  `UniverseAuthorization`; do not bypass those checks with controller-specific visibility logic.
  Read [`docs/adr/0005-universe-access-levels.md`](docs/adr/0005-universe-access-levels.md) and test
  public/private read-write-admin boundaries explicitly.
- Before handing off, summarize changed files, behavior, tests/checks run, checks not run, and
  any follow-up work that was deliberately deferred. Work delivered from
  [`docs/backlog.md`](docs/backlog.md) leaves that file: changelog entry first, then the item is
  deleted, so the backlog only ever lists pending work.
