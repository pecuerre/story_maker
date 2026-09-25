# ADR 0001: Keep world-building universe-scoped and scripts story-scoped

- **Status:** Accepted
- **Date:** 2026-09-24
- **Related:** [`../data_model.md`](../data_model.md), [`../architecture.md`](../architecture.md)

## Context

Universe Maker supports multiple stories that can share one fictional world. A character,
location, event, item, relationship, or ownership may be relevant to several stories, while a
story's script structure—such as books, chapters, and scenes—belongs only to that story.

Putting every record in a single scope would make shared world-building difficult. Putting every
record in a story scope would duplicate common entities and make cross-story continuity harder
to manage. It is also important not to silently choose the first story in a universe: doing so
would make the current navigation state surprising and could expose content in the wrong scope.

## Decision

A universe owns the shared world-building records and their tag taxonomies. This includes
characters, locations, items, events, relations, ownerships, and all corresponding tag models
except section tags and scene tags.

A story owns its sections, scenes, section tags, and scene tags. Sections form the story's script
hierarchy, while Scenes form its ordered narrative sequence; each story has its own structure
taxonomies. Section, Scene, Section Tag, and Scene Tag routes must therefore include an explicit
story id.

> **Slice 11.4 clarification (2026-09-25):** `Scene` and `SceneTag` apply the same story-scope
> boundary to the ordered Scene sequence and its optional tag taxonomy. The underlying
> world-building scope decision is unchanged.

The current story is selected explicitly or remembered for the current user and universe. There
is no fallback to the universe's first story.

## Consequences

### Benefits

- Multiple stories can share one coherent universe without duplicating world-building data.
- Each story can have an independent script structure and section taxonomy.
- Cross-story continuity can be queried through the shared universe scope.
- Explicit story selection keeps navigation and authorization-sensitive context predictable.

### Costs and constraints

- Controllers, views, routes, and tests must carry the correct universe or story scope.
- Cross-scope associations require application-level validation; foreign keys alone do not prove
  that records belong to the same universe or story.
- The UI has an additional selection step before story-scoped content becomes available.

## Alternatives considered

### Make every record story-scoped

Rejected because shared characters, locations, events, and other world-building records would
need to be duplicated or synchronized across stories.

### Keep sections at universe scope

Rejected because different stories need independent scripts and section taxonomies.

### Automatically select the first story

Rejected because it hides an important user choice and can cause content from the wrong story to
appear in navigation and forms.

## Related documentation

- [`../data_model.md`](../data_model.md)
- [`../architecture.md`](../architecture.md)
- [`../universe_maker_conventions.md`](../universe_maker_conventions.md)
