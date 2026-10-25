# ADR 0034: Factions are universe content

- **Status:** Accepted
- **Date:** 2026-10-25
- **Related:** [Faction profiles](../features/factions.md), [Tags](../features/tags.md), [Universe access](0005-universe-access-levels.md)

## Context

Character tags can label Characters as members of a faction, but they cannot describe a faction that
exists independently of any one Character. A faction also has its own public mission, actual aims,
structure, internal divisions, and resources. These are shared world facts, not facts that belong to
one Story.

## Decision

- Model each Faction as first-class, universe-scoped content, addressed by its generated slug and
  described by its own profile fields.
- Give Factions their own optional `FactionTag` taxonomy. Character tags remain Character labels; no
  existing tags or Character assignments are automatically moved or rewritten.
- Keep Character-to-Faction membership and Faction-to-Faction relationships out of this slice. They
  are separate associations and require their own domain decisions.

## Consequences

### Benefits

- A faction can be created and described even when it has no Characters.
- Character classification and faction identity no longer compete for one taxonomy.

### Costs and constraints

- Existing Character tags that represent factions remain in place until an author chooses how to
  migrate or remove them.
- This first slice does not record which Characters belong to a Faction, nor relationships among
  Factions.

## Alternatives considered

### Keep using Character tags as faction records

Rejected because a tag describes how a Character is classified; it cannot carry the faction's own
profile, exist independently of a Character, or be connected to other Factions.

## Related documentation

- [Faction profiles](../features/factions.md) — profile fields, taxonomy, access, and workflow.
- [Data model](../data_model.md) — schema and universe ownership.
