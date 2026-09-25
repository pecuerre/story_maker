# ADR 0009: Maintain ordered collections transactionally with an explicit flat mode

- **Status:** Accepted
- **Date:** 2026-09-25
- **Related:** [`0002`](0002-json-crud-with-stimulus-editors.md), [`0007`](0007-story-owned-scenes-and-elements.md), [`../architecture.md`](../architecture.md), [`../data_model.md`](../data_model.md), [`../universe_maker_conventions.md`](../universe_maker_conventions.md)

## Context

The existing `MaintainsSiblingPositions` controller concern normalized positions for hierarchical
resources, but create and destroy paths were separate operations, normalization was not enclosed
in one transaction, and the implementation assumed every positioned record had a `parent_id`.
The upcoming Story-owned Scene sequence is flat: it has a narrative `position` but no hierarchy
parent. Reusing the old concern unchanged would either corrupt Scene ordering or create a second,
inconsistent ordering implementation.

## Decision

Use one `PositionedResourceOrder` service for positioned mutations. It:

- receives the resource, an already-authorized collection, and the persisted scope owner;
- runs the complete operation in an `ApplicationRecord.transaction` and locks the scope owner;
- supports hierarchical mode (`parent_id` sibling groups) and explicit flat mode;
- creates at a requested position or appends, moves and reparents by `(position, id)`, and
  normalizes the affected group after destroy;
- returns validation failure to the controller without committing a partial normalization.

`MaintainsSiblingPositions` remains the controller-facing adapter. Existing positioned controllers
use its create/update/destroy helpers. Future Scene and Element controllers use flat mode with
their Story or Scene as the scope owner; they do not add `Hierarchical` or a fake `parent_id`.
The development-data registry also distinguishes hierarchical and flat position groups.

SQLite does not provide the same row-lock semantics as a server database. The transaction is the
authoritative local serialization boundary, while the owner lock keeps the algorithm portable.
The current implementation deliberately does not add a transient-unsafe unique position index;
direct SQL/import writes and model-dependent destroys remain separate data-integrity concerns.

## Consequences

### Benefits

- Position changes, reparenting, and destroy normalization commit or roll back together.
- One algorithm serves current hierarchies and the upcoming flat Story sequences.
- Deterministic `(position, id)` ordering and explicit move/create tests protect the Scene contract.
- Controllers do not depend on an instance variable or duplicate normalization code.

### Costs and constraints

- Position maintenance must be invoked through the shared service for application mutations.
- Callers must provide the correct authorized collection and persisted scope owner.
- Raw SQL, direct association manipulation, and some model-dependent destroy paths can still bypass
  the service; those paths need separate validation or maintenance if they become product flows.
- Concurrent behavior on SQLite should be tested when the production database or write volume
  changes.

## Alternatives considered

### Add a separate flat-ordering concern

Rejected because it would duplicate create/move/destroy and transaction semantics and make the
Scene contract diverge from the existing positioned-controller convention.

### Keep the hierarchy-only concern and normalize in each controller

Rejected because it leaves transaction, scope-lock, and destroy behavior inconsistent across
resource types.

### Add a unique position index immediately

Rejected for now because row-by-row reordering can create transient duplicate positions and the
current fixture/import data is disposable. The index can be reconsidered with a database-specific
deferred or two-phase reorder strategy.

## Related documentation

- [`../architecture.md`](../architecture.md)
- [`../data_model.md`](../data_model.md)
- [`../universe_maker_conventions.md`](../universe_maker_conventions.md)
- [`../backlog.md`](../backlog.md)
