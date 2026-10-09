# ADR 0027: A draft is one line of work; there is no branch, no fork, and no merge

- **Status:** Accepted
- **Date:** 2026-10-10
- **Related:** [`../conventions.md`](../conventions.md),
  [`../known_quirks.md`](../known_quirks.md),
  [`../delivery_history.md`](../delivery_history.md),
  [0019](0019-collaboration-foundations.md),
  [0020](0020-remembering-mutations-instead-of-writing-them.md),
  [0021](0021-applying-a-draft-through-the-live-mutation-path.md),
  [0022](0022-an-editing-session-claims-the-browser-and-one-draft-stays-open.md),
  [0023](0023-pending-changes-are-read-from-the-draft-and-drawn-as-badges.md)

## Context

The collaboration work delivered a draft system that remembers a mutation instead of writing it, and
it left one rule unexplained. One open draft per author per universe is a partial unique index
([ADR 0022](0022-an-editing-session-claims-the-browser-and-one-draft-stays-open.md)), `apply`
closes the draft it wrote on its first run ([ADR
0021](0021-applying-a-draft-through-the-live-mutation-path.md)), and `DraftApplier` reads one draft's
changes. So an author who wants to pursue two directions for one record cannot: their second
direction joins the first as one more remembered change, and one apply writes both.

That cost was recorded as a finding in [`../known_quirks.md`](../known_quirks.md), which is
correct for a fact no other document owns — and it was there **because** no other document owned
it. The word "branch" had never been defined for this application, so nothing could be said about
what a branch would be, and a finding is not where a decision lives. The reader-facing half was
worse than unrecorded: pressing **Start editing** when a draft was already open resumed that draft
silently, and said the same sentence a first start says.

Two properties the answer must not break are settled elsewhere and are not reopened here.
**Remembering is unconditional** — a reader who forgot the control must not write straight through
([ADR 0020](0020-remembering-mutations-instead-of-writing-them.md)), so refusing a change is not an
available answer. And **an apply closes its draft**, because a remembered create names no record
and applying twice would write it twice ([ADR 0021](0021-applying-a-draft-through-the-live-mutation-path.md)),
so anything that leaves two drafts applicable at once reopens a hazard that was closed on purpose.

## Decision

### A draft is one line of work, and its unit is the author and the universe

`Draft::OPEN_STATUSES` and the partial unique index stay exactly as ADR 0022 left them. The unit
is **not the record**: a draft holding changes to forty records is still one line of work, because
what makes two drafts the same draft is who is holding them and in which universe, not what they
touch. Branching is therefore not a feature this application is missing behind a switch — it is a
different answer to "what is a draft", and this is the answer.

### A second direction is bought by closing the first, never by parking it

The only ways to free the slot are the three that close a draft: **apply** it, **discard** it, or
—in a `github` universe — **submit** it and let a reviewer close it. There is no fourth state
between open and closed. That is what keeps the applier's precondition true (a closed draft cannot
be applied again), and it is why **Stop editing** is not an answer: stopping releases the browser's
claim and leaves the draft open, because the work is still there.

### A start says which of the two things it did

`Draft.open_or_start_for!` is `open_for!` with the answer attached — the draft, and whether it was
already open — and `open_for!` is now defined in terms of it, so the race rescue ADR 0022 settled
has one implementation. `DraftEditingSession.start!` returns that value rather than the draft
alone, so the caller has one derivation of the fact rather than asking whether a draft existed a
moment earlier and risking an answer about a different request.

The **Start editing** flash is then two sentences rather than one: `drafts.flash.editing_started`
when this author had no open draft, and `drafts.flash.editing_resumed` — carrying how many
remembered changes are waiting on it — when they did. The count is the one **Stop editing** already
names, because it is the same question asked at the other end of the same session.

### The workflow guide states the rule where an author decides

