# ADR 0022: An editing session claims the browser, it does not gate remembering; and one open draft is a database rule

- **Status:** Accepted
- **Date:** 2026-10-03
- **Related:** [`../architecture.md`](../architecture.md),
  [`../conventions.md`](../conventions.md),
  [`../features/navigation.md`](../features/navigation.md),
  [`../known_quirks.md`](../known_quirks.md),
  [0019](0019-collaboration-foundations.md),
  [0020](0020-remembering-mutations-instead-of-writing-them.md),
  [0021](0021-applying-a-draft-through-the-live-mutation-path.md)

## Context

A draft-based universe remembers every mutation its authors make, and a draft's page is where the
remembered changes are reviewed, applied, or thrown away. What it did not have was a way to *say* that
an author is in the middle of an editing session: the first thing slice 2.4 needs to deliver is a
**Start editing** / **Stop editing** control on the universe page and a count of what is waiting, and
two questions have to be answered before it can be written.

**1. What does the control decide?** The obvious reading is that it decides whether a change is
remembered: press it and edits are held, leave it alone and edits are written. That reading is
available because the control is a switch, and it is the one reading that is actively unsafe. The
author who has not noticed the switch is exactly the author whose edit should have been held, and in
a `wikipedia` universe a write that lands without anyone reviewing it is the outcome the whole mode
exists to prevent. Every other path into a draft-based universe already remembers unconditionally —
ADR 0020 settled that, and all twenty mutation controllers implement it — so a control that gated
remembering would be a second, weaker answer to a question that has one.

The honest alternative is to make the control say what it actually is: a claim by this browser that its
user is working in this universe right now. That claim earns its place by doing two things a bare
mutation never did. Entering it **opens the draft before the first change is made**, so the thing
changes are remembered into exists before anything needs remembering, and it gives the universe page a
count to state. It costs nothing in safety, because the claim is not consulted when a mutation arrives.

**2. Where does "one open draft per author per universe" live?** ADR 0019 settled that there is **no**
unique index on `[user_id, universe_id]`, because an applied draft stays behind as history and a
constraint across every status would make a second editing session impossible. The reasoning was about
*all* statuses, and it is still right about all of them — but it left "one **open** draft" as an
application convention, which made it a thing two simultaneous requests could disagree about. Both read
"no open draft", both insert, and two drafts exist where the convention says one. That was recorded as
a low finding while it was harmless, and it stopped being harmless the moment a draft had a page:
applying both writes both, so the second one's changes land over whatever the first one left.

The slice that asks for this control is also the slice that opens drafts from a user action, which makes
the race easier to hit rather than harder — the same click in two tabs is now a plausible way to do it.

## Decision

### The control claims the session; remembering does not consult it

`DraftEditingSession` stores one boolean per universe in the session, and `DraftEditingController`'s two
actions write it. `DraftMutation` never reads it: in a draft-based universe a mutation is remembered
whether the flag is set or not. The flag is a **claim about this browser's user**, and the two facts it
carries are the draft (opened on entry, resumed rather than replaced) and the pending count the universe
page displays.

Three consequences follow, and each is load-bearing:

- **A reader who never presses the control cannot write straight through.** There is no path from a
  forgotten button to a live record, which is the property that made refusing unsafe.
- **Stopping is not discarding.** The draft stays open and every remembered change stays in it, because
  a remembered change is append-only and the draft is where it lives. The flash that follows a stop
  states how much is still waiting, so a release is never read as a loss.
- **The claim is per universe and per visit.** It is stored in a hash keyed by universe id, the way the
  remembered story map is, so a visit that spans two universes does not make the second inherit the
  first's session; and `clear_session_context` drops it at every session boundary, so one account's
  claim cannot cross accounts on a shared browser. A draft outlives the session — a sign-out is not a
  discard — and the right sidebar's **Pending changes** entry is still how it is reached afterwards.

The control is offered exactly where it is enforced: a draft-based universe and `write` access. Both
actions need `write` from the shared universe policy, which is the same rule that decides where the
control renders, so an author whose access was revoked mid-session loses the control with the access
rather than keeping a mode whose changes could not be remembered.

### One open draft per author per universe is a partial unique index

