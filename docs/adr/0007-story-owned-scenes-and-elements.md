# ADR 0007: Make Scenes story-owned narrative units with optional Elements and links

- **Status:** Accepted
- **Date:** 2026-09-25
- **Related:** [`0001-universe-and-story-scope.md`](0001-universe-and-story-scope.md), [`../architecture.md`](../architecture.md), [`../data_model.md`](../data_model.md), [`../universe_maker_conventions.md`](../universe_maker_conventions.md), [`../backlog.md`](../backlog.md)

## Context

Universe Maker already separates shared universe world-building from story-specific script
structure, but it has no record for the ordered scenes through which a story is narrated. A
minimal section tree is not enough to express narrative order, prose, participation, and a link to
in-world events. At the same time, characters, items, locations, and events belong to the shared
universe and must not be duplicated merely because a story uses them.

Epic 11 requires an explicit domain and UX contract before the first Scene migration. The record
must preserve the accepted Universe/Story boundary, allow unfinished title-only Scenes, distinguish
narrative order from in-world chronology, and provide an extensible editing model without claiming
that free text alone is machine-checkable continuity data.

Slice 11.0 resolves the remaining product defaults and sketches the future URLs and interactions.
It does not add a schema, route, controller, view, fixture, or development-data record.

## Decision

### Ownership and narrative order

- A `Story` owns an ordered collection of `Scenes`.
- A `Scene` belongs to exactly one required Story and is not a universe-level record.
- A Scene's contiguous `position` represents **narrative order**—the order in which the story is
  told—not in-world chronology. Ordering is deterministic by `position, id`; controllers and
  services maintain positions transactionally as contiguous `0..n-1`.
- A `Scene` may belong to at most one optional Section. Sections organize Scenes but never define
  their narrative order. Section and Scene must belong to the same Story.
- A `Scene` may reference one optional universe Event and may separately store one optional
  in-world datetime. These fields are independent in the first version; selecting one never writes,
  clears, or validates against the other.
- A Story still becomes current only through the existing explicit selection or remembered-story
  flow. Scenes never cause fallback to a Story's first record or first Scene.

### Scene contract

A Scene persists its required title in `name` and labels that field **Title** in the interface. It
uses `HasSlug`, has a short optional description, and has the following optional references:

- one same-Story Section;
- one same-Universe Event;
- one in-world datetime;
- zero or many story-scoped Scene Tags;
- zero or many same-Universe Character, Item, and Location presence links.

A title-only Scene is valid. Optional links and Elements may be completed later. Presence links
store a nullable free-text `role`; a blank role means no role, not a controlled-vocabulary value.
The same Event may be referenced by many Scenes, including separately written Scenes with no
point-of-view claim.

Scene Tag definitions are story-scoped hierarchical taxonomies managed under **Configuration →
Tags → Story Tags**. Scene Tag assignment remains optional and is edited on Scene Details. Scene
Tags are never created or assigned automatically.

### Scene Element contract

A `SceneElement` belongs to one Scene and is a flat, ordered sequence rather than a hierarchy. It
stores:

- `kind`, restricted to `narration` or `dialogue`; the column must not be named `type`, which
  Active Record reserves for single-table inheritance;
- required `name`, persisted in the conventional field and labelled **Title**;
- optional `body`, persisted as plain text and labelled **Content**; an Element can be saved without
  a body;
- a contiguous `position`, maintained independently within its Scene.

A Dialogue Element must link to at least one same-Universe Character through
`SceneElementSpeaker`. A speaker is also visible as a Scene participant, but speaker links do not
represent turn order or turn-by-turn attribution. Narration Elements cannot have speakers. The
server rejects changing a Dialogue Element to Narration while speakers remain; the future modal
may offer an explicit confirmation that removes those speakers in the same atomic request.

Elements are independent of a Scene's in-world Event and datetime. Adding an Element does not
change chronology, and an Element is not a world record.

### Target URLs

Scenes are mounted only beneath an explicit Story. There is no Universe-level Scene route.

| Purpose | Canonical URL |
|---|---|
| Global narrative Scene list | `/u/:universe_slug/s/:story_id/scenes` |
| Scene Details | `/u/:universe_slug/s/:story_id/scenes/:scene_id` |
| Characters tab | `/u/:universe_slug/s/:story_id/scenes/:scene_id/characters` |
| Items tab | `/u/:universe_slug/s/:story_id/scenes/:scene_id/items` |
| Locations tab | `/u/:universe_slug/s/:story_id/scenes/:scene_id/locations` |
| Elements collection/mutations | `/u/:universe_slug/s/:story_id/scenes/:scene_id/elements` and member URLs beneath it |

