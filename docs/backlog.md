# SHARED BACKLOG

This is the one place for **pending** work, rough ideas, and things we may want
to do in the future. The owner can append ideas without worrying about format.

## How finished work leaves this file

This file follows the same discipline as [known_quirks.md](known_quirks.md), where a fixed
finding is no longer an open item. When work is finished it does not stay here as a
"completed" paragraph. In the same change that delivers it:

1. add or update the dated entry in [`../CHANGELOG.md`](../CHANGELOG.md), then
2. delete the item from this file.

The changelog is the durable record of delivered work, so nothing else has to track it
here. Do not archive finished items under a separate heading, and do not leave a
completion summary behind.

## How AI assistants should use this file

When you notice another worthwhile improvement while working on a task, ask
the owner whether to do it NOW, LATER, or NEVER.

- NOW: do the extra work as part of the current task, then update the changelog and
  remove the item.
- LATER: add it under FUTURE WORK below.
- NEVER: do not implement it and do not add it to this file.

Do not silently expand the current task. Keep this file focused on work that is
still pending.

## PENDING WORK

Items are numbered and the numbers are stable: a finished item is deleted without
renumbering, so the remaining numbers are left as they are and a number is never reused or
made to mean a different idea.

Because a number disappears from this file when its item is completed, **do not cite a backlog
number from another document**. Reference a pending idea by its heading text, and cite delivered
work through the matching document in `docs/` or its dated `CHANGELOG.md` entry.

29. **Dropping one change a draft cannot describe**

   A draft holding a remembered change the applier cannot read is refused in words rather than applied,
   and the author's only way out is **Discard**, which throws away the other changes in the draft with it.
   The refusal names the change and leaves it listed, so nothing is hidden — but a draft with one corrupt
   change among nineteen cannot be applied at all, and a draft-based universe is a place where an editor can
   reach that state by accident (a hand-edited `draft_changes` row, a model renamed under the demo data, a
   loader from an older version). The general answer is the per-change control ADR 0021 deferred for
   conflicts: a way to drop one remembered change and apply the rest. Decided on 2026-10-05: not now. It
   belongs with a later collaboration phase rather than as a fix to the refusal, and the refusal itself is
   settled — see the resolved finding in [`delivery_history.md`](delivery_history.md).

32. for locations do these changes
  - sensory
    - sight
    - sound
    - smell
    - taste
    - touch
  - layout
    - overall structure
    - key areas
    - pathways
    - entrances and exits
    - points of interest
  - why it matters (significance of the location)
  - who is here (this should probably be updated by each scene, reflecting the current presence of factions and individuals in the location at that moment and specially the reason)
    - factions present
    - notable individuals
    - reasons for being here
  - history
    - significant events
    - past occupants
    - changes over time
  - control and access
    - who controls it
    - how access is granted
    - security measures
    - restrictions

33. for items
  - what it is
  - what is does
  - how it is used
  - side effects
  - origin (where it comes from)
  - ownership (who owns it) (this should be updated as ownership changes)
  - value (monetary or otherwise)
  - cannot
  - constraints (limitations or restrictions on its use)
  - history (past uses or significant events involving the item)
  - jargon

These items are deliberately **LATER** by default. Use the owner's **NOW / LATER / NEVER** decision
before expanding a feature task; the DataFactor report is directional evidence, not an automatic
work order.

## FUTURE WORK
- **Verify the weak-confidence Brakeman SQL warning in `ListFilter`.** Brakeman 8.1.0 reports
  possible SQL injection at `app/models/list_filter.rb:191`; review the current interpolation and
  sanitizer path in isolation before changing the shared filter implementation. Deferred LATER on
  2026-10-24 while implementing Routes.
- **One accepted ADR still points at something this change moved.** [ADR
  0023](adr/0023-pending-changes-are-read-from-the-draft-and-drawn-as-badges.md) cites finding
  63, which left [`known_quirks.md`](known_quirks.md) when the conflict page removed the cost of
  retyping an unapplied change. The decision stands and only the pointer is stale, so the fix is one
  clause on its "pending create says nothing about where it would go" bullet — not a rewrite of the
  body. ADR 0021's half of the same note was done on 2026-10-04 when the stored outcomes landed: its
   Status line now says which costs
   [ADR 0024](adr/0024-an-applies-outcome-is-stored-and-a-closed-draft-stays-inspectable.md)
   superseded and which of its reasoning still holds. Deferred by owner decision on 2026-10-04.
- **Story page/photo expectations from existing workspace changes.** The 2026-10-25 full suite still
  finds stale expectations on the Story overview and photo details surfaces. Re-run and triage those
  failures in their owning feature areas after the existing work is ready for review, rather than
  expanding turn-level dialogue.
- **change universes to subdomains**. replace the /u/universe_slug for universe_slug.<website>.com
- **Scene point-of-view/focus Character.** Record whose perspective presents a Scene separately from
  all Characters present, supporting same-Event/different-POV analysis without duplicating Event data.
- **Composite Scene-to-Event links.** If a Scene often contains several Events, introduce a scoped
  join model with roles/order rather than overloading the first version's optional single Event.
- **Narrative-order versus chronology comparison.** Visualize a Story's Scene sequence beside the
  Universe Timeline to expose flashbacks, parallel scenes, and unexplained order changes.
- **Structured Scene roles.** Analyze recurring free-text Character/Item/Location annotations before
  promoting useful values to controlled, analyzer-friendly role types.
- **Scene character-presence analyzer.** Use explicit participants and derived speakers to answer
  where a Character appears, with Story context and confidence/inference labels kept separate from
  author-entered facts.
- **Scene character-knowledge analyzer.** Track what a Character witnesses or is told in a Scene;
  this needs explicit attribution rules and should not be inferred from mere presence.
- **Scene causality and temporal analyzer.** Compare Scene order, linked Events, independent
  Scene datetimes, and Element chronology to explain likely contradictions rather than silently
  rewriting author data.
- **Scene prose-contradiction analyzer.** Analyze Element text for claims that conflict with Universe
  facts; this is a separate product from structured temporal/causal checks and should explain its
  evidence and uncertainty.
- **Timeline pan/zoom.** `architecture.md` and the conventions described a pan/zoom interaction for
  `timeline_controller.js` from the feature's first commit, but it was never implemented — the
  controller only draws edges between nodes. The docs were corrected on 2026-09-29 to describe the
  Timeline as the static layered view it is; this item is the actual feature, deferred by decision.
  Building it is a UI design question, not a defect fix: a draggable/zoomable viewport changes how
  the layer markers and node circles read, needs a keyboard and touch path to be usable at all, and
  the SVG edges must stay aligned under the transform. Worth doing only if a universe's event count
  makes the current wrapped layout genuinely hard to read.

## other ideas
- export in book format
- export in script format