`drafts/_workflow_guide` carries `drafts.guide.one_draft` on both drafts pages: one draft at a
time, everything remembered goes onto it in the order it was remembered, and trying a different
direction means applying or discarding what is waiting. The flash reports the rule **after** the
reader has pressed the control; the guide states it on the page they read before deciding what to
do.

## Consequences

### Benefits

- The one surface where a reader could mistake a return for a beginning now says which it was, and
  says how much of the earlier work is waiting.
- The cost the finding recorded has an owner that can change it, and the reader-facing half is
  decided rather than accidental.
- Nothing a decision would have to unlearn was unlearned: the index, the applier's precondition, and
  the unconditional remembering are all untouched.

### Costs and constraints

- **An author who wants both directions pending still cannot have them.** The sentence does not
  change that; it tells them what has to happen first, which is the honest version of the same
  refusal.
- **A remembered change still joins an existing draft without saying so.** `drafts.flash.remembered`
  is unchanged, because it is printed on every mutation in a draft-based universe and a clause about
  which draft it joined would be noise on every one of them. The pending count and its link into the
  drafts page are where an author goes to see which draft holds their work.
- **`Draft` gains a second public class method and a `Data` value.** `open_or_start_for!` exists so
  that one caller can say which of the two things happened; `Opening` is that answer, and
  `open_for!` — the form every other caller uses — is unchanged in behaviour and signature.
- **Revisiting this is not a one-column change.** Everything that reads a draft reads *one* of them
  by name: `DraftPreview`, `Draft.pending_changes_count`, `DraftsController#index`, the sidebar
  panel, and the applier's precondition. Parking a draft would move the hazard ADR 0022 closed
  rather than remove it, because a parked draft still holds changes some other run would have to
  write.

### Rejected: more than one open draft (a parked status outside the index)

The narrowest version of "two lines of work", and the one that sounds cheapest. It fails on the
read side rather than the write side: `DraftPreview` answers for one draft, the pending count counts
one draft, the sidebar panel lists one draft's changes, and the list page is a row that cannot be
sorted (the very thing ADR 0022's index made unnecessary). Parking also does not make the second
draft inert — it is still applicable, so two runs can still write over each other, which is the
hazard the index exists to close. It converts a decision about what a draft *means* into a change
to five read surfaces.

### Rejected: forking a draft into a copy

A copy would be a second line of work with no record of where it came from, and it makes the two
lines apply in either order. Whichever applied second would meet conflict detection that only knows
about the moves made **after the fork**, so a fork quietly loses the guarantee that the conflicts
an author was shown cover what the other line did. It answers "I want two directions" with "I want
two histories".

### Rejected: merging two drafts

There is nothing to merge after the fact: `apply` closes its draft, so a second draft's changes are
either live or never were. The one merge with any content is the one that already happens —
`Draft.open_or_start_for!` puts two tabs' changes on one draft, and a single apply writes them in
the order they were remembered ([ADR
0021](0021-applying-a-draft-through-the-live-mutation-path.md)). A merge control would be a second
way to do what a resumed start already does, with the cost of two histories to reconcile.

### Rejected: one draft per record rather than per author and universe

It sounds narrower and is worse. A remembered change that touches two records would have to name
which draft it belongs to, and a draft that remembers three records could not exist at all — so
the unit stops being a piece of work and becomes a per-record container. ADR 0019's append-only
change would then need a foreign key per change, which is the join this design deliberately does not
have.

## Related documentation

- [`../conventions.md`](../conventions.md) — the editing session and the drafts page as they behave
  now
- [`../known_quirks.md`](../known_quirks.md)
- [`../delivery_history.md`](../delivery_history.md)
- [0019](0019-collaboration-foundations.md)
- [0020](0020-remembering-mutations-instead-of-writing-them.md)
- [0021](0021-applying-a-draft-through-the-live-mutation-path.md)
- [0022](0022-an-editing-session-claims-the-browser-and-one-draft-stays-open.md)
- [0023](0023-pending-changes-are-read-from-the-draft-and-drawn-as-badges.md)