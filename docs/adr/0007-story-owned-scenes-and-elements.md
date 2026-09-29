# ADR 0007: Make Scenes story-owned narrative units with optional Elements and links

- **Status:** Accepted
- **Date:** 2026-09-25
- **Related:** [`0001-universe-and-story-scope.md`](0001-universe-and-story-scope.md), [`0002-json-crud-with-stimulus-editors.md`](0002-json-crud-with-stimulus-editors.md), [`../architecture.md`](../architecture.md), [`../data_model.md`](../data_model.md), [`../conventions.md`](../conventions.md)

## Context

Universe Maker already separates shared universe world-building from story-specific script
structure, but it has no record for the ordered scenes through which a story is narrated. A
minimal section tree is not enough to express narrative order, prose, participation, and a link to
in-world events. At the same time, characters, items, locations, and events belong to the shared
universe and must not be duplicated merely because a story uses them.

The feature needed an explicit domain and UX contract before the first Scene migration. The record
must preserve the accepted Universe/Story boundary, allow unfinished title-only Scenes, distinguish
narrative order from in-world chronology, and provide an extensible editing model without claiming
that free text alone is machine-checkable continuity data.

This decision resolves the remaining product defaults and sketches the target URLs and interactions.
It added no schema, route, controller, view, fixture, or development-data record; the deliveries
that implemented it are recorded in the dated execution notes below.

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
  `datetime` column as a single in-world time point. This is intentionally not Event's two-field
  `start_datetime`/`end_datetime` shape. It uses the same ordinary `t.datetime` storage and current
  minute-precision `datetime-local` editor semantics as Events, with no explicit timezone. The Event
  reference and Scene datetime are independent in the first version; selecting one never writes,
  clears, or validates against the other.
- A Story still becomes current only through the existing explicit selection or remembered-story
  flow. Scenes never cause fallback to a Story's first record or first Scene.

### Scene contract

A Scene persists its required title in `name` and labels that field **Title** in the interface. It
uses `HasSlug`, has a short optional description, and has the following optional references:

- one same-Story Section;
- one same-Universe Event;
- one optional in-world `datetime` (a single point, using Event-compatible storage/editor
  precision and timezone semantics, rather than Event's start/end pair);
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

Every URL above is generated by the Rails routes with explicit `story_id` and `scene_id` keys,
and every call site passes route keys by name. The left-sidebar **Scenes** entry became a real
story-scoped link with the core Scene delivery and stays a placeholder only while no Story is
selected.

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
2. The Sections workspace provides a separate grouping workspace with accessible move controls that
   change only the Scene's `section_id`. It lists the scenes that belong to no Section; a grouped
   scene is read on its own Section's page, and any scene can still be moved from or into a group
   there.

The global Scenes list remains canonical and keeps narrative order after any grouping change. No
delivery step depends on drag-and-drop.

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
updates list and count state reliably. That reliability was a prerequisite for the Element
delivery, and the shared modal JSON path it depends on is reliable in its own right — see
[ADR 0011](0011-modal-json-mutation-contract.md).

The response architecture is deliberately per controller:

| Flow | Actions | Response |
|---|---|---|
| HTML | Scenes index/show/new/create/edit/update/destroy and narrative-order moves | redirect or re-render with errors |
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

Deletion remains asymmetric so shared world records survive Scene deletion. The Scene feature does
not change existing shared-model dependent behavior:

- deleting a Scene removes its Elements, tag assignments, speaker links, and presence links;
- deleting a Story cascades its Sections, Section Tags, Scene Tags, Scenes, and all Scene-owned
  descendants;
- deleting a Section removes its child Sections and clears Scene grouping while preserving Scene
  narrative positions;
- deleting an Event clears Scene Event references but never deletes a Scene; its existing child,
  tag-assignment, and temporal-referrer cleanup remains in effect;
- deleting a Character removes its descendant Characters, Relations, Ownerships, tag assignments,
  and future Scene links;
- deleting an Item removes its descendant Items, Ownerships, tag assignments, and future Scene links;
- deleting a Location removes its descendant Locations, tag assignments, and future Scene links.

None of these shared-record deletions removes a Scene. The shared-record confirmation templates
below describe both the existing model dependents and the future Scene links. If a later delivery
changes those dependencies, it must update the copy and its tests in the same change.

This contract is about what happens to the *related* records, and it survived a later change to how
a record itself is deleted. On 2026-09-28 every content table with a user-facing delete action
gained a nullable `deleted_at`: a delete marks the column instead of removing the row, a
`default_scope` hides the record from ordinary queries, `restore` brings it back, soft-deleting a
parent cascades to its declared children, and the unique indexes that would otherwise block
re-creating the same key are partial (`WHERE deleted_at IS NULL`). The `Section` ungrouping and the
`Event` reference clearing above remain the two exceptions to the cascade. That behavior is
described in [`../data_model.md`](../data_model.md#soft-delete); the confirmation templates below are
unchanged as the recorded copy.

Destructive controls use these exact templates, substituting the displayed record name:

- **Scene:** `Delete “#{scene.name}”? Its elements, tag assignments, and links to story and universe records will be permanently removed. Linked records will not be deleted.`
- **Story:** `Delete “#{story.name}”? Its sections, section tags, scene tags, scenes, scene elements, and story-owned links will be permanently deleted. Shared universe records will not be deleted.`
- **Section:** `Delete “#{section.name}”? Its child sections and tag assignments will be removed, and linked scenes will become ungrouped. Their narrative order will not change.`
- **Event:** `Delete “#{event.display_string}”? Its child events, tag assignments, and any temporal referrers that would become unidentifiable will be permanently removed; other temporal references and Scene links will be cleared. Scenes will remain.`
- **Character:** `Delete “#{character.name}”? Its descendant characters, relations, ownerships, tag assignments, and links to scenes will be permanently removed. Scenes and other universe records will remain.`
- **Item:** `Delete “#{item.name}”? Its descendant items, ownerships, tag assignments, and links to scenes will be permanently removed. Scenes and other universe records will remain.`
- **Location:** `Delete “#{location.name}”? Its descendant locations, tag assignments, and links to scenes will be permanently removed. Scenes and other universe records will remain.`

The implementation may add surrounding accessibility text, but it does not omit the consequences
shown in these confirmations.

> **Execution note (2026-09-25, core, references, and Scene Tags):** this decision is implemented
> in full and is not superseded. The core delivery landed the `scenes` table, the `Scene` model, the
> story-scoped routes, the canonical narrative-order list with accessible Move controls, and the
> Scene Details editor. The references delivery landed the optional same-Story Section, optional
> same-Universe Event, and independent single-point `datetime` references (with the model-level
> validations that make a malformed optional ID or datetime a `422` rather than a database
> exception), the URL-backed **Scene Details / Characters / Items / Locations** tab shell, and both
> Section-grouping paths. The Scene Tag delivery landed the story-scoped `SceneTag` hierarchy, its
> constrained `scenes_scene_tags` join, the separate Story Tags taxonomy tab, optional Scene Details
> assignment, and preloaded tag badges. Two decisions above are implemented literally and are worth
> restating because they are easy to break:
>
> - The three not-yet-routable workspace tabs are `aria-disabled` placeholders, not live links to
>   missing routes, and the Editor is reachable only by the visible tab labels.
> - Grouping is a **collection** action (`PATCH .../scenes/group`) rather than a member action,
>   because the Sections workspace form posts the chosen `scene_id` next to the chosen `section_id`.
>   That keeps the move working with no client-side scripting, which the keyboard/touch requirement
>   above depends on.
>
> The `Character`, `Item`, `Location`, Element, and speaker routes remained unrouted until their
> deliveries added a real destination. Scene Tag definitions and assignment were routed with the
> Scene Tag delivery.
> `Section` and `Event` declare
> `has_many :scenes, dependent: :nullify`, so the asymmetric deletion contract and the confirmation
> templates below are live for those two records; the Character/Item/Location templates still
> describe Scene links that the presence deliveries added afterwards.

> **Execution note (2026-09-27, Elements and Character presence):** Scene Elements and Character
> presence are delivered and do not change the domain. Four decisions above were implemented and are
> worth restating because they are easy to break:
>
> - The Dialogue speaker link is a **plain many-to-many association** (`scene_element_speakers`),
>   not a join model, because it carries no data of its own and records no turn order. `Character`
>   declares the same link from its side, so deleting a Character removes its speaker links and its
>   presence links and never a Scene or an Element.
> - "the Speakers picker shown and required for Dialogue" is one native multi-select rendered by
>   the same modal for both kinds and revealed by `scene_element_form_controller.js`. The picker is
>   **hidden, never disabled**, so a hidden selection is still submitted and the server can see that
>   there is something to confirm. That confirmation is a checkbox which sends `remove_speakers`,
>   which the controller turns into an empty speaker list in the same request — the only way a
>   Dialogue becomes Narration, and it is atomic.
> - A Scene's Element sequence uses the shared service's **flat** mode with the **Scene** as the scope
>   owner, exactly as a Story is the scope owner for the Scene sequence. `position` is not a
>   permitted form field, so the Move controls are the only way to order Elements. Because the
>   endpoint is JSON-only those controls cannot be Turbo forms: `modal_form_controller.js#move`
>   issues the `PATCH` and performs the same-URL refresh a save performs, reusing the same request,
>   token, status, and refresh path as a JSON-only delete.
> - "The Characters tab should derive participation from explicit presence links plus Element
>   speakers" is implemented as `SceneParticipants`, which reports the **union** of the two sources
>   and never their sum. Speaking never creates a `SceneCharacter` row. The same object backs the
>   tab's rows and the Scenes list's per-row participant count, so the two can never disagree.
>
> **Execution note (2026-09-27, Item/Location presence and appearances):** Item presence, Location
> presence, and the reverse continuity links are delivered and do not change the domain. Five
> decisions above were implemented and are worth restating because they are easy to break:
>
> - `SceneItem` and `SceneLocation` are join models with the same nullable free-text `role` as
>   `SceneCharacter`, and the same same-Universe rule. Neither derives a second source, so their
>   tabs have no participant union to reconcile: every row is a stored link, and the row list,
>   the page count, and the count a mutation changes are the same list. `Item` and `Location`
>   declare `has_many :scene_items` / `has_many :scene_locations` with `dependent: :delete_all`,
>   so the Scene links the two templates above describe do exist.
> - The Locations tab is **plural** because the model supports many, and it is the only Scene
>   workspace whose rows are hierarchical. A linked place is named with its full ancestor path
>   (`LocationPaths`, built from one ordered universe query — the same value-object shape as
>   `SectionPaths` and `SceneTagPaths`) and the picker is depth-indented in root-first order. The
>   row list itself is a flat name order, because the ancestor path is what disambiguates two
>   places with the same name.
> - The three presence tabs keep the Characters tab's read-page/JSON-mutation split. `index` is
>   unauthenticated-readable; `create`/`update`/`destroy` are JSON-only behind
>   `RequiresJsonMutationFormat`, and both an unknown world-record id and a cross-universe one are
>   a `404`, because the record is resolved through `Current.universe`.
> - "Appears in Scenes links … always with Story context" is `SceneAppearances`, one query object
>   behind the Character, Item, Location, and Event details pages. It reports the **union** of a
>   stored presence link, a derived Dialogue speaker, and an Event reference, in Scene `position`
>   order, and it is scoped to `Current.story`. A Scene has no Universe-level URL, so with no
>   current Story the section states that and offers the story list; it never falls back to the
>   Universe's first Story.
> - "multiple Scenes can reference one Event while Scene `position` remains narrative order" is
>   the property `SceneContinuityQueriesTest` pins down: `Event#scenes` returns every Scene in
>   `position` order, and nothing in the model sorts a story by an Event's timeline or by a
>   Scene's in-world `datetime`.
>
> Every Scene-owned route in the target-URL table is live. The confirmation templates above are
> the live copy for `Scene`, `Story`, `Section`, and `Event`; the `Character`, `Item`, and
> `Location` templates are still the contract this ADR records and are not yet the copy the
> interface shows — see [`../known_quirks.md`](../known_quirks.md).

> **Execution note (2026-09-26, Scene and Section improvement pass):** the first improvement pass
> over the two shipped Scene/Section workspaces is delivered and does not change the domain. Two
> parts of the decision above were read more literally:
>
> - "a separate grouped outline" is now the **ungrouped** list plus the move form. A Section is a
>   group, not a story record with a list of its own, so the scenes inside one are listed on that
>   Section's own details page (the **Details** link on its tree row). The Sections workspace no
>   longer repeats a grouped scene. The move form offers only the ungrouped scenes it lists, so the
>   control matches the block it lives in; a grouped scene is regrouped from its own Section's page
>   through the scene editor's Section selector, which is where that decision belongs.
> - The global Scenes list stays the canonical narrative order under every view. It gained a GET
>   search area (text, Section group, Scene Tag, inclusive in-world date range) that narrows what is
>   shown without reordering, regrouping, or renumbering anything: the position badge, the story
>   total, and the Move boundary state all come from the whole sequence, and a list-embedded move or
>   delete returns to the same filter. A Story may hold hundreds of scenes, so narrowing the list is
>   a list capability, not a second order.

## Dated execution note (2026-09-30, deletion contract under soft delete)

The Decision section above describes the deletion contract in hard-delete terms. The shipped delete
is a **soft delete**, and the two differ for the HABTM join tables. Recorded here rather than by
rewriting the Decision, because that section is the record of what was decided on 2026-09-25.

- **Still cascading.** Scene-owned Elements and presence links, and the Section/Event reference
  clearing, behave exactly as the Decision states. `soft_delete` walks each model's declared
  `soft_deletes` list, and the partial unique indexes carry the matching `deleted_at IS NULL`
  condition.
- **Not cascading, deliberately.** Rows in a HABTM join table are retained: a Scene's
  `scenes_scene_tags` assignments and `scene_element_speakers` links, and a Character's tag
  assignments and speaker links. `SoftDeletable` has no join-cleanup hook, so these survive
  untouched. That is what makes a **restore** complete — the record returns with its tags and
  speakers intact — and `test/controllers/scene_elements_controller_test.rb` pins it for speaker
  links with the comment "speaker links are kept so a restore brings them back". The Decision's
  sentence "deleting a Character removes … tag assignments" is therefore not true of the shipped
  soft-delete path.
- The user-facing confirmation copy still describes the removal in the Decision's terms, because
  that copy is mandated by this ADR and has not been reworded.

The current contract is documented in
[`../features/scenes.md`](../features/scenes.md#the-deletion-contract) and
[`../data_model.md`](../data_model.md#soft-delete).

## Consequences

### Benefits

- Story structure gains an explicit narrative sequence without duplicating shared world data.
- Section grouping and in-world chronology remain independent and visible as such.
- The writing model supports narration, dialogue, and role-bearing participation while remaining
  extensible for later analyzers.
- URL-backed workspaces and accessible move controls support desktop, touch, and keyboard users.
- Clear ownership and deletion contracts prevent Scene deletion from destroying shared facts.

### Costs and constraints

This extends ADR 0002's positioned-controller convention; it does not waive the requirement to use
and test the project's sibling-position behavior.

- The feature spans several persisted models and required a staged delivery sequence; each stage is
  recorded in the dated execution notes above.
- Flat Scene and Element ordering needed its own transactional maintenance. The existing
  `MaintainsSiblingPositions` concern assumes a `parent_id` hierarchy and cannot be reused unchanged
  for these flat sequences, so the concern was generalized rather than bypassed:
  [ADR 0009](0009-transactional-position-maintenance.md) keeps the sibling-position conventions and
  their tests and adds an explicit flat mode with the Story or Scene as the scope owner.
  `Hierarchical` remains reserved for actual parent/child models.
- The same-Universe application validations, authorization resolvers, and uniqueness indexes must
  be applied consistently across every presence and speaker link.
- The first version stores free-text roles and dialogue blocks that are useful for continuity but
  cannot prove turn-level attribution, causality, or prose consistency.
- Scene deliberately uses one `datetime` field while Events use `start_datetime` and
  `end_datetime`. It follows the current Event storage/editor precision and timezone ambiguity for
  compatibility, but this is a deliberate field-shape choice rather than an accidental omission. A
  later shared precision/timezone decision must update Events and Scenes together rather than
  creating a Scene-only exception.

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
- [`0002-json-crud-with-stimulus-editors.md`](0002-json-crud-with-stimulus-editors.md)
- [`../architecture.md`](../architecture.md)
- [`../data_model.md`](../data_model.md)
- [`../conventions.md`](../conventions.md)
- [`../visual_design.md`](../visual_design.md)
- [`../development.md`](../development.md)
- [`../known_quirks.md`](../known_quirks.md)
