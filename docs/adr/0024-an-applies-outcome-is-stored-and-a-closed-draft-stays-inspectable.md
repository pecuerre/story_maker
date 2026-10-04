# ADR 0024: An apply's outcome is stored per change and on the draft, and a closed draft stays inspectable

- **Status:** Accepted
- **Date:** 2026-10-04
- **Related:** [`../conventions.md`](../conventions.md),
  [`../data_model.md`](../data_model.md),
  [`../architecture.md`](../architecture.md),
  [0019](0019-collaboration-foundations.md),
  [0020](0020-remembering-mutations-instead-of-writing-them.md),
  [0021](0021-applying-a-draft-through-the-live-mutation-path.md),
  [0022](0022-an-editing-session-claims-the-browser-and-one-draft-stays-open.md),
  [0023](0023-pending-changes-are-read-from-the-draft-and-drawn-as-badges.md)

## Context

Phase 3 made a conflict a question rather than a report: `apply` renders `drafts/conflicts`, waits for
an answer per change, and writes through `DraftApplier`. What it left untouched is the other half of the
promise. `DraftApplier::Result` knows exactly what was written, what was refused, and why; the
controller turns that into one flash message; and then it is gone.

So an applied draft reads as a list of remembered intentions rather than as a record of what happened.
The drafts list shows a row with a change count, a status badge, and `created_at` as "Remembered …" —
a moment from before anything was applied. There is no way to see when the draft was applied, what it
wrote, what it could not write, or why. An author who closes the tab and comes back to "which of my
edits went through?" has nothing to read.

The draft's own page has the same gap, and ADR 0021 explains why it cannot be closed by inference. An
apply moves every version it writes, so comparing a record's current version with the remembered
`base_version` cannot distinguish "written by this draft" from "changed by somebody else". The page
therefore reports what each change *says* and nothing more — which was right while the flash was the
only report, and stops being right once there is a history to keep.

Two questions follow, and they are not the same question.

**1. Where does the outcome live?** ADR 0021 rejected inferring it after the fact, and rejected an
outcome column on `DraftChange` for the reason ADR 0019 settled: a remembered change is append-only,
because what it said is a statement about one moment and an editable row would let it drift away from
what was actually observed. A `applied_at` column would also have been the wrong shape — a change
that was *not* written would carry the same value as one that was.

**2. Does a closed draft stay inspectable?** It is reachable today, and three documents depend on that:
ADR 0021 says a skipped change "is still listed on the draft's own page, so the author can see what it
said and redo it from the record's own page"; ADR 0019 says rejecting a draft records the decision on
the draft rather than deleting what the change said; and `conventions.md` says the two controls are
rendered only while `Draft#open?`, which is a statement about *controls*, not about reachability. The
alternatives are both worse: hiding the page would make that ADR's promise false, and deleting the
changes would destroy the only record of what the author asked for.

## Decision

### A closed draft stays inspectable, and now says what happened

The draft's own page keeps serving an applied or discarded draft, with its two controls gone, and gains
a **history**: when the draft stopped being actionable, and what the run did to its changes. Each
change's row gains the outcome the apply recorded, beside the values it carries — never instead of
them, because a skipped change is still what the author asked for and is still redoable by hand.

### The outcome is a new row per change, not an attribute of the change

`draft_change_outcomes` holds one row per change per apply: the `state` the run left it in (`written`,
or one of `DraftApplier::SKIP_REASONS`) and the author's `answer` where a conflict was answered.
`state` and `answer` are separate columns because they answer two different questions — a change
answered `"mine"` **is** written, while one answered `"theirs"` is not written and its state is still
the conflict that put it there, so one column would have to say two things at once.

A new row rather than a column on `draft_changes` is what keeps ADR 0019 intact: what a change said is
never rewritten, so what became of it is a second statement. The unique index on `draft_change_id` is
then the rule "one outcome per change" rather than a convention, and it holds because a draft closes on
its first apply — applying twice is already refused (ADR 0021).

### The draft's own row carries the run's moment and tally

