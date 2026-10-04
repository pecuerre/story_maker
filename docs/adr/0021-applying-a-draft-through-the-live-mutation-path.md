# ADR 0021: Applying a draft writes through the live mutation path, and a change that has moved is reported rather than asked about

- **Status:** Accepted — **annotated 2026-10-04.** Phase 3's resolution page now exists, so a
  conflict is asked about before the write rather than only reported after it: `apply` renders
  `drafts/conflicts` as a `422` and waits for an answer per conflicting change. What this ADR
  decided is untouched and still holds — the draft closes either way, an unanswered conflict is
  reported rather than written, and the run stays one transaction.
- **Superseded in part, 2026-10-04:** the "reported, not resolved" cost below, and the rejected
  *an outcome page for this phase* and *inferring each change's outcome after the fact* alternatives,
  describe what Phase 3 and then
  [0024](0024-an-applies-outcome-is-stored-and-a-closed-draft-stays-inspectable.md) changed. The
  run's outcome **is** now stored — one row per change in `draft_change_outcomes`, and the moment and
  tally on the draft — and a closed draft is still inspectable and says what became of each change.
  The reasoning the storage did not overturn stands: an outcome is a new row rather than an attribute
  of a remembered change, and it is never inferred from a version stamp.
- **The "still raises on a payload it cannot describe" cost below still holds, and is now the last
  resort rather than the answer.** `DraftIntegrity` is asked before a run and refuses such a draft in
  words — naming the change the application cannot read — so the raise no longer escapes a controller
  as a 404 for a draft that is sitting in front of the reader. What it decides is unchanged: a change
  this application cannot describe is refused, not guessed at, and nothing is written. The same
  refusal now runs on a reviewer's approval, because that is the same apply.
- **Date:** 2026-10-03
- **Related:** [`../conventions.md`](../conventions.md),
  [`../architecture.md`](../architecture.md),
  [`../features/navigation.md`](../features/navigation.md),
  [0019](0019-collaboration-foundations.md),
  [0020](0020-remembering-mutations-instead-of-writing-them.md),
  [0009](0009-transactional-position-maintenance.md)

## Context

ADR 0019 settled that an applier must not write records directly: it routes a mutation through the
same service a controller would use, so ordered collections stay contiguous and the model's own
validations stay authoritative. ADR 0020 settled the other end — how a change is remembered, from
inside the action that would have written it, as the submitted attributes plus the one column that
places the record in its scope.

What neither settled is what happens when a stored change is applied days later, by a different
request, against a universe that has moved underneath it. Three questions have to be answered before
any of it can be written, and two of them can go wrong in a way that does not raise.

**1. How does an applier know a model is ordered?** Fifteen of the twenty mutation controllers
maintain sibling positions, and each says so through `MaintainsSiblingPositions` — with the collection
it orders (`@story.sections`, `@scene.scene_elements`, `Current.universe.characters`) and the scope
owner that transaction it. That answer lives in a controller, written against a record the controller
already holds. An applier holding a payload has no such record, and if it keeps its own list of which
models are ordered then there are two lists: the fifteen controllers that declare themselves, and the
fifteen the applier believes in. Nothing would fail. A model added to one and not the other would be
written with a plain `save`, land at the `position` default of 0, and sit inside somebody else's
sibling group — a sequence that looks ordered until somebody moves a row.

**2. What happens to a change whose record has moved?** A remembered `base_version` is the record's
version at the moment the author pressed the button. Between then and the apply, another editor may
have saved the same record. Applying blindly overwrites their work, and nothing anywhere records that
it happened.

**3. What happens to a change that cannot be written at all?** The applier re-runs the live path, so
some changes are refused — a create with a name the model will not accept, a Section whose parent has
been deleted underneath it. There is a `draft_changes` row for each, an append-only record of what the
author asked for, and no way to write it.

The tempting answers to 2 and 3 are the same: refuse the whole apply, roll back, and tell the author
to sort it out. That is atomic and loses nothing. It also has no exit. The author's only controls would
be **Apply again** — which produces exactly the same refusal — and **Discard**, which throws away the
other nineteen changes along with the one that cannot be written. There is no per-change control in
this phase, and no conflict page to send them to, so an unappliable change would leave a draft that can
never be closed.

## Decision

### The applier derives a model's ordering instead of listing it

A model with a `position` column is one whose collection `PositionedResourceOrder` maintains; a model
with a `parent_id` is one whose siblings are scoped by it. Both are read from the model's own columns,
so there is no second list to keep in step. The sibling collection is the owner's association —
`story.sections`, `scene.scene_elements`, `universe.characters` — which is exactly what every
positioned controller's `sibling_collection` and `sibling_position_scope_owner` already return, and
the owner is named by `UniverseScopeResolver.owner_association_for`, the same derivation that chose the
scope column a remembered create stores.

A derivation is only as good as the guard on it, and the guard is
`test/services/draft_applier_test.rb`. It walks **every controller the route set reaches**, reads the
ordering each one declares, and fails when the two answers disagree — in both directions, so a model
that grows a `position` column without a controller is caught as surely as a controller whose model
lost one. That is the same shape as `test/models/ability_test.rb`'s content registry: an inclusion list
fails by being forgotten silently, so the test reads the other list instead of being given one.

### A change whose record has moved is reported, and the rest of the draft is still written

