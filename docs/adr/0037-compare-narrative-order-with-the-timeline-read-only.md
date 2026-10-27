# ADR 0037: Compare a Story's narrative order with the Timeline, read-only

- **Status:** Accepted
- **Date:** 2026-10-27
- **Related:** [`../features/scenes.md`](../features/scenes.md),
  [`../features/events.md`](../features/events.md),
  [`../data_model.md`](../data_model.md),
  [`../visual_design.md`](../visual_design.md),
  [0007](0007-story-owned-scenes-and-elements.md)

## Context

A Story records one order and the Universe records another. `Scene.position` is the order the Story
**tells** its scenes. The Timeline (`TimelineLayout`) is the order the Universe's Events **happen**,
derived from start/end datetimes and the `before_event`, `after_event`, and `simultaneous_event`
relations. A Scene links the two by naming at most one Event, so for the Scenes that carry an Event
the same material is read twice.

Those readings disagree all the time, and they are supposed to. A flashback is a Scene told late
whose Event happens early. A parallel thread is two Scenes told apart whose Events happen together.
A cold open is the first Scene told and the last Event to happen. None of those is a mistake, and
none of them is detectable as intent, because the author records **order**, not the device that
produced it: there is no "flashback" flag and no "parallel thread" marker.

Today a reader has to hold both readings in their head. The Scenes list shows `position` and says
that it is the order the story is told, never in-world time. The Timeline shows the Events and no
Scenes at all. Event details lists the Scenes that depict that Event in narrative order. Nothing
puts the two orders on one page, so a reader cannot see a run of flashbacks, notice that two Scenes
were meant to be simultaneous, or spot a Scene that is simply in the wrong place.

There is a second pair of facts in the same area. A Scene may carry its own optional `datetime`
independently of its `event_id`; the model treats them as independent, and neither writes, clears,
nor validates the other. Nothing compares them either.

The design is constrained by the existing domain rather than by a wish for new capability:

- **All the facts already exist.** `Scene.position`, `Scene.event_id`, `Scene.datetime`, the Event
  datetimes, and the Event relations are stored and validated today. Nothing here needs a table,
  a column, a migration, or a stored verdict.
- **`position` is Story-owned; the Timeline is Universe-owned.** One comparison therefore belongs
  to one Story, not to the Universe. Combining the stories of a universe would interleave sequences
  that never claimed to be comparable.
- **`TimelineLayout` is the only authority for Event order.** Recomputing layers or simultaneity in
  the comparison would be a second implementation that could drift from the page it claims to show.
- **The page must not rewrite author data.** It reads; it never moves a Scene, links an Event,
  changes a `datetime`, or resolves a disagreement on the author's behalf.
- **Access is a decision, not a default.** The Scenes list and the Timeline are guest-readable on a
  public universe; this comparison is intended for signed-in readers, while still respecting the
  universe's public/private rule after authentication.
- **The backlog item is design-gated.** Its own text says to define what counts as "conflicting"
  before building it, which is the decision this ADR records.

## Decision

### The comparison is a read-only fourth tab of the Story workspace

The Story workspace's existing strip — **Sections**, **Plots**, **Scenes** — gains one more live
tab, **Narrative order**, after **Scenes**:

```text
GET /u/:universe_slug/s/:story_id/narrative_order
```

`NarrativeOrdersController#show` resolves the Story through the same universe-scoped lookup the
Scenes controller uses, so another universe's Story is a `404`. It is **signed-in only**: the
controller does not opt out of the shared `require_authentication` callback, so a guest is sent to
sign in and returned to the page afterwards. Beyond authentication, the page uses the shared read
rule in [`../architecture.md`](../architecture.md) and the `Ability` policy: any signed-in reader may
open it on a public universe, and a private universe keeps its owner/membership rule, so a signed-in
non-member gets the same `404` as everywhere else. The tab is therefore rendered only for a signed-in
reader; a guest sees the existing three tabs. There is no mutation route, no form, and no new
Stimulus controller: the page is a server-rendered read.

The tab and every existing Story-workspace strip must name the same four destinations. Extracting
one `story_workspace_tabs` helper is in scope for the implementation, because the array is currently
repeated in five views and a fourth entry is where a copy silently falls behind.

### "Conflicting" means one Scene's own two in-world claims disagree

`Scene.position` makes no claim about in-world time. It is a statement about telling, so a reversal
between narrative order and chronology is **not** a conflict, and the page never labels one as an
error. Two Scenes whose Events are ordered one way while the Scenes are told another way are not a
conflict either: the story is allowed to tell them in any order.

A conflict exists only when a **single Scene** records two in-world times that cannot both be true:

> A Scene is **conflicting** when it links an Event that has a known start or end, and the Scene's
> own `datetime` falls outside that Event's known interval — before its start or after its end.

