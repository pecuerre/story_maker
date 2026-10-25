# ADR 0035: Faction relationships are directed

- **Status:** Accepted
- **Date:** 2026-10-25
- **Related:** [Faction profiles and relationships](../features/factions.md), [Faction domain](0034-factions-are-universe-content.md), [Universe access](0005-universe-access-levels.md)

## Context

Factions need relationships that can be described independently of Character relations. Alliances,
conflicts, and influence are not necessarily reciprocal, and deriving one side from the other would
hide that difference. The data also needs to be available to every Story in the Universe.

## Decision

- Store a relationship as a universe-scoped `FactionRelationship` with `from_faction` and `to_faction`
  endpoints. The arrow is meaningful; a reverse relationship is an independent record and is never
  inferred.
- Require distinct endpoint Factions from the same Universe. Store an optional name, description, and
  in-world date interval on the relationship itself.
- Use the standard details page and HTML CRUD flow for this link record. Keep it separate from the
  Character `Relation` model and its tag-driven symmetric/inverse semantics.

## Consequences

### Benefits

- An author can record an asymmetric relationship without encoding a second answer in a tag or
  silently manufacturing its inverse.
- Relationship details and dates are shared across the Universe's Stories and follow the existing
  Universe access and draft-mutation rules.

### Costs and constraints

- A reciprocal relationship takes two records, and the author is responsible for keeping their details
  consistent when reciprocity is intended.
- There is no taxonomy, pair uniqueness, or inferred reciprocal link in this first model.

## Alternatives considered

### Reuse Character `Relation`

Rejected because its endpoints are Characters and its RelationTag taxonomy carries symmetric/inverse
semantics that do not describe the new Faction link's independent direction.

### Make every relationship symmetric

Rejected because it would prevent the model from expressing asymmetric alliances, pressure, or hostility.

## Related documentation

- [Faction profiles and relationships](../features/factions.md) — current fields, scope, and workflow.
- [Data model](../data_model.md) — persisted schema, ownership, and validations.
