# ADR 0036: A remembered change can be dropped before its draft is applied

- **Status:** Accepted
- **Date:** 2026-10-25
- **Related:** [`../conventions.md`](../conventions.md),
  [`../architecture.md`](../architecture.md),
  [`../data_model.md`](../data_model.md),
  [0019](0019-collaboration-foundations.md),
  [0020](0020-remembering-mutations-instead-of-writing-them.md),
  [0021](0021-applying-a-draft-through-the-live-mutation-path.md),
  [0022](0022-an-editing-session-claims-the-browser-and-one-draft-stays-open.md),
  [0024](0024-an-applies-outcome-is-stored-and-a-closed-draft-stays-inspectable.md),
  [0027](0027-a-draft-is-one-line-of-work.md)

## Context

A draft remembers every mutation its author makes, and one change it cannot describe refuses the
whole run. `DraftIntegrity` asks before an apply starts, names the change, and writes nothing — the
answer [ADR 0021](0021-applying-a-draft-through-the-live-mutation-path.md) settled. The refusal is
honest, and the page behind it is readable: the change is still listed, and nothing is hidden.

What it did not have was an exit that keeps the other work. The author's only control was
**Discard**, which closes the draft and throws away every other remembered change with it. A draft
with one corrupt row among nineteen could not be applied at all, and the state is reachable without
anybody editing a database by hand: a model renamed under the demo data, or a loader from an older
version, writes a payload this application can no longer read.

Two facts about the existing design make the gap narrower than it first looks and sharper where it
remains:

- A change that has **moved** or been **deleted** already has a per-change answer. The conflict page
  offers **Apply theirs**, which leaves the record as it is and drops the author's change; the rest of
  the draft is written. So the "drop one change and apply the rest" journey already exists for a
  conflict.
- A change the applier cannot **interpret** never reaches that page. There is no conflict to choose
  between, so the conflict page is the wrong shape, and the generic apply refusal is what the author
  meets.

ADR 0021 deferred the per-change control while it was one phase's work. This ADR delivers it for the
state that cannot use the conflict page, and states the rule for every remembered change so there is
not a second kind of exit for damage alone.

## Decision

### A working draft's author can drop one change, and it is a `DELETE` on that change

`DraftChangesController#destroy` is mounted under the draft that owns the change:

```text
DELETE /u/:universe_slug/drafts/:draft_id/changes/:id
```

It is the only `DELETE` on the drafts route, and the only draft action that removes a row rather than
moving the draft's status. The control is a `button_to` on each row of `drafts/_change`, with a
confirmation, because a drop cannot be undone.

### Dropping deletes the change; it does not mark it, rewrite it, or store an outcome

A remembered change is append-only in the sense ADR 0019 settled: **what it says is never rewritten**,
because a new payload would still carry a `base_version` captured against the values it originally
described. Dropping does not rewrite anything — it removes the author's statement of intent before
any of it became a record. That is the same kind of act as discarding a draft, not the same kind of
act as editing a change, and it is why the row is deleted rather than given a `dropped` state.

No `DraftChangeOutcome` is written. An outcome belongs to an **apply run** (ADR 0024), and a dropped
change was never part of one; writing an outcome outside a run would make the draft's tally describe
work no apply did. The draft's history therefore does not mention a dropped change, and the row is
absent from every surface that lists the draft's changes.

The change's own `has_one :outcome` is `dependent: :destroy`, which matters only for data that
already contradicts this decision: an open draft holds no outcomes, so the ordinary drop cannot leave
one behind.

### Only a working draft can lose a change

The three statuses each answer differently, and the page shows the control only where the controller
would honour it:

- **`draft`** — the author may drop one change. That includes the last one, which leaves an empty but
  still-open draft; the page already has an empty state, and dropping one change is not the author
  discarding their line of work.
- **`submitted`** — refused. A `github` draft is with a reviewer, and the mode's promise is that what
  was reviewed is what was submitted. Changing the set underneath the reviewer is the same hazard
  that made `DraftMutation` refuse new changes while a draft is submitted. The author's exits are to
  wait for a decision or to withdraw the draft by discarding it; a rejection hands it back to edit,
  and then a change can be dropped.
- **`applied` / `discarded`** — refused, with the same `drafts.flash.closed` sentence `apply` and
  `discard` already use. A closed draft is history.

The refusal is an action check, not only a missing button: a stale page or a hand-made request gets
the sentence rather than a silent change to a draft that cannot be edited.

### The change is reached through its draft, and the draft through its author