Rails route definitions eventually generate the URLs above with explicit `story_id` and
`scene_id` keys. Every call site passes route keys by name. The left-sidebar **Scenes** placeholder
remains non-functional until slice 11.1 ships a real story-scoped destination.

### Scene list and editor skeleton

The global Scenes index is a flat list in canonical narrative order, not a section-grouped view.
Each row previews:

- Title and short description;
- an explicit **Ungrouped** indicator or the Section's full ancestor path;
- Scene Tag badges;
- Element count and participant count;
- add/edit/delete or read-only state as appropriate;
- visible **Move up** and **Move down** controls when the user can write.

The row order uses Scene `position`, not Section position, Event chronology, or the Scene datetime.
Drag-and-drop may be added later but cannot be the only ordering mechanism.

**Scene Details** is a stable full-page editor with URL-backed workspace tabs for **Details**,
**Characters**, **Items**, and **Locations**. Details contains Title, description, optional Section,
optional Event, optional datetime, optional Scene Tags, and the ordered Element list. Selecting a
Section changes organization only; it never changes the Scene's narrative position. The Elements
list stays under Details in the first version.

The Characters, Items, and Locations tabs show linked universe records with their optional roles and
provide add, remove, and role-edit flows. They show no mutation controls to guests or read-only
members. Duplicate links are prevented by database uniqueness and must also be handled as ordinary
validation errors in the interface.

The first Section-grouping flow has two complementary paths:

1. A Scene's Details form assigns it directly to **Ungrouped** or one Section in the current Story.
2. The Sections workspace provides a separate grouped outline with accessible move controls that
   change only the Scene's `section_id`.

The global Scenes list remains canonical and keeps narrative order after any grouping change. No
first slice depends on drag-and-drop.

### Element modal and response formats

The Scene Details page includes an **Add element** action opening a Bootstrap modal. The same modal
edits an existing Element and contains:

- kind selector (**Narration** or **Dialogue**);
- required Title;
- optional plain-text Content;
- a many-speaker picker shown and required for Dialogue;
- no speaker control for Narration.

Narration and Dialogue have explicit, understandable labels. Validation and network errors remain
visible in the modal, the modal does not close on failure, and deleting a row or moving an Element
updates list and count state reliably. These are prerequisites in slice 11.5; Scene Elements must
not depend on the current known-broken HTML-to-JSON submission and stale-DOM behavior.

The response architecture is deliberately per controller:

| Flow | Actions | Response |
|---|---|---|
| HTML | Scenes index/show/new/create/edit/update and narrative-order moves | redirect or re-render with errors |
| JSON | SceneElement CRUD and role-bearing SceneCharacter/SceneItem/SceneLocation CRUD | JSON success payloads or `422` error hashes |

No action accepts ambiguous HTML and JSON mutations merely to make a form work.

### Access, scope, and implementation constraints

- Public-universe guests may read the global Scene list, Scene Details, each related tab, and its
  Elements. Every mutation requires authentication and the shared Universe write policy.
- Private-universe visibility and read/write/admin behavior remain unchanged: non-members receive
  404, known members with insufficient access receive 403, and universe admins retain their existing
  settings authority.
- Controllers load every Scene through `Current.universe.stories.find` and then the Story's Scenes;
  they never use an unscoped `Scene.find`.
- Same-Story and same-Universe associations are application-level rules. Real foreign keys protect
  referenced rows, but do not prove shared scope.
- Every Scene-owned model is registered with `Ability` and can resolve its Universe through Scene,
  including Element, speaker, and presence-link records. Shared helpers use the same resolver.
- Unknown optional Section, Event, Character, Item, Location, or Element IDs become documented
  validation/404 responses, never uncaught foreign-key 500s.
- Lists preload the records needed for Section paths, Tags, Elements, participants, and counts.
  Speaker-derived participation is displayed distinctly and is not double-counted as an explicit
  presence link.
- Delivery includes model, request, authorization, route, and focused browser coverage, connected
  per-universe development data, the shared loader registry, matching documentation, and a dated
  changelog entry.

### Deletion contract and confirmation copy

Deletion remains asymmetric so shared world records survive:

