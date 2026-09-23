# ADR 0003: Keep migrations schema-only and rebuild demo data from `db/data/`

- **Status:** Accepted
- **Date:** 2026-09-24
- **Related:** [`../development.md`](../development.md), [`../data_model.md`](../data_model.md)

## Context

Universe Maker's development and demo database is disposable. The project keeps schema creation
in migrations and keeps the sample universes in `db/data/`, loaded by the seed process. Tests use
fixtures rather than the demo seed data.

Mixing application records or model logic into migrations would make schema changes depend on
application code and would make disposable database reconstruction harder to reason about. A
second seed run is also not currently safe because the demo loaders are not idempotent.

## Decision

Keep migrations schema-only:

- migrations define tables, columns, indexes, and foreign keys;
- migrations do not reference application models;
- migrations do not create or update application records;
- `db/schema.rb` is generated through Rails and is not edited manually.

Keep demo data under `db/data/` and reconstruct it through the documented seed loaders. Use
`bin/rails db:restart` when a deliberate disposable database rebuild is needed, after confirming
that development data may be discarded. Keep tests independent of seeds by using fixtures.

## Consequences

### Benefits

- Schema history remains understandable independently of application code.
- The database can be rebuilt from migrations and checked-in demo data.
- Tests remain deterministic and do not depend on a particular demo dataset.
- Refactoring an early create migration can be validated by rebuilding the disposable database.

### Costs and constraints

- Re-running the current seed process is not guaranteed to be idempotent.
- Data-shape changes may require updates to both the schema and the relevant `db/data/` loader
  or YAML files.
- Developers must distinguish schema work from seed-data work and avoid mixing them in a
  migration.

## Alternatives considered

### Put demo records in data migrations

Rejected because it would couple schema history to application records and make the disposable
rebuild workflow less clear.

### Treat the production database as the source of truth

Rejected because this repository is designed around a disposable SQLite development/test setup
and checked-in demo data.

## Related documentation

- [`../development.md`](../development.md)
- [`../data_model.md`](../data_model.md)
- [`../architecture.md`](../architecture.md)