`VersionStamp.changed?` compares the stored version with the record's version now, and counts an
unknown base as moved. A create names no record and cannot conflict. When a change cannot be written —
because the record has moved, because the record is gone, because the payload's scope cannot be
resolved inside this universe, or because the live path refused it — it is reported in the result and
the remaining changes are written.

**The draft becomes `applied` either way.** This is the load-bearing part of the decision, and it is
forced by what a remembered create is: it names no record, so applying the same draft twice would write
the author a second copy of it, and `PositionedResourceOrder` would place that copy happily. Leaving a
partly-applied draft open would make that a reachable accident rather than an unlikely one. So an apply
always closes its draft, and a change it could not write is left behind as a row the author can still
read on the draft's page and redo by hand.

That is a real cost and the honest way to state it is that a conflict in this phase is **reported, not
resolved**. Phase 3 replaces the report with the resolution page, and the flash sentence that carries
the counts goes with it.

### The whole run is one transaction, and the draft's status change is inside it

A skipped change is not a failure, so it does not roll anything back. An *unexpected* failure — a
payload naming an attribute no column holds, say — must not leave a universe that is partly written
behind a draft that still looks applyable, which is the same duplicate-create hazard by another route.
One transaction around the whole run and the `status` change means such a failure leaves the draft
exactly as it was, and the author can discard it.

`PositionedResourceOrder` opens its own `requires_new: true` transaction, so each change commits to a
savepoint inside this one and a refused write rolls back to its savepoint rather than the run. The scope
owner's row lock is then held until the run commits, which serializes two applies in one universe.

### A create's stored scope is resolved, not trusted

`DraftChange` validates the universe of a record it *names*, but a create names none, so the scope
column in its payload is the only thing that says where the record goes. It is resolved through the
draft's own universe — `universe.stories.find_by`, or the universe itself — and a payload whose scope
column names something that is not there reports as unplaceable. A universe-scoped payload whose
`universe_id` contradicts the draft's universe is refused for the same reason: writing it into the
draft's universe anyway would be answering a different question from the one the author asked.

Everything else in the payload is left to the model's own validations, which are the authority. A
cross-universe tag assignment, a presence link pointing at another universe's Character, and a Relation
between two different universes are all refused by the model, not by a second opinion here.

## Consequences

### Benefits

- An ordered sequence cannot be left with a gap by an apply, and the test that holds the derivation
  reads the controllers rather than a list, so it cannot be satisfied by updating the list.
- A conflict never overwrites somebody else's edit silently. `VersionStamp`'s conservative direction
  (an unknown base counts as moved) means the cost of the rule is a change that is reported rather than
  written.
- The apply always terminates. There is no state an author can reach in which a draft can neither be
  applied nor closed.
- One writer owns the fact "this model is ordered" — the model's own columns — and three callers read
  it: the remembering path choosing the column to store, the applier choosing the collection to order,
  and a draft's page telling plumbing from something it can print.

### Costs and constraints

- **A reported conflict is not a resolved one.** The author's remembered values stay readable on the
  draft's page and have to be redone by hand, because nothing stores an outcome per change and a
  remembered change is append-only (ADR 0019). Phase 3 is what removes this, and the flash copy that
  reports it is written to be replaced.
- **A draft's page cannot say whether a change was written.** It reports what each change says and
  which record it is about; the version stamp it could compare against has moved by the apply itself,
  so inferring an outcome from it would be a second answer about the same record. The outcome is
  reported once, in the flash that follows the apply.
- **The scope column is hidden from a draft's page.** A remembered create's `story_id` is a number the
  reader cannot name, and the page is already inside the universe it would place the record in;
  resolving it to a name would mean a lookup per change to say something the author already knows.
- **The applier still raises on a payload it cannot describe.** That is deliberate — an unknown
  attribute is a defect rather than something an author typed — and the transaction is what makes
  raising safe.
- **Two applies can still open two drafts.** That is the accepted cost of the missing unique index on
  `[user_id, universe_id]` (ADR 0019), and applying both writes both sets of changes rather than
  refusing either.

### Rejected: refusing the whole apply when one change cannot be written

Atomic, lossless, and with no exit. The author reaches a draft that cannot be applied, cannot be
partly applied, and cannot be closed without discarding everything in it, because the per-change
control that would let them drop the one bad change is Phase 3's work. Delivering an apply that can
strand a draft is worse than delivering one that reports what it left behind.

### Rejected: a registry of ordered models in the applier

Readable, and it is a second list. It would drift from the controllers silently — a new ordered
controller would be applied with a plain `save` and leave a gap — and the test that holds it would have
to be given the list to compare against, which is the same omission the guard is supposed to catch.

### Rejected: inferring each change's outcome after the fact

`DraftChange` could carry an `applied_at`, or the page could compare the record's current version with
the remembered one. Both are wrong: an apply moves every version it writes, so a comparison cannot
distinguish "written by this draft" from "changed by somebody else", and a column would contradict the
append-only decision ADR 0019 settled.

### Rejected: an outcome page for this phase

Storing what happened per change is the Phase 3 conflict resolution page's data model, built twice.
This phase reports the outcome in the flash that follows the apply and keeps the draft's page to
stating what the changes say.

## Related documentation

- [`../conventions.md`](../conventions.md)
- [`../architecture.md`](../architecture.md)
- [`../features/navigation.md`](../features/navigation.md)
- [0019](0019-collaboration-foundations.md)
- [0020](0020-remembering-mutations-instead-of-writing-them.md)