- deleting a Scene removes its Elements, tag assignments, speaker links, and presence links;
- deleting a Story cascades its Sections, Section Tags, Scene Tags, Scenes, and all Scene-owned descendants;
- deleting a Section removes its child Sections and clears Scene grouping while preserving Scene
  narrative positions;
- deleting an Event clears Scene Event references but never deletes a Scene;
- deleting a Character, Item, or Location removes its Scene presence/speaker links but never deletes
  a Scene or any other shared world record.

Soft deletion is deliberately deferred as backlog item 20 and is not part of slice 11.0. The
hard-deletion behavior and confirmations below are the contract for the future implementation; a
future soft-delete ADR must revisit restore behavior, relation tracking, visibility, and uniqueness
before any model gains `deleted_at`.

Destructive controls use these exact templates, substituting the displayed record name:

- **Scene:** `Delete “#{scene.name}”? Its elements, tag assignments, and links to story and universe records will be permanently removed. Linked records will not be deleted.`
- **Story:** `Delete “#{story.name}”? Its sections, section tags, scene tags, scenes, scene elements, and story-owned links will be permanently deleted. Shared universe records will not be deleted.`
- **Section:** `Delete “#{section.name}”? Its child sections and tag assignments will be removed, and linked scenes will become ungrouped. Their narrative order will not change.`
- **Event:** `Delete “#{event.display_string}”? Scenes linked to this event will remain, but their event links will be cleared.`
- **Character, Item, or Location:** `Delete “#{record.name}”? Its links to scenes will be removed. The scenes and all other shared universe records will remain.`

The implementation may add surrounding accessibility text, but it does not omit the consequences
shown in these confirmations.

## Consequences

### Benefits

- Story structure gains an explicit narrative sequence without duplicating shared world data.
- Section grouping and in-world chronology remain independent and visible as such.
- The writing model supports narration, dialogue, and role-bearing participation while remaining
  extensible for later analyzers.
- URL-backed workspaces and accessible move controls support desktop, touch, and keyboard users.
- Clear ownership and deletion contracts prevent Scene deletion from destroying shared facts.

### Costs and constraints

- The feature spans several persisted models and requires a staged delivery sequence.
- Flat Scene and Element ordering needs its own transactional maintenance; the existing
  `Hierarchical` and `MaintainsSiblingPositions` contracts must not be reused as though these
  sequences were parent/child trees.
- The same-Universe application validations, authorization resolvers, and uniqueness indexes must
  be applied consistently across every presence and speaker link.
- The first version stores free-text roles and dialogue blocks that are useful for continuity but
  cannot prove turn-level attribution, causality, or prose consistency.
- Scene datetime initially follows the existing Event contract. A later shared precision/timezone
  decision must update Events and Scenes together rather than creating a Scene-only exception.

## Alternatives considered

### Keep Sections as the only story sequence

Rejected because a hierarchical organizational tree cannot represent a single stable narrative
order independent of grouping, prose Elements, or participation links.

### Make every referenced record story-scoped

Rejected because it would duplicate characters, items, locations, and events across Stories and
make cross-story continuity harder to maintain.

### Merge Scene and Event

Rejected because narrative presentation and in-world fact have different lifecycles. Several Scenes
can depict one Event from different contexts.

### Give each Scene exactly one Event

Rejected as the first-version requirement. A Scene may have only an Event, only a datetime, both,
or neither, and the two values remain independent.

### Use Active Record's `type` column for Element kind

Rejected because `type` is reserved for single-table inheritance. The explicit `kind` column is
validated as `narration` or `dialogue` in both model and database checks.

### Require Element Content

Rejected. Element Title is required, while Content is optional so authors can persist an unfinished
Element without inventing prose or a second mandatory heading.

### Allow Dialogue with no speakers

Rejected. Once an author chooses Dialogue, at least one same-Universe Character must be identified;
unfinished Scene structure is represented by an Element-free or optional-field Scene instead.

## Related documentation

- [`0001-universe-and-story-scope.md`](0001-universe-and-story-scope.md)
- [`../architecture.md`](../architecture.md)
- [`../data_model.md`](../data_model.md)
- [`../universe_maker_conventions.md`](../universe_maker_conventions.md)
- [`../visual_design.md`](../visual_design.md)
- [`../development.md`](../development.md)
- [`../backlog.md`](../backlog.md)
- [`../known_quirks.md`](../known_quirks.md)
