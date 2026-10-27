# ADR 0038: A Scene depicts Events through ordered link rows

- **Status:** Accepted
- **Date:** 2026-10-27
- **Related:** [Scenes](../features/scenes.md), [Events](../features/events.md),
  [data_model](../data_model.md), [ADR 0007](0007-story-owned-scenes-and-elements.md),
  [ADR 0037](0037-compare-narrative-order-with-the-timeline-read-only.md)

## Context

A Scene carried one optional `event_id`. That was enough for "this Scene depicts this Event", but not
for the common case the author actually writes: one Scene can stage a conversation, a remembered
meeting, and the consequence of an earlier Event in the same narrative unit. The single column also
could not say *how* the Scene uses an Event — the opening, the climax, a report of something that
happened elsewhere — and it could not order several Events inside the Scene.

The alternatives were to keep a "primary" Event column and add a secondary list, or to let the single
column mean something it cannot express. The first creates two sources for one relationship; the
second is a hidden overload that every reader would have to learn. The comparison added in
[ADR 0037](0037-compare-narrative-order-with-the-timeline-read-only.md) also read the column
directly, so any change had to say how a Scene with several Events is placed and when its own
`datetime` conflicts.

## Decision

- **The link is its own record.** `SceneEvent` belongs to a Scene and an Event, carries the author's
  nullable free-text `role` and a flat contiguous `position` inside the Scene, and soft-deletes with
  its Scene. The pair is unique among live links. `scenes.event_id` and the `Scene#event` association
  are retired.
- **A Scene may depict any number of Events, and an Event may be depicted by any number of Scenes.**
  Neither side copies the other, and an Event's removal removes the links rather than the Scenes.
- **The links are edited on their own Scene tab**, `/scenes/:id/events`, a read page whose mutations
  are JSON-only under the shared modal contract. The Scene form no longer offers an Event selector,
  because a multi-link editor cannot live in one `<select>`; `position` is changed only by Move.
- **The Comparison places a Scene by the earliest linked Event the Timeline can place**, with the
  link order breaking a tie in one row. A Scene conflicts only when its own `datetime` is outside
  **every** claiming Event it links; a time inside any one of them is consistent with at least one
  recorded fact.
- **The API reports the links as an ordered `events` array** (`event_id`, `role`, `position`) and no
  longer accepts a single `event_id` when creating or updating a Scene.

## Consequences

### Benefits

- One Scene can record the several in-world facts it actually stages, each with the author's own
  reason and a stable order.
- The relationship has one home. A "primary Event" never disagrees with the rest of the list, and a
  reader asks the same association whether there is one link or five.
- The comparison's single-Event behaviour is preserved exactly: with one link, the earliest placed
  Event is that Event, and the "outside every linking Event" rule reduces to the old rule.

### Costs and constraints

- `scenes.event_id` is gone. The migration is schema-only by [ADR 0003](0003-disposable-schema-and-seed-data.md),
  so the disposable development data in `db/data/` is where the existing links are re-sourced; a real
  database keeps no copy of the old column.
- A draft remembered before this change carries an `event_id` payload for a Scene. The record no
  longer has that writer, so `DraftIntegrity` reports the change as unreadable rather than writing a
  guess. The author drops that one change or discards the draft; nothing is silently reinterpreted.
- The JSON API's Scene payload is a breaking change: consumers that read `event_id` or send it must
  move to `events`.
- A Scene no longer has a single "its Event". Every caller that read `scene.event` must choose
  between the links (ordered) and the placement rule (the earliest placed one).
- A Scene's own `datetime` is still never derived from a link, and the links are still never derived
  from it. The change adds multiplicity, not chronology.

## Alternatives considered

### Keep a primary `event_id` and add secondary links

Rejected: two associations for one relationship invite a primary that disagrees with the list, and
every reader would need to know which one is authoritative.

### A plain HABTM table

Rejected: the role and the order are part of the decision, so the join needs columns. It is a model,
with validations and a soft delete, in the same way `SceneCharacter` is.

### Model "roles" as a controlled vocabulary

Deferred: there is no evidence yet about which roles recur, so the role stays the author's free text.
A vocabulary would be a separate decision with its own migration and editor.

## Related documentation

- [Scenes](../features/scenes.md) — the Events tab, its contract, and the comparison rule.
- [Events](../features/events.md) — what deleting an Event does to its Scene links.
- [data_model](../data_model.md) — `scene_events` columns, indexes, and validations.
