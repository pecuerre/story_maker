# ADR 0019: Settle the collaboration system's authorization, version, and page-shape foundations

- **Status:** Accepted
- **Date:** 2026-10-02
- **Related:** [`../architecture.md`](../architecture.md),
  [`../conventions.md`](../conventions.md),
  [`../data_model.md`](../data_model.md),
  [`../known_quirks.md`](../known_quirks.md),
  [0005](0005-universe-access-levels.md),
  [0009](0009-transactional-position-maintenance.md)

## Context

The collaboration system is planned as six phases: a universe-level mode setting, a discussion on
every content record, a draft system that intercepts mutations instead of writing them, conflict
detection, a review workflow, and notifications. It is the largest change this application has
attempted, and it touches every model, every mutation controller, and the authorization boundary.

Reading the plan against the current tree turned up three problems that are not implementation
detail. Each one would have been discovered late, and each would have been expensive to undo.

**1. There is no safe way to resolve a polymorphic record reference.** The plan attaches a
discussion to "every content model and tag model" through a `record_type`/`record_id` pair, and
loads the record "through the authorized scope". Two things stand in the way.

`Ability::CONTENT_CLASS_NAMES` (`app/models/ability.rb:11-34`) is a hard-coded list, and a model
missing from it has no CanCan rule at all, so every check against it is denied. That failure is
silent: nothing raises, a control simply never renders. The documented new-model workflow does ask
for registration (`docs/development.md`), which is why the "workflow does not require it" half of
the finding in [`../known_quirks.md`](../known_quirks.md) is stale, but a workflow step is not a
guard. A developer who misses it gets no signal.

More seriously, the content rules are **instance blocks**, and CanCan answers a block rule with
`true` when it is handed the class instead of an instance. A guest asking `authorize! :read,
Character` is therefore allowed. No current route does this, so there is no live bypass — but a
generic polymorphic path is the most natural place in the whole application to write exactly that
line, and `known_quirks.md` already names it as a footgun.

**2. The planned conflict stamp cannot work as written.** The plan stores `base_version` as a
**string** and compares it to `record.updated_at`, which is a `Time`. Those are never equal, so
every single stored change would be reported as a conflict and the conflict-resolution UI would be
unusable rather than merely imperfect.

**3. The planned discussion page contradicts a documented convention.** `conventions.md` requires a
`show` action to be read-only, guest-readable, and to render **no mutation control**, so that
read-only members and guests see identical content. The plan wants `DiscussionsController#show` to
render the record's details, the thread, and a reply form. Related: the page is addressed by
discussion id, so a "Discuss" link has to find-or-create the thread first — and
`find_or_create_discussion` is a **write inside a `GET`**.

## Decision

### A universe has one collaboration mode, and it is owner/admin configuration

`universes.collaboration_mode` is a string, `NOT NULL`, defaulting to `"direct"`, with exactly three
values: `direct`, `wikipedia`, and `github`. `direct` writes straight through. The other two store
changes for the author to apply. The model owns the predicates (`direct?`, `wikipedia?`,
`github?`, `draft_based?`) so that no controller re-derives the mode from a string, and only the
owner or an administrator may change it.

### A polymorphic reference is resolved only through `RecordTarget`

`app/models/record_target.rb` is the single answer to "which record does this reference name", used
by both a controller and a model validation so the two cannot disagree.

- The type is matched against `Ability::CONTENT_CLASS_NAMES` and is **only constantized after that
  match**. An arbitrary constant in a param or a stored row is therefore never loaded.
- The record must resolve to the universe the request has already authorized, through the existing
  `UniverseScopeResolver` walk. Comparing the resolved universe rather than a foreign key is what
  makes this agree with the authorization decision that is about to be made.
- An unknown type, an unknown id, a soft-deleted record, a record in another universe, and a record
  that resolves to no universe at all are one indistinguishable `ActiveRecord::RecordNotFound`. In
  the test environment that renders as **404**. An unknown type is a missing record, not a
  permission decision, so refusing it as forbidden would turn a stored `record_type` into an oracle
  for what exists.
- A registered class is only ever returned as an **instance**. This is what removes the CanCan
  class-subject hole: the caller has a record, so authorizing the class is not an option the API
  offers.

A row that stores both a polymorphic record and its own `universe_id` — a discussion does — is
validated in the model against `RecordTarget`, so the two scopes cannot silently disagree. Neither is
trusted as a foreign key.

### The content registry is inverted, so drift fails loudly

`test/models/ability_test.rb` now requires every persisted model to be in exactly one of three
groups: registered in `CONTENT_CLASS_NAMES`, authorized by another rule group (`Universe` and
`UniverseMembership`), or listed with a stated reason for not being content. A new model therefore
fails the suite until somebody decides which group it belongs to.

The direction matters. An inclusion list fails by being forgotten, silently. An exclusion list fails
by being noticed.

