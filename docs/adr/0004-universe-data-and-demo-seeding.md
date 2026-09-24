# ADR 0004: Organize disposable data by universe and separate it from production seeds

- **Status:** Accepted
- **Date:** 2026-09-24
- **Related:** [`0003-disposable-schema-and-seed-data.md`](0003-disposable-schema-and-seed-data.md), [`../development.md`](../development.md), [`../data_model.md`](../data_model.md)

## Context

Universe Maker uses `db/data/` to create local universes for browser testing and feature
development. The data is intentionally disposable: the developer may rebuild the database after
schema changes, add records that exercise a new feature, and revise the sample data without
treating it as production history.

The first implementation loads two universe directories from a hardcoded list in `db/seeds.rb`.
That makes the Rails seed command look like a production data contract even though the records are
temporary and create-only. It also leaves no clear convention for where data for a newly introduced
model belongs.

A future model such as `Dialog` may belong to a story or a universe and may relate to characters,
locations, events, sections, and tags. Its development records need to be placed where the rest of
that universe's data can resolve them, without creating a feature-specific parallel dataset.

## Decision

- `db/data/` contains one subdirectory per universe, named by the universe slug. The directory
  contains all data that exists for that universe, including its universe record, stories,
  sections, tags, world-building records, and relationships.
- A new universe is represented by a new `db/data/<universe_slug>/` directory. A new universe is
  not a migration, a production seed, or a feature directory.
- A new model is represented by a file such as `db/data/dark/dialogs.yml` in every universe
  directory where that model should be exercised. The same model may have files in `dark/`,
  `lotr/`, and future universe directories. A directory named after a feature, such as
  `db/data/dialog/`, is not used.
- The loader keeps model dependency order in one shared configuration/registry. Per-universe data
  files may differ in size and content, but they use the same model and reference conventions.
- `db/data/` is development-only and disposable. It must not be loaded by a production deploy or
  used as a data migration. `db/seeds.rb` and `db/seeds/` are reserved for production-safe,
  idempotent bootstrap records.
- Development data is loaded explicitly after a deliberate database rebuild/reset, in a
  development-only task. The existing `db:seed`/`db:restart` coupling is transitional until that
  boundary is implemented.
- Automated tests remain fixture-based. Development data supports manual and browser validation
  and is not the test database's source of truth.
- When a model, table, association, or persisted field changes, the feature work updates the
  relevant per-universe data files, shared loader order, tests, and documentation. A new-model
  request includes the full application stack and connected browser-reachable sample universe data.

## Consequences

### Benefits

- The directory name communicates the domain boundary: one universe means one data directory.
- New model data naturally composes with existing universe, story, and relationship records.
- A feature such as Dialog can be exercised with existing characters, locations, events, and
  sections instead of an isolated placeholder dataset.
- Disposable development data is not confused with production bootstrap data.
- Rebuilding the local database remains a simple and intentional way to handle schema changes.

### Costs and constraints

- Adding a core model may require touching several universe directories, not just one feature file.
- The shared loader order and the files in each universe directory must be kept consistent.
- Sample data needs stable symbolic references and scope-aware relationships; numeric ids are not
  stable across rebuilds.
- The explicit development-only load/reset task still needs to be implemented and guarded against
  production execution.
- A check should detect missing files, broken references, invalid model order, and cross-scope
  associations before a developer tries the browser.

## Alternatives considered

### One subdirectory per feature

Rejected because a Dialog dataset would not naturally contain the rest of the Dark or LOTR
universe, and the same feature would need to duplicate or depend on unrelated data.

### Make every temporary loader idempotent

Rejected as the primary solution. Disposable data is clearer when the supported operation is an
explicit rebuild/reset followed by a load. Production seeds may require idempotence separately;
that does not make every development data loader a production seed.

### Put demo records in data migrations

Rejected because it couples schema history to mutable application data and makes rebuilds harder
to reason about. Migrations remain schema-only.

### Keep `db/data` on the production seed path

Rejected because temporary local records, local credentials, and feature experiments must never
be treated as production bootstrap data.

## Related documentation

- [`0003-disposable-schema-and-seed-data.md`](0003-disposable-schema-and-seed-data.md)
- [`../development.md`](../development.md)
- [`../data_model.md`](../data_model.md)
- [`../universe_maker_conventions.md`](../universe_maker_conventions.md)
- [`../known_quirks.md`](../known_quirks.md)