The bounds are read as the Event states them:

| Event records | The Scene's `datetime` conflicts when |
|---|---|
| start and end | it is before the start or after the end |
| start only | it is before the start |
| end only | it is after the end |
| neither | never — there is no clock to compare |
| end before start | never — the Event's own range is unusable, not the Scene's claim |

The Event supplies the place on the Timeline; the Scene's `datetime` is shown beside it and is
**never** used to move the Event or to choose a different place. A `datetime` with no linked Event
is not a conflict, because the two facts are independent by design. A conflict is reported, never
resolved: the page shows both values, and the author is the one who decides which is wrong.

The verdict is computed for the request and is not stored. There is no conflict column, no badge on
the Scene's own page, and no notification. If the author fixes the data, the next request shows it
fixed.

### The Event supplies the timeline place, and only when the Timeline has a reason for it

Each Scene's place comes from its linked Event's row in `TimelineLayout#layers`, which is the same
row the Timeline page draws. An Event is treated as **placed** only when its simultaneity group has
temporal evidence: a start or end datetime anywhere in the group, or a `before_event`/`after_event`
relation that connects the group to another. An Event with none of that (a title-only Event, or a
group of dateless Events joined only to each other) still has a row in the layout, but that row is
the layout's arbitrary top row rather than a claim about time. The page says **No recorded time**
for those Scenes and does not compare them.

`TimelineLayout` gains read-only accessors for the three questions the comparison asks — the layer
of an Event, whether its group is placed, and whether two Events share a simultaneity group — and
the comparison uses them. `layers` and `edges` are unchanged, and the comparison never rebuilds the
union-find or the graph. Simultaneity is the union-find group, not the layer: two Events can share a
row without being simultaneous, because a row only means "no known order below this one".

### The step is measured inside a run

Scenes are read in `(position, id)` order, which is the Story's one narrative sequence. A **run** is
a maximal stretch of consecutive Scenes that all have a place. An unlinked Scene, or a Scene whose
Event has no recorded time, ends the run: the next placed Scene starts a new one and is **not**
compared across the gap. Within a run, each Scene's Event layer is compared with the Event of the
Scene immediately before it, which is also the previous placed Scene, and the row names that Scene so
the comparison is inspectable.

| Step | Meaning |
|---|---|
| **First in this run** | There is no earlier Scene with a place in the same run; nothing to compare. If the run begins after a gap, the page says the comparison starts here. |
| **Later** | The Event's layer is below the previous Scene's Event in the run. The story moves forward in world time. |
| **Earlier** | The Event's layer is above it. The page explains this as a return — a flashback, a parallel thread, or an order worth checking — and calls it neither a mistake nor a conflict. |
| **Same time** | The two Events share a simultaneity group. This is the parallel-scene reading, and it is why simultaneity is read from the group rather than from the row. |
| **No known order** | The two Events share a layer but not a group. The Timeline records no evidence either way; the page says so instead of inventing an order. |

A Scene with no Event is **not linked**, and a Scene whose Event has no recorded time is **not
placed**. Both are listed in story order, left out of the step comparison, and end the current run.
A Scene's own `datetime` is shown whenever it is present, but it never becomes its place.

### The page puts the two readings side by side

The page is a single server-rendered read with two lists, side by side on a wide screen and stacked
on a narrow one. It is not a new Timeline and does not draw arrows.

- **How the story is told (left)** — every Scene in narrative order: the position number, the Scene's
  title linking to its details page, its Section, its linked Event, its own `datetime`, its
  comparison step, and the Timeline row it belongs to. A conflicting Scene states both the Event's
  range and its own time in the row.
- **When it happens (right)** — the Universe's Timeline rows in `TimelineLayout` order. Each row
  lists its Events; each Event links to its details page and names the narrative positions of this
  Story's Scenes that depict it. Events this Story never depicts stay visible but secondary, because the
  right-hand column is the Timeline, not a filtered version of it. Events with no recorded time sit
  in their own **No recorded time** group rather than in a numbered row, for the reason above.
- **The reading guide (above)** — one sentence defining a conflict, the step labels, and counts of
  Scenes and Events by category. The labels are text, never color alone.

The page is the **whole Story** and the **whole Timeline**. It has no filter, no sort control, and
no pagination: a narrowed sequence is not the telling order, and a filtered timeline is not the
timeline. A Story with no Scenes, a Story whose Scenes link no Event, a Universe with no Events, and
a group with no recorded time each get their own empty or partial state, with a link to the relevant
workspace worded for a writer or a reader as the Scenes and Timeline pages already do.

### What this page deliberately does not do