### A discussion thread is a fourth page shape, not a record `show`

The `show` rule is kept, not bent. A conversation page is a new pattern added to `conventions.md`:
a guest-readable read of an append-only thread whose composer is rendered only for a user who may
write, and whose write posts to its own action. Read-only members and guests see an identical
thread; only the composer differs. What stays absolute is that a `show` never *performs* a write.

The find-or-create move out of the `GET` and into a `POST`: the "Discuss" control on a record's
details page submits to `DiscussionsController#create`, which finds or creates the thread and
**redirects** to it. That is the same shape as every other create-then-redirect in the application,
and it means a `GET` never writes.

### A remembered change is stamped with `updated_at`, normalized through `VersionStamp`

`app/models/version_stamp.rb` captures a record's version as a fixed-format UTC string with
microsecond precision, and compares stamps as strings. It exists because the naive comparison is
wrong in a way that fails silently and totally: a `Time` is never equal to the string it was
serialized from.

The comparison is deliberately **conservative**: an unknown or missing base counts as *moved*. A
false conflict is something an author sees and answers; a missed conflict is a silently overwritten
edit, and only one of those two is recoverable.

`updated_at` is the version rather than an integer revision column. See the alternatives below for
why.

### Applying remembered changes reuses the live mutation path

An applier must not write records directly. Where a controller routes a mutation through a service
— ordered and hierarchical collections go through `PositionedResourceOrder` (ADR
[0009](0009-transactional-position-maintenance.md)) — the applier routes it through the same
service, and the model's own validations still run. A direct `record.update(attributes)` would
skip sibling-position normalization, skip the tag-scope validation, and leave menu-count caches and
soft-delete cascades to chance.

This may require extracting the mutation into a service both the controller and the applier call.
That is the intended cost.

## Consequences

### Benefits

- A polymorphic record reference has one audited answer, and it fails as a 404 rather than as a
  permission oracle.
- A forgotten registry entry is a failing test instead of a control that silently never renders.
- Conflict detection compares like with like, so a conflict means the record actually moved.
- A `GET` never writes, and the "no mutation control on a `show`" rule survives intact rather than
  being quietly redefined for one page.

### Costs and constraints

- **Any save counts as a move.** A soft delete bumps `updated_at`, so a delete reads as both "moved"
  and "gone"; the detector has to ask `deleted?` separately to tell those apart. Likewise
  `PositionedResourceOrder`'s sibling normalization uses `update_columns`, which skips timestamps —
  so renumbering is deliberately *not* a version bump. That is now load-bearing rather than
  incidental, and a future change to how positions are written would change conflict behaviour.
- **A false conflict is possible and normal.** Two people editing one record will collide by design.
  The resolution UI has to be genuinely usable, because it is a common path rather than an edge case.
- **Two new classes have no callers yet.** `RecordTarget` and `VersionStamp` are consumed by the
  collaboration phases, not by existing code. They are small, tested, and would otherwise be written
  mid-phase and get the reasoning wrong.
- **One shared scope is validated twice** — in the model and, for the request path, through
  `find!`. That is deliberate: the model check covers every writer including the console, and the
  controller check keeps the failure a 404.
- **ADR 0017 and ADR 0018 were missing from the ADR index** and have been added alongside this one.

### Rejected: an integer revision column (`lock_version`)

Adding a `lock_version` column to the content tables would activate Rails' optimistic locking on
every one of them, which is a better version stamp than a timestamp. It was rejected for now because
it is an application-wide behaviour change and not a collaboration change: every concurrent save
would raise `ActiveRecord::StaleObjectError`, which nothing currently rescues, so two readers editing
one record would turn a 200 into a 500. Turning that into a 409 or a re-render is real work across
roughly twenty controllers, and it is a better decision made on its own evidence rather than as a
side effect of building a draft system. Revisit it if a timestamp turns out to be too coarse.

### Rejected: per-field conflict detection

Kept as the backlog records it: per-record, because a per-field merge needs a field-level diff and a
merge policy per model, and a half-built merge is worse than an honest "you two edited this record".

### Rejected: a `GET` that creates the discussion thread on demand

It would have kept the "Discuss" control a plain link, at the cost of a page load that writes, which
is exactly the class of surprise the `show` rule exists to prevent.

### Rejected: storing the record's class as a free string with no registry check

A `record_type` straight into `constantize` is a loadable-constant injection point. The registry is
the gate, and sharing it with CanCan means the gate is already the thing the authorization decision
is made from.

## Related documentation

- [`../architecture.md`](../architecture.md)
- [`../conventions.md`](../conventions.md)
- [`../data_model.md`](../data_model.md)
- [`../known_quirks.md`](../known_quirks.md)
- [0005](0005-universe-access-levels.md)
- [0009](0009-transactional-position-maintenance.md)