`drafts` gains `closed_at` and three counts. `closed_at` is one column rather than one per closing
reason because `status` already says *which* closure it was and this says *when*; a `submitted` draft
is open (ADR 0019), so a review request in flight has no closure moment, which is exactly what the
word is for. `Draft` validates that a draft outside the open statuses has one, so the moment is stored
rather than read off `updated_at` — a timestamp that exists to say a row changed, and the first column
anything writes the next time the draft is touched.

The counts are stored rather than recomputed from the rows because the drafts list prints a history for
every row it renders, and a list that had to group the outcome table first would be the one list in
the application that resolves per row. `DraftApplier` writes them **from the same `Result`** that
writes the rows, inside the same transaction, so the two cannot drift; `test/services/draft_applier_test.rb`
asserts the columns against the rows rather than trusting the derivation.

### One sentence, one helper

The list row and the draft's own page both read `DraftsHelper#draft_history_sentence`. Two surfaces
printing the same fact must not compose it separately: that is how a list and a page come to disagree
about what an apply did. The three counts stay three sentences for the reason the flash's sentences
do — a change dropped on purpose was not skipped, and folding the kept count into either of the others
would report the run as failed when the author simply decided.

## Consequences

### Benefits

- A closed draft answers "when" and "what became of it" without an inference, which is what finding 64
  said was impossible.
- The stored outcomes are the data Phase 5's review workflow needs: a reviewer approving or rejecting a
  submission reads a stored decision rather than a re-run detector.
- The append-only rule survives intact, and the one attempt to infer an outcome (ADR 0021's rejected
  alternative) stays rejected rather than becoming a fallback.
- The tally is a column read rather than a grouped query, so the drafts list keeps its cost at one row
  per draft.

### Costs and constraints

- **The summary and the rows are the same fact stored twice.** That is affordable only because one
  caller writes both from one object inside one transaction, and only while a test asserts the two
  against each other. A second writer of either would break the invariant silently.
- **A failed run leaves no history at all.** The rows and the status change are inside the transaction,
  so an unexpected failure rolls back to a draft that is still open — which is the right outcome for a
  duplicate-write hazard (ADR 0021) and means the history is a record of runs that finished.
- **A discarded draft has a moment and no tally.** "Discarded … Nothing was written." is one sentence
  rather than a summary of three zeroes, and there are no outcome rows to draw.
- **Outcomes are not a re-editable record.** An author who wants a refused change written has to redo
  it by hand, exactly as ADR 0021 decided; what is new is that the refusal now says so.
- **`draft_change_outcomes` is not content.** It is read on a draft's page, which has already resolved
  the draft as its own author's, so `AbilityTest` records it as authorized elsewhere rather than as a
  content class.

### Rejected: hide a closed draft's page

It would make ADR 0021's promise — that a skipped change is still listed on the draft's page — false,
and it would leave the remembered values unreachable, which is the one thing a remembered change is
for. A draft that cannot be acted on is not a draft that cannot be read.

### Rejected: an outcome column on `draft_changes`

It is what ADR 0021 already rejected, for ADR 0019's reason: it makes a remembered change editable,
and a rewritten payload would be applied against a `base_version` captured against something else. One
`applied_at` would also not distinguish a written change from a refused one, which is the only fact the
history is for.

### Rejected: infer the outcome from versions on the way out

The apply moves every version it writes, so a later comparison cannot tell "written by this draft" from
"changed by somebody else". This is ADR 0021's rejected alternative unchanged, restated because the
cheaper-looking option is the one that was already refused.

### Rejected: derive the list's tally from the outcome rows

It would make the list the only page in the application that groups a table per request, and it would
give the same fact a second derivation to keep in step with the first. The draft's own page already
reads the rows; the list reads columns.

## Related documentation

- [`../conventions.md`](../conventions.md)
- [`../data_model.md`](../data_model.md)
- [`../architecture.md`](../architecture.md)
- [0019](0019-collaboration-foundations.md)
- [0021](0021-applying-a-draft-through-the-live-mutation-path.md)
- [0023](0023-pending-changes-are-read-from-the-draft-and-drawn-as-badges.md)
