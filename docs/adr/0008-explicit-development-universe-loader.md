# ADR 0008: Use an explicit registry-driven development universe loader

- **Status:** Accepted
- **Date:** 2026-09-25
- **Related:** [`0003-disposable-schema-and-seed-data.md`](0003-disposable-schema-and-seed-data.md), [`0004-universe-data-and-demo-seeding.md`](0004-universe-data-and-demo-seeding.md), [`../development.md`](../development.md), [`../data_model.md`](../data_model.md), [`../backlog.md`](../backlog.md)

## Context

`db/data/` is disposable development data, not production bootstrap data. The previous lifecycle
loaded Dark and LOTR from a hard-coded list in `db/seeds.rb`; Dark and LOTR had separate loaders;
missing files, unknown files, forward references, and cross-scope data were not checked as one
catalog; and `db:restart` could drop a database without an environment or acknowledgement guard.
That made the development-data boundary unsafe to reason about and allowed a fresh `db:prepare` or
container startup to load temporary records unintentionally.

The project already has a shared model order and association validators, but those rules need a
single development-data entry point that can validate a complete universe before persistence. This
ADR implements the target described by ADR 0004 and supersedes that ADR's transitional execution
wiring only; it does not change the disposable-data or schema-only migration boundary.

## Decision

### Registry and data format

`Development::UniverseDataRegistry` is the authoritative registry for:

- the current model dependency order;
- the YAML filename for each model;
- whether a model is story/universe scoped and whether it has sibling positions; and
- the supported universe directory slugs.

The registry covers `User`, `Universe`, `UniverseMembership`, `Story`, the story-scoped section
models, all current universe-scoped world models/tags, and excludes runtime-only `Session` data.
Every registered universe directory must provide every registered YAML file. An intentionally
unused model is represented by `[]`, not by a missing file or an unregistered feature file.

All universes use YAML with stable `Model.slug` references. The loader builds an in-memory index,
resolves only association-valued references, rejects duplicate/missing/forward references, checks
known attributes, and validates universe/story scope before writing. It does not call global
class-level slug finders for data loading, does not accept raw foreign-key IDs, and does not log
password values. Hierarchical records are assigned contiguous sibling positions after creation:
groups with no explicit positions use YAML/file order, while groups that provide positions must
provide a unique non-negative integer for every sibling.

### Explicit tasks and environment boundary

The supported commands are:

```bash
UNIVERSE=dark bin/rails db:demo:check
UNIVERSE=dark bin/rails db:demo:load
CONFIRM_DB_RESET=1 UNIVERSE=dark bin/rails db:demo:reset
```

`db:demo:check` is read-only and allowed in development or test. `db:demo:load` and
`db:demo:reset` are allowed only in development. `load` is create-only and refuses an existing
target universe. The service's environment override is accepted only by the test suite; production
callers cannot make a write-capable loader appear to be running in development. `reset` requires
the explicit confirmation value, drops/creates/migrates the
database, and loads only the named universe; it never invokes `db:seed`.

`db/seeds.rb` loads only production-safe files under `db/seeds/`. `db:prepare` and deployment
startup therefore do not load `db/data/`. The legacy `db:restart` name remains only as a guarded
schema-only reset and also requires development plus confirmation; it does not load demo data.

## Consequences

### Benefits

- Development data has one auditable model order and one file contract for every universe.
- Checks fail before persistence with file/row context instead of leaving a partial create-only load.
- Production/deployment seed paths cannot accidentally load temporary users or universe records.
- One named universe can be loaded for browser work without loading the other sample universe.
- The loader tests can validate checked-in YAML without making development data a fixture source.

### Costs and constraints

- Adding a persisted model requires updating the registry and every registered universe directory.
- The loader is intentionally create-only; changing demo data means using the explicit reset task.
- The current Dark/LOTR synthetic passwords remain a separate security-hygiene backlog item.
- The loader normalizes current hierarchy positions but does not solve application-level sibling
  position concurrency concerns for future flat Scene/Element sequences.

## Alternatives considered

### Keep hard-coded per-universe Ruby loaders

Rejected because model order, file validation, reference resolution, and scope behavior would
remain duplicated and could drift.

### Let `db:seed` load development data when the environment is development

Rejected because environment detection in a seed file is too easy to bypass through deploy-time
commands, containers, and task composition. The boundary is now explicit at the task/service edge.

### Make development data idempotent

Rejected as the primary solution. Disposable universes are supported by an explicit reset followed
by a create-only load; production-safe seeds remain the place for idempotent bootstrap records.

### Discover and execute arbitrary files in `db/data/`

Rejected because it permits unreviewed code/data entry points. The registry must explicitly list
supported universes and model files.

## Related documentation

- [`0003-disposable-schema-and-seed-data.md`](0003-disposable-schema-and-seed-data.md)
- [`0004-universe-data-and-demo-seeding.md`](0004-universe-data-and-demo-seeding.md)
- [`../development.md`](../development.md)
- [`../data_model.md`](../data_model.md)
- [`../universe_maker_conventions.md`](../universe_maker_conventions.md)
- [`../known_quirks.md`](../known_quirks.md)
- [`../backlog.md`](../backlog.md)
