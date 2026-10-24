# ADR 0033: Represent gatherings through Events and Scene presence

- **Status:** Accepted
- **Date:** 2026-10-25
- **Related:** [ADR 0007](0007-story-owned-scenes-and-elements.md), [Scenes](../features/scenes.md), [Events](../features/events.md)

## Context

The proposed Meeting concept overlapped the existing Event and Scene model. A gathering can be
represented by an Event and its linked Scenes, while Scene participation already records Characters
and Locations. A separate record would need a distinct meaning to justify another model and page.

## Decision

- Do not add a Meeting model, route, or dedicated page.
- Represent a gathering as an Event with linked Scenes. Record Character participation and Location
  presence on the relevant Scenes, using the existing Scene links and tags where useful.
- Do not add Event-level attendance. Attendance without a relevant Scene is not a separate supported
  record in this model.

## Consequences

### Benefits

- The same gathering is not duplicated across Event, Scene, and Meeting records.
- Existing Event chronology and Scene participation remain the sources of author-entered facts.

### Costs and constraints

- A gathering's attendees and Locations are recorded per Scene, not once on the Event.
- There is no Meeting-specific list, details page, or attendance view.

## Alternatives considered

### Add a Meeting record

Rejected because the proposed scope and fields were already expressible through Events, linked Scenes,
and Scene participation; no distinct Meeting-level fact or workflow was identified.

## Related documentation

- [Scenes](../features/scenes.md) — Scene ownership and participation.
- [Events](../features/events.md) — Event chronology and Scene references.