`drafts` gains a **partial** unique index on `[user_id, universe_id]` over `status IN ('draft',
'submitted')`, alongside the plain composite index the reader's draft list still needs for history. This
is the rule the collaboration plan always stated, said by the database rather than by convention, and it
keeps ADR 0019's actual reasoning intact: applied and discarded drafts are outside the index, so history
is unlimited and a second editing session is possible.

`Draft.open_for!` resolves the one race the index leaves. When the insert is refused, the losing request
re-reads the winner's row and returns it instead of raising — both requests' changes belong to one
author working in one universe, so they belong on one draft that one apply closes. The rescue re-reads
rather than inventing an answer: if the row is gone again, the original error is raised, because a nil
answer would hand the caller a draft-less session to remember changes into.

The migration writes its statuses as SQL, because a migration has to keep saying what it said on the day
it ran. `test/models/draft_test.rb` reads the index back out of the database and compares it with
`Draft::OPEN_STATUSES`, so the frozen list and the live one cannot drift apart silently — the same
"test the other list" shape as the applier's ordering derivation.

## Consequences

### Benefits

- The control cannot cause an unreviewed write, and the remembering path keeps the one answer ADR 0020
  gave it.
- Starting an editing session is a visible, ordinary act: the author knows their changes are being held
  and can see how many.
- Two tabs can no longer open two drafts. The double-apply hazard is closed rather than documented as
  unlikely, and closing a draft is what frees the slot for the next session.
- The index is the one place that says what "open" means, alongside `OPEN_STATUSES`, so a status added to
  that list without joining the index fails a test.

### Costs and constraints

- **The control is not a gate, which may read as a missing feature.** An author who expects pressing
  **Start editing** to be required for remembering gets no such refusal, because there is none to give.
  The button's own copy says what it does — it opens the draft and states the count — rather than
  implying it authorizes anything.
- **An editing session is per visit, not per author.** A reader who signs out and back in is no longer
  editing, and must press the control again; their draft and its changes are still where they were.
- **A partial index freezes a status list in SQL.** `submitted` is in the index before the reviewing
  workflow exists, because `OPEN_STATUSES` already included it and the two must agree.
- **The flag is unreadable data the session can be made to carry**, so `DraftEditingSession` reads its
  stored value defensively: a value that is not a map is no claim at all rather than an exception on
  every page of a draft-based universe.
- **The race is handled, not prevented.** Two simultaneous writes can still interleave; what the index
  prevents is two drafts, so the outcome is one draft with both requests' changes on it.

### Rejected: refusing mutations while the control is off

The reading that makes the button a real gate has to refuse the mutation, because writing it through
would be a live edit nobody reviewed. That is the safest possible reading and the wrong one for this
phase: it needs a JSON and HTML refusal contract across all twenty mutation controllers, it makes every
workspace in the universe refuse until the author finds a control on a different page, and a reader who
cannot find the control is left with a universe they cannot edit at all. The gate would have to be
discoverable before it is load-bearing, and a control that refuses work until it is pressed is not.

### Rejected: writing straight through while the control is off

The other way to make the button a switch, and the one this decision exists to refuse. It makes the
collaboration mode a per-session preference, so the same universe is review-gated for an author who
pressed the button and open for one who did not — and the author who did not press it is the one who
forgot. Nothing in the request lifecycle can tell the two apart at the moment the write happens.

### Rejected: a unique index across every status

ADR 0019's reasoning, and it is still correct for history: applying or discarding a draft leaves the row
behind as the record of what was attempted, so a constraint that forbids a second row would make a
second editing session impossible and the history a lie.

### Rejected: keeping the convention and documenting the race

The status quo, with the finding left open. It is one line of code either way, and the difference is
whether the collaboration plan's central rule — one draft at a time per author per universe — is a
property of the data or a property of nobody's timing.

## Related documentation

- [`../architecture.md`](../architecture.md)
- [`../conventions.md`](../conventions.md)
- [`../features/navigation.md`](../features/navigation.md)
- [`../known_quirks.md`](../known_quirks.md)
- [0019](0019-collaboration-foundations.md)
- [0020](0020-remembering-mutations-instead-of-writing-them.md)
- [0021](0021-applying-a-draft-through-the-live-mutation-path.md)