- No flashback, parallel-thread, or "out of order" flag is stored, inferred, or suggested.
- No data is rewritten, normalized, relinked, or moved, and no conflict is resolved.
- No reversal between narrative order and chronology is called an error.
- No Scene from another Story appears, and no Story is selected implicitly.
- No pending draft change is projected. The page reads the saved records, like the Timeline; a
  remembered change has no applied place to compare. Adding a page-level notice about open drafts is
  a later decision, not part of this one.
- No causality, Element chronology, or uncertainty analysis. Explaining *why* a contradiction is
  likely belongs to the separate temporal analyzer, which can reuse this comparison without
  changing it.

## Consequences

### Benefits

- A signed-in reader can see a flashback run, a parallel thread, a forward jump, and an unordered
  pair in one place, without the story being edited.
- The only thing marked as a problem is an objective contradiction between one Scene's own facts,
  which is safe to report and honest about what the app does and does not know.
- The Event ordering is the Timeline's own, so the two pages cannot disagree about which Event comes
  first.
- No storage, no migration, no data change; the Dark and LOTR demonstrations already contain several
  Scenes per Event, a Scene with a `datetime` and no Event, and ungrouped Scenes, so the page is
  exercisable without new sample data.

### Costs and constraints

- A new read surface, a new value object, a new controller and view, a fourth tab in five view
  locations, translations, and tests (model classification, request access and scope, and a browser
  case for the tab).
- `TimelineLayout` grows a small read-only surface for grouping and placement. That surface must be
  tested, and it must not become a second ordering implementation.
- Two long lists do not align row for row, so the page cross-references by position numbers and
  Event titles rather than by connector lines. A connector would claim an alignment the columns do
  not have. A very large Story or Timeline therefore makes a long page; that is accepted, because
  filtering or paging either column would stop it being the sequence it claims to show.
- The comparison stops at the first Scene it cannot place. A reversal that spans an unlinked or
  undatable Scene is therefore not reported; the page shows two runs instead of guessing across the
  gap.
- The page is the one signed-in read in the Story workspace. The tab is hidden from guests and a
  guest URL is sent to sign in, which must be tested against the shared authorization rules rather
  than implemented as a controller-local visibility check.
- The conflict check is local to one Scene. A contradiction between two different Scenes' datetimes,
  or between an Event's dates and its relations, is outside this page and stays with the temporal
  analyzer.
- The page is only as useful as the Event links. A Story whose Scenes rarely name an Event will show
  mostly "not linked", which is a data fact the page makes visible rather than hides.

## Alternatives considered

### Alternative: a card on the Story overview page

The Story overview has no width for two long sequences, and a card would either summarize away the
comparison or become a second page in disguise. The workspace tab is the established place for a
Story-level read.

### Alternative: a universe-level page covering every Story

`position` is per Story. Interleaving several Stories' sequences would produce an order no Story
claims, and a Story selector would duplicate navigation the workspace already provides.

### Alternative: a tab on Scene Details

Scene Details is about one Scene and already carries five tabs. The comparison is a whole-Story read
whose subject is the relationship between Scenes, so it belongs beside the Scenes list.

### Alternative: overlay Scenes on the existing Timeline page

That would change the Timeline's reading from the Universe's events to one Story's telling, and it
would require choosing a Story on a Universe page. The Timeline stays the shared, story-free read;
the comparison is the Story-scoped one.

### Alternative: store a "flashback" or "parallel" marker

A stored device would let the page distinguish intent, but it adds authoring work, a migration, and
a new field that every existing Scene lacks. The comparison can explain the order without claiming
to know the device, and the missing marker can be a later product decision if authors ask for it.

### Alternative: treat every reversal as a conflict

This is the trap the design exists to avoid. Because intent is not stored, every flashback and every
parallel thread would be flagged, the warning would be noise, and authors would learn to ignore it.
Only the objective two-claim disagreement is a conflict.

### Alternative: compute Event order inside the comparison

A second longest-path layering could disagree with the Timeline after the next algorithm change.
The comparison reads `TimelineLayout`, and the only new code is the accessors it needs.

### Alternative: use the Scene's `datetime` to place it on the timeline

The `datetime` is a Scene's own point, not the Event's interval, and treating the two as one clock
would silently prefer one fact over the other. The Event supplies the place; the `datetime` is
shown and checked against it.

## Related documentation

- [`../features/scenes.md`](../features/scenes.md) — the Scene model, `position`, `datetime`, and
  the Scene workspace, where the implemented page will be documented.
- [`../features/events.md`](../features/events.md) — the Timeline algorithm and the Event relations
  this page reads.
- [`../data_model.md`](../data_model.md) — the stored columns the comparison uses.
- [`../visual_design.md`](../visual_design.md) — the tabs, two-column layout, and text-labelled
  states the page reuses.
- [ADR 0007](0007-story-owned-scenes-and-elements.md) — why Scenes are story-owned and `position`
  is narrative order.
