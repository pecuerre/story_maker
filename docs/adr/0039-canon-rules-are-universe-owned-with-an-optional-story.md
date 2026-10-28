# ADR 0039: A canon rule belongs to the universe unless a story owns it

- **Status:** Accepted
- **Date:** 2026-10-28
- **Related:** [ADR 0001](0001-universe-and-story-scope.md), [Canon rules](../features/canon.md), [Data model](../data_model.md)

## Context

The application records facts — profiles, knowledge changes, ownerships, relationships, Events — but
nothing records a **rule** the fiction must obey: what magic costs, how long a road takes, what nobody
can survive. Competitor tools sell this as "world rules" and cite the rule beside each violation, and
the planned story-structure interchange needs a `canon/` home and a `[[rule:ID]]` reference. Without a
record, the rule lives only in prose and nothing can point at it.

Two questions had to be settled before a table existed: what owns a rule, and what a rule stores.
A rule can be true of a whole universe (the cost of magic) or of one story told in it (this
retelling's rule about the cave), so ownership cannot be a single fixed parent. The backlog also
warned that a rule only earns its keep when something checks prose against it, so this decision must
not quietly become an analyzer.

## Decision

- A Canon Rule is one record with a required short **statement** and an optional **source passage**
  quoting or citing where the rule comes from.
- The record always belongs to a Universe. `story_id` is nullable: no story means the rule is
  universe-wide, a story means that Story owns it. One table carries both, because either way the
  rule is the same record with the same editor and the same search document.
- A Story that owns a rule must belong to that rule's Universe. This is an application-level
  validation, because the two foreign keys cannot prove it.
- The record is addressed by its numeric id, not a slug. Its identity is prose, so a slug derived
  from the statement would re-address the rule every time an author reworded it and break a stored
  citation. The stable id is what a `[[rule:ID]]` reference can point at.
- Rules are flat and unordered. There is no hierarchy, position, tag taxonomy, photo, or separate
  story workspace.
- Canon Rules are content records: they follow the Universe's read/write/admin policy, participate
  in the shared search index and the optional discussion control, and their HTML mutations are
  remembered in a draft-based Universe like every other content write.
- **The checker is deliberately not part of this decision.** Comparing prose with a rule belongs to
  the continuity findings inbox and the contradiction analyzer described in
  [the backlog](../backlog.md), not to this record.

## Consequences

### Benefits

- A rule has one list, one editor, one validation, and one search kind whichever story owns it.
- A universe-wide rule is visible and citable from every story without copying it.
- Rewording a rule keeps its id, so a passage that cites it stays valid.
- The story-structure import can later write a `canon/` directory into these rows without changing
  the shape.

### Costs and constraints

- `UniverseScopeResolver.owner_association_for` now reads a model's own `universe_id` before the
  owner associations, because a Canon Rule has both columns and its optional `story_id` must not be
  mistaken for its scope. A class-level authorization check and a remembered create both depend on
  that answer.
- The Story sidebar block gains nothing, and the rule list is a Universe Bible workspace even for a
  story-owned rule: there is no per-story canon tab.
- Because the record has no slug, a rule's page URL is numeric and does not change when the rule is
  reworded. Nothing else in the application depends on a slug for it.

## Alternatives considered

- **Two tables, universe rules plus story overrides:** rejected because it duplicates the table, the
  editor, the list, and the search declaration, and the override relationship would need its own
  precedence rule before anything reads it.
- **Universe-only rules:** rejected because a Story can legitimately change a rule for its own
  retelling, and the backlog names that case.
- **A rule as a Scene annotation or a tag:** rejected because a rule is not attached to one Scene and
  is not a classification of a record; it must be citable by id from prose.
- **Building the prose checker with the record:** rejected because an analyzer without a findings
  inbox is a verdict rather than evidence, and both are larger decisions.

## Related documentation

- [Canon rules](../features/canon.md) — the workspace, the editor, and the lifecycle.
- [Data model](../data_model.md#content-tables) — the table and its validations.
- [Navigation](../features/navigation.md) — the Universe Bible entry.
- [Search](../features/search.md) — the `canon_rule` kind.
