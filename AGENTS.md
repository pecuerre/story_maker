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

Read the relevant documents before making a non-trivial change:

1. [`docs/architecture.md`](docs/architecture.md)
2. [`docs/data_model.md`](docs/data_model.md)
3. [`docs/universe_maker_conventions.md`](docs/universe_maker_conventions.md)
4. [`docs/known_quirks.md`](docs/known_quirks.md)
5. [`docs/development.md`](docs/development.md) for setup, tests, CI, or deployment

Read [`docs/adr/`](docs/adr/) when a change depends on a foundational design decision. Add a
new ADR for a decision that changes the project's structure, domain boundaries, or long-term
workflow; do not rewrite an accepted ADR to hide its history.

When behavior changes, update the matching document in `docs/` in the same change.

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
bin/brakeman --no-pager                # Rails security analysis
bin/bundler-audit                      # vulnerable gems
bin/importmap audit                    # vulnerable JavaScript pins
bun run build:css                      # Sass -> PostCSS/autoprefixer
bun run watch:css                      # CSS watcher
```

Use the smallest relevant test while iterating, then run the full relevant suite before
finishing shared model, controller, routing, authorization, or shared JavaScript changes.
Report every check that was not run. The CSS build requires the JavaScript dependencies to be
installed.

Do not run `bin/rails db:restart` without approval: it drops, recreates, migrates, and seeds the
development database.

## Domain and architecture invariants

- Characters, locations, items, events, relations, ownerships, and their tag taxonomies belong
  to a universe and are shared by that universe's stories.
- Sections and section tags belong directly to a story. A section URL must include its story
  scope.
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
  event, and section mutations are JSON-only; universes, stories, relations, and ownerships use
  the HTML redirect/re-render flow. Do not silently mix the two.
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
- Demo data is reconstructed from `db/data/` by the seed loaders. Tests use fixtures, not seeds.
- Treat the current seed process as non-idempotent. Do not add a data migration or assume a
  second `db:seed` is safe without an explicit decision.

## Testing conventions

- Add or update tests for behavior changes.
- Use the existing fixtures. Request tests use `sign_in_as` / `sign_out`; system tests use the
  real sign-in form when authentication behavior is part of the scenario.
- In the test environment, cross-scope `ActiveRecord::RecordNotFound` requests render as HTTP
  404; assert `assert_response :not_found` rather than expecting an exception.
- Keep route helpers fully qualified in tests when the current request does not provide the
  universe slug.
- Do not claim exhaustive UI coverage from the system-test job: it currently covers the initial
  smoke journeys only.

## Scope, safety, and completion

- Keep changes focused. If another worthwhile improvement is noticed, ask whether it is **NOW**,
  **LATER**, or **NEVER**, following [`docs/backlog.md`](docs/backlog.md).
- Do not silently add refactors, dependency changes, or security fixes outside the requested
  scope.
- Never expose or modify credentials, `.env` files, Rails keys, or deployment secrets.
- Do not push, reset, rewrite history, or deploy without explicit approval.
- Do not edit generated files under `public/assets` or `app/assets/builds` by hand.
- Do not assume the installed `cancancan` gem provides authorization; read
  [`docs/known_quirks.md`](docs/known_quirks.md) and test access boundaries explicitly.
- Before handing off, summarize changed files, behavior, tests/checks run, checks not run, and
  any follow-up work that was deliberately deferred.
