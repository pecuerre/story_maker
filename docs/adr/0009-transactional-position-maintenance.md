# ADR 0009: Maintain ordered collections transactionally with an explicit flat mode

- **Status:** Accepted — **annotated 2026-10-06.** What this ADR decided is untouched and still holds:
  the service is the application path for an ordered mutation, and the transaction that locks the
  scope owner is the only place that does. One cost below has since narrowed: *model-dependent
  destroy paths* no longer bypass the service by leaving a gap. `OrderedSequence` renumbers a whole
  sibling group on `after_destroy`, `after_soft_delete`, and `after_restore` for all fifteen
  positioned models, so a direct write that runs the model repairs itself. The other half of that
  cost — raw SQL, `update_column`, and an import naming its own `position` — is repaired by running
  a command rather than by a callback, because no callback fires for a statement that skips the
  model: `bin/rails positions:normalize` walks every positioned model and renumbers each sibling
  group, reporting every move, and `bin/rails positions:status` walks the same models and groups
  without writing, so the step being forgotten is something a script can notice. What remains of the
  cost is that two such writes racing each other are still not serialized, which is the SQLite
  row-lock limitation this ADR already accepted. See
  [`../data_model.md`](../data_model.md#hierarchies--positions) for the rule as it stands.
- **Date:** 2026-09-25
- **Related:** [`0002`](0002-json-crud-with-stimulus-editors.md), [`0007`](0007-story-owned-scenes-and-elements.md), [`../architecture.md`](../architecture.md), [`../data_model.md`](../data_model.md), [`../conventions.md`](../conventions.md)

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
- [`../conventions.md`](../conventions.md)
- [`../backlog.md`](../backlog.md)