`@draft` is the reader's own draft inside the universe the request has already authorized, and
`@change` is looked up on that draft's association. Another author's draft, another universe's
draft, and a valid change id belonging to a different draft are one **404**, the answer
`DraftsController` gives for the same reason: pending work is not a permission decision and must not
be an oracle for what somebody else is writing.

### The damaged-draft refusal is unchanged; the way out is the new control

`DraftIntegrity` still refuses the run, still names every change it cannot read, and still writes
nothing. What changed is the notice's sentence: it now says to drop the changes it names and apply
the rest. The control changes the author's options, not the applier's rule — a change the application
cannot describe is never guessed at, and the draft is never partly applied by the refusal itself.

## Consequences

### Benefits

- A damaged draft is no longer a dead end whose only exit is losing the whole draft. Both
  collaboration modes can recover one, because the author's own page carries the control.
- The general "drop one remembered change and apply the rest" answer exists where it was missing. A
  conflict still offers its own version (`theirs`), which is the right answer at the moment the record
  has moved; dropping is the answer before an apply and for a change that has no conflict to answer.
- The rule is one sentence rather than a special case for damage: a working draft's author may
  withdraw any one of its changes.
- The compact set of surfaces stays compact. `drafts/_change` is still the only row partial; the drop
  control is rendered only when the author's own page passes the `draft` local, so the change history,
  a reviewer's page, and the collaborators pages cannot inherit a control that would be refused.

### Costs and constraints

- **A dropped change leaves no audit trail.** It was pending work and never a record, and the history
  records runs rather than withdrawals. An author who drops the wrong change has no undo.
- **Deletion sits beside an append-only rule, and the distinction has to be understood.** A future
  reader who sees `DraftChange` refuse updates and allow this `DELETE` may think one of them is a
  bug. The rule is what it says: a change's *content* is never rewritten; the author may withdraw the
  change itself while it is still pending.
- **A drop counts as a mutation** for the universe's mutation budget, like every other write. It is
  one row and one request, but it is not free.
- **A submitted draft's author cannot use it.** That is the point, but it means the two modes have
  different recovery paths: a `wikipedia` author drops and re-applies, while a `github` author asks
  for a rejection or withdraws the whole draft.
- **The empty open draft is reachable on purpose.** A draft whose last change was dropped is a draft
  with nothing waiting; it is not closed automatically because the author has not decided to close
  their line of work.

### Rejected: a `dropped` state or tombstone on the change

It would keep the row for an audit, at the cost of a second kind of remembered change that every
reader — the applier, the preview, the panel, the history — has to filter out or explain. The state
that matters is "the author withdrew this before it was applied", which is the absence of the row.
If an audit of withdrawals is ever wanted, it is a new table and a product decision, not a column
this feature invents.

### Rejected: only offering the control on a damaged change

It would answer the reported dead end and nothing else, and it would put a condition on the page that
does not describe the model: a change is either pending or not. It would also make "drop a change I
no longer want" a feature that appears only after the draft has a defect. The general control is
smaller to explain and no more code.

### Rejected: reusing the conflict page as the drop page

A damaged change has no conflict row to draw: the page's whole layout compares the author's values
with what is currently there, and there is nothing to compare a payload this application cannot read
against. Making it a third kind of conflict would put a question on a page whose contract is a
choice between two answers.

### Rejected: allowing a submitted draft to drop a change

It reopens the gap the existing submission freeze closes: a reviewer would be reading a set that
changed after the submission message described it. Withdrawing the draft is the author's whole-draft
version of the same act, and a rejection returns the draft to a state where this control is available.

### Rejected: closing a draft when its last change is dropped

Discard already exists, and it says what it does. Silently closing a draft because a change was
removed would make the last drop mean something different from every other drop, and the author
would find their editing session over because they tidied up.

### Rejected: dropping a change from the conflict page as a third button

The conflict page already has **Apply theirs**, which drops the change and applies the rest in the
same run. A drop button beside it would be a second way to leave the record alone, and the two would
need a sentence explaining the difference for a page whose value is that its choice is clear.

## Related documentation

- [`../conventions.md`](../conventions.md) — the drafts page, its controls, and the per-change drop
- [`../architecture.md`](../architecture.md) — the collaboration request surface
- [`../data_model.md`](../data_model.md) — `draft_changes` and `draft_change_outcomes`
- [0019](0019-collaboration-foundations.md)
- [0020](0020-remembering-mutations-instead-of-writing-them.md)
- [0021](0021-applying-a-draft-through-the-live-mutation-path.md)
- [0022](0022-an-editing-session-claims-the-browser-and-one-draft-stays-open.md)
- [0024](0024-an-applies-outcome-is-stored-and-a-closed-draft-stays-inspectable.md)
- [0027](0027-a-draft-is-one-line-of-work.md)
