# Scenes

[ADR 0007](../adr/0007-story-owned-scenes-and-elements.md) accepts the first Scene contract, and the
whole of it is implemented. This is the one home for the Scene domain, its six workspace tabs, its
Elements, and the deletion and validation rules that make them safe. The several Events a Scene may
depict are organized by [ADR 0038](../adr/0038-a-scene-depicts-events-through-ordered-links.md).

Story-level Plot assignments are a separate through-line grouping axis; their domain and editor are
owned by [Plot arcs](plots.md), not duplicated here.

Story- and Scene-level trope annotations use the shared curated reference list described in
[Tropes](tropes.md); they are distinct from the Story-local Scene Tag taxonomy.

Schema is in [data_model.md](../data_model.md#stories--sections); the page patterns the Scene pages
reuse are in [conventions.md](../conventions.md#views---three-patterns).

## Model and scope

`Scene belongs_to :story`, includes `HasSlug`, and is **flat rather than hierarchical** — no
`parent_id`. A required `name` is labelled **Title**; `description` is optional and a title-only Scene
is valid. `belongs_to :section, optional: true` carries the organizational group, and the single
optional `datetime` carries the in-world time point. The Events a Scene depicts are its own ordered
link rows (`SceneEvent`), so a Scene may depict several; each link carries the author's free-text
`role` and a `position`, and `Scene#event_id` no longer exists. `belongs_to :pov_character,
class_name: "Character", optional: true` names the single character whose perspective presents the
scene; it must belong to the scene's universe and is independent of both the Event links and the
in-world time. The Event links and the datetime are **independent**: neither writes, clears, nor
validates against the other, and a disagreement between them is not detected. Blank means no point of
view is recorded. `has_many_tags :scene_tag, scope: :story_id` supplies optional Story Tag
assignments. `Scene#universe` resolves through `story.universe`.

`SceneTag belongs_to :story`, includes `Hierarchical`, `HasColor`, `HasSlug`, and the inverse
`has_many_tagged :scene, scope: :story_id`. Definitions use the same positioned controller contract as
Section Tags, while the Scene form uses `scene_tag_ids` and the shared scoped association; no default
tag is assigned.

A `Story` owns the contiguous, narrative-order `Scene.position`. A Scene never causes a Story to be
selected implicitly, and the global Scene list is ordered by `(position, id)` and is **not** grouped
by Section. `ScenesController` uses the flat mode of `PositionedResourceOrder` through
`maintains_flat_positions_for :scene` with `@story` as the sibling collection and scope owner.

## Ownership resolution

`UniverseScopeResolver` is the single answer to which universe owns a record. `Ability#universe_for`
and `ApplicationHelper#universe_for_record` both delegate to it, so record-level authorization and the
mutation controls a view renders cannot drift. It resolves a record through its own `#universe` or
through a declared owner association (`story`, `scene`, `section`, `scene_element`). `SceneElement`,
`SceneCharacter`, `SceneItem`, `SceneLocation`, and `SceneEvent` all reach their Universe through
`scene`, so none needs a new entry; `SceneDialogueTurn` delegates through its `scene_element`. Do not re-implement the
walk in a view or a controller, and do not add a controller-specific visibility rule.

Controllers resolve `@story` through `Current.universe.stories.find(...)`, then Scenes through that
Story, and Scene-owned records through that Scene. Never use `Scene.find`, a universe-level Scene
route, or a controller-specific visibility rule. Public read actions still pass through the shared
authorization callback.

## Validation, not exceptions

Same-Story and same-Universe scope is an application rule: a real foreign key cannot prove it. The
`Scene` model adds `section_belongs_to_story`, `optional_references_exist`, and
`datetime_is_a_valid_point`. A malformed `section_id` therefore renders a `422` field error through
the ordinary HTML re-render flow instead of raising a foreign-key exception, and an unparseable
`datetime` is reported instead of being silently cast to `nil`. The editor re-renders the submitted
raw value, so a rejected entry is never cleared from the field.

`SceneEvent` proves the Event it links is real, belongs to the Scene's Universe, and is not already
linked to the same Scene while the link is live; a blank link is refused. Its unique index is partial
over live rows, so a removed link can be created again without resurrecting the old one.

The Scene-owned records prove their shared Universe the same way: `SceneElement#speakers_belong_to_the_scene_universe`,
`SceneDialogueTurn#speaker_belongs_to_scene_universe`, `SceneCharacter#character_belongs_to_the_scene_universe`,
`SceneItem#item_belongs_to_the_scene_universe`, `SceneLocation#location_belongs_to_the_scene_universe`,
and `SceneEvent#event_belongs_to_the_scene_universe`
compare against `scene.story.universe_id`.
A `character_ids` writer on `SceneElement` turns an unknown, duplicated, or cross-Universe id into an
ordinary field error instead of a driver exception, exactly as `Scene#scene_tag_ids=` does, and a
direct association assignment is checked by the same validation. The same-Universe rule is also in
each controller, where a foreign id is a `404` because the record is resolved through
`Current.universe`. The development-data loader proves it a third time: a Scene-owned record's
Universe is resolved through its Scene, and a manifest may only reference records from its own
universe directory. `scene_elements` additionally carries a database `check_constraint` on `kind`, and
the four Scene-owned join tables carry real foreign keys and a unique pair index, so every uniqueness
rule is proved in the model *and* the database.

## Routes and responses

| Purpose | Canonical URL | Mutation response |
|---|---|---|
| Global Scene list | `/u/:universe_slug/s/:story_id/scenes` | HTML |
| Scene Details | `/u/:universe_slug/s/:story_id/scenes/:scene_id` | HTML |
| Narrative-order move | `PATCH /u/:universe_slug/s/:story_id/scenes/:id/move` | HTML |
| Section grouping | `PATCH /u/:universe_slug/s/:story_id/scenes/group` | HTML |
| Scene Tag taxonomy | `/u/:universe_slug/s/:story_id/scene_tags` | JSON mutations, HTML index |
| New / Edit Scene | `.../scenes/new`, `.../scenes/:id/edit` | HTML |
| Scene Elements | `.../scenes/:scene_id/elements`, `.../elements/:id`, `.../elements/:id/move` | JSON only |
| Scene Dialogue Turns | `.../elements/:scene_element_id/dialogue_turns`, `.../dialogue_turns/:id`, `.../dialogue_turns/:id/move` | JSON only |
| Scene Events tab | `.../scenes/:scene_id/events`, `.../events/:id`, `.../events/:id/move` | HTML index, JSON mutations |
| Scene Characters tab | `.../scenes/:scene_id/characters` | HTML index, JSON mutations |
| Scene Items tab | `.../scenes/:scene_id/items` | HTML index, JSON mutations |
| Scene Locations tab | `.../scenes/:scene_id/locations` | HTML index, JSON mutations |
| Scene Tropes tab | `.../scenes/:scene_id/tropes` | HTML index, JSON mutations |
| Story-wide Scene matrix | `/u/:universe_slug/s/:story_id/scene_matrix` | Read-only HTML |

Scenes have no Universe-level route. Every Scene and Scene Tag route includes its Story, and all
route-helper keys are passed by name.

`ScenesController` answers HTML only and follows the redirect/re-render flow: a successful
create/update redirects to Scene Details, a move redirects back to the list with a `303`, and grouping
redirects back to the Sections workspace with a `303`. The Scene record flow never uses the shared
modal path, so it inherits nothing from it. Element and presence-link mutations reuse
`modal_form_controller.js` under
[ADR 0011](../adr/0011-modal-json-mutation-contract.md) instead of a second editor, so their JSON
submission, `422` rendering, pending state, and post-mutation refresh are the same contract already
covered for Characters, Items, and Events. The nested turn editor uses `scene_turns_controller.js`
for add/edit and hands move/delete to `modal_form_controller.js`; all four turn actions preserve the
same JSON, error, pending, and server-refresh behavior.

`SceneDialogueTurnsController` has no read action — turns are read with their Element on Scene Details.Create, update, delete, and move are JSON-only and pass through `RequiresJsonMutationFormat` before
writing. In `direct` mode, create returns `201`, update and move return `200`, each with the JSON
fields `id`, `speaker_id`, `speaker_name`, `body`, `parenthetical`, `position`, `update_url`,
`move_up_url`, `move_down_url`, and `destroy_url`; delete returns `204` with no body. In other
collaboration modes, the shared `DraftMutation` contract remembers the change and returns `202` (see
[architecture.md](../architecture.md#response-formats-per-controller)).
The turn is resolved through the request's authorized Universe → Story → Scene → Element path; a turn
belonging to another Element is a `404`. An unknown or other-Universe speaker is a `422` model error,
a narration Element refuses a turn with `422`, and an unknown move direction is `400`. Guests cannot
mutate and are sent to sign in; a read-only member receives `403`. HTML mutations are refused with
`406` before any write. CSRF protection applies to all four mutation verbs.

`SceneEventsController` follows the same read-page/JSON-mutation contract as the presence tabs. Its
links are resolved through the request's authorized Universe → Story → Scene path, so a link belonging
to another Scene, Story, or Universe is a `404`. Create returns `201`, update and move `200`, delete
`204`; a draft-based universe remembers the change and returns `202`. An Event that is unknown or from
another Universe is a `404`, a duplicate link is a `422` model error, a missing `event_id`,
an unknown `direction`, or an update with neither editable field is a `400`, and an HTML mutation is
refused with `406` before any write. Move is the only way to reorder the links.

Documented per-action failures: a malformed `section_id`/`datetime` or foreign Scene Tag
assignment in the editor is a `422` re-render; a foreign or unknown grouping target, scene, Element,
dialogue turn, event link, presence link, or Character is a `404`; a missing or unknown `direction`, a create with
no `character_id`, or an update with neither field is a `400`. `SceneElementsController` has **no** read
action — Elements are read on Scene Details — so every one of its actions is authenticated and none of
them may be reached with an HTML request.

A move is a single transactional service call: the controller converts `direction=up|down` into the
neighboring target position and lets `PositionedResourceOrder` clamp and normalize, so a move at a
sequence boundary is a no-op with explicit flash copy rather than a partial write. An unknown
`direction` is a `400`, never a silent success.

Grouping is a different kind of change, so it is a different action: `ScenesController#group` posts
the chosen `scene_id` and `section_id` to `/scenes/group` (a collection route, so the workspace form
needs no client-side scripting) and resolves the Section through `@story.sections.find`. A Section from
another story or universe is a `404`. Both keys are required, and a blank `section_id` is the explicit
**Ungrouped** choice — `params.expect` rejects a blank scalar, so that one key is checked for presence
directly. The flash copy always states that the narrative position did not change.

## The list, the filter, and the ordering

A Story can hold hundreds of Scenes, so the canonical list narrows with a GET search area instead of
growing without limit. `SceneFilter` (`app/models/scene_filter.rb`) is the value object that owns this
list's keys: `q` (title and short description), `section_id` (a Section of this Story or the literal
`ungrouped`), `scene_tag_id` (a Scene Tag of this Story), and inclusive in-world `from`/`to`
**days**. Filters combine with `AND`. It is a `ListFilter`, so the contract it shares with every other
workspace's filter — how a value is validated and dropped, what a canonical query is, how a filtered
list treats pending rows, and what an empty result says — is in
[`list_filters.md`](list_filters.md), not here. What is this list's alone:

- The filter never reorders, regroups, or renumbers. `Scene#position` is the only order there is, so
  this list has no sort control; a workspace that offers one is making a different decision, in
  [`list_filters.md`](list_filters.md#what-this-contract-does-not-decide).
- A filter value is validated against the already-loaded story-scoped lists, so a foreign or unknown
  id is dropped and reported instead of reaching the query. The tag filter narrows through the scoped
  inverse association (`SceneTag#tagged_records.select(:id)`), so it cannot disclose another Story's
  scenes.
- The position badge, the story total, and the Move boundary state come from the whole sequence — one
  aggregate query (`COUNT(*)`, `MIN(position)`, `MAX(position)`) — never from the filtered rows, so a
  narrowed list cannot mistake its first visible row for the first scene of the Story.
- The index redirects a form submission once (`302`) to the canonical query, and the recognized keys of
  a `move` or `destroy` are carried back to the same list. Both come from `FilteredListQuery`; the one
  thing it cannot know is where this list's own URL is, which is `ScenesController`'s
  `#filtered_list_path_with`.
- The two empty states are this list's own words: a Story without scenes says **No scenes yet** (and
  only a writer is told to add one), while a filter matching nothing says **No scenes match these
  filters**, repeats the active filters, and offers **Clear filters**.
- Add a new key in `SceneFilter::PARAMS`, in the form, and in the helper that labels it — not in a
  controller condition.

The page states that the order is the order the story is told, not in-world chronography, and that a
section group only organizes a scene. Move up/Move down are real `button_to` forms that post
`direction=up|down`, are keyboard operable, and are disabled at the boundaries. Section assignment is a
separate action that changes only `section_id` and never touches `position`. Do not add a second
ordering path or a drag-only control.

A Scene's **Element** sequence follows the same rules inside its own Scene, except that its endpoint is
JSON-only: there is no Turbo form to follow, so the visible Move buttons are issued by
`modal_form_controller.js#move`, which `PATCH`es the same `move` action and then performs the same-URL
refresh a save performs.

## Narrative order beside the Timeline

The Story workspace's **Narrative order** tab
(`GET /u/:universe_slug/s/:story_id/narrative_order`) is a signed-in, read-only comparison of the
Story's `Scene.position` sequence with the Universe Timeline. `NarrativeOrdersController#show`
resolves the Story through the request's `Current.story` and builds `TimelineLayout` over the
universe's Events, so the page cannot disagree with the Timeline about Event order. It has no
mutation route, no form, and no stored result. The design reasoning is in
[ADR 0037](../adr/0037-compare-narrative-order-with-the-timeline-read-only.md).

The tab is the one signed-in destination in the Story strip: a guest is sent to sign in and is not
shown the tab. After authentication the ordinary universe read rule applies — any signed-in reader
may open it on a public universe, and a private universe keeps its owner/membership rule. The strip
is built by `StoryWorkspaceHelper#story_workspace_tabs`; every Story workspace page uses that one
helper, so another destination is added in one place rather than copied into the page views.

**A conflict is one Scene, not a disagreement between the two orders.** `Scene.position` orders
telling and the Timeline orders happening, so a reversal is a flashback, a parallel thread, or a
cold open, never an error. The page reports a conflict only when a Scene links Events with a known
start or end and the Scene's own `datetime` falls outside **every** one of their intervals — before
every start or after every end. A time inside any linked Event is consistent with at least one fact
the Scene records; a `datetime` with no Event link, and an Event with no dates, claim nothing to
disagree with. The Event supplies the timeline place; the `datetime` is shown beside it and is never
used to move it. Nothing is rewritten, normalized, or resolved.

**A Scene is placed by the earliest of its Events the Timeline can place.** A Scene with no Event link
is *unlinked*; a Scene whose Events all lack a place is *unsequenced*. The link order breaks a tie
between Events in the same Timeline row. Both unlinked and unsequenced end the current *run*, so the
next placed Scene starts a new run and is labelled **First in this run**; the comparison never reaches
across a gap. Inside a
run the step is **Later**, **Earlier**, **Same time** (the placement Events share a simultaneity group), or
**No known order** (the same row, different groups). `TimelineLayout#layer_for`, `#placed?`, and
`#same_group?` are the read-only authority for those facts; do not recompute them in the view or the
controller. The left column lists every Event the Scene links, in the Scene's own order, so the
placement Event is never the only one named.

The page shows the whole Story and the whole Universe Timeline: no filter, sort, or pagination,
because a narrowed sequence is not the telling order and a filtered Timeline is not the Timeline.
The right column is the Timeline's own rows with the narrative positions of this Story's Scenes
attached; Events this Story never depicts stay visible but secondary, and Events with no recorded
time sit in a separate **No recorded time** group instead of an arbitrary numbered row. The left
column is the whole narrative sequence with each Scene's own time and step. Pending draft changes
are not projected: the page reads saved records, like the Timeline.

## The Story-wide Scene matrix

`GET /u/:universe_slug/s/:story_id/scene_matrix` (`SceneMatricesController#show`) is the whole Story as
a table: one row per Scene in `(position, id)` order and one column for each fact the Story already
stores on it — Section path, Scene Tags, point of view, in-world time, linked Events, Element count,
word count, and participant count. It is the table counterpart to the Appearance grid, reached from
`StoryWorkspaceHelper#story_workspace_tabs`, and it is a **read**: no form, no mutation route, no CSRF
surface, no stored result, and no JavaScript.

- **Rows and columns are the whole Story.** There is no filter, sort, or pagination: a narrowed matrix
  is not the Story at once, and `Scene#position` stays the only order. Section grouping is a column,
  never a second grouping of the table, because grouping does not change the telling order.
- **Every fact is already stored.** `SceneMatrix` preloads each Scene's Section, point of view, Scene
  Tags, and Event links; the Element and participant counts are one grouped query each; and the prose
  column is `WordCounts#for_scene`, the per-Scene reader over the Story's existing totals. A Story of
  hundreds of Scenes costs the same number of queries as a short one.
- **Presence is the union, not a sum.** The participant count is `SceneParticipants.counts_by_scene`,
  so it is the same number the Characters tab, the Scenes list, and the Appearance grid report. A
  Character who both participates and speaks is counted once, and a prose mention never adds to it.
- **An absent fact is stated, not left blank.** An untagged Scene says **No tags**, one with no
  recording says **No point of view recorded** or **No in-world time recorded**, and one with no link
  says **No events linked**. A zero count is a real measurement and stays a number.
- **Every row links out rather than editing in place.** The Scene title opens Scene Details, and each
  linked Event opens its own Universe page. The page never becomes a second editor with its own
  validation; writing stays on the ordinary draft-backed Scene form.
- **Access follows the Story.** A guest may read a public Universe's matrix, a private Universe keeps
  its owner/membership rule, and another Universe's Story is a `404`. An empty Story says **No scenes
  yet**, with the writer's copy offering the first Scene and the read-only copy not doing so.

The table is its own accessible equivalent, and its painted rules are in
[visual_design.md](../visual_design.md#scene-matrix).

## Elements

`SceneElement belongs_to :scene`; it is an ordered child component rather than a standalone navigable
content model, so it has no public slug requirement, and it is flat rather than hierarchical. Its
`kind` is `narration` or `dialogue` — **never** a column named `type`, which Active Record reserves
for single-table inheritance — and both the model validation and a database `check_constraint` enforce
the pair. `name` is required and labelled **Title**, `body` is optional and labelled **Content**, and
`position` is flat and contiguous inside its own Scene. `position` is deliberately **not** a permitted
form field: the Move controls are the only way to order Elements.

The Element list and its modal render on Scene Details (`scenes/_elements`), because the Scene above
it already carries identity, references, and tags; splitting the prose onto a second page would add
navigation without adding meaning. A Scene may hold any number of Elements, including none, so the
empty state says so instead of implying a Scene is unfinished.

**Narration and Dialogue are the same editor with two different sets of rules**, so the modal offers
an **Element type** selector, a required **Title**, an optional **Content** textarea, and a
many-speaker **Speakers** picker. `scene_element_form_controller.js` owns only the presentation of
that rule (show the picker for Dialogue, offer the remove-speakers confirmation when needed); the
server is what enforces it. Hide a control, never disable it, when its value still has to be
submitted: a hidden picker is still submitted so the server can see there is something to confirm, and
the confirmation then sends an empty speaker list in the same request, which is the only way a
Dialogue becomes Narration. A dialogue's own copy states the limitation out loud — the link records
who is in the conversation, not which line belongs to whom.

**Block-level speakers** remain a plain many-to-many link (`has_and_belongs_to_many :characters,
join_table: :scene_element_speakers`): the roster says who speaks in the block, without assigning
individual lines. A Dialogue must name at least one same-Universe Character in this roster; Narration
may name none.

`SceneDialogueTurn belongs_to :scene_element` and records one line's same-Universe `speaker`, optional
plain-text `body`, optional `parenthetical`/delivery note, and flat contiguous `position` within that
Element. It has no URL, public slug, or independent Universe; its Universe is resolved through
`scene_element → scene → story → universe`. Narration Elements cannot carry turns. The roster and turns
are independent levels of attribution: neither is inferred from nor automatically writes the other.
Both contribute to derived speaker participation and appearance, with duplicates collapsed to one
Character/Element; neither creates a `SceneCharacter` presence link. `position` is not a form field;
only the editor's Move up/Move down operations change turn order. The table, manifest reference, and
validation details are in [data_model.md](../data_model.md).

The ordered turns are edited inside the existing **Elements** modal, not on a new page. A new Element
must first be saved as Dialogue so it has a scoped id; reopening it then exposes the turn editor. The
modal shows each turn's speaker, line, and optional delivery note, and supports adding a turn, editing
those three fields, and moving a turn up or down, with sequence-boundary moves disabled. The speaker
picker uses the same Universe Character choices as the block-level roster, but selecting a turn
speaker never changes that roster. Switching an Element to Narration hides the add controls while
keeping existing turn rows available to remove; the server refuses to save Narration while any turns
remain. Turn mutations use the nested JSON-only endpoints and server-provided scoped URLs. Every
successful mutation refreshes the page from the
server, including remembered draft changes, so derived participation stays current and an unpersisted
draft receipt is never shown as a saved turn. Every visible label, confirmation, and empty/save-first
message is localized.

A registered Character name written in an Element body is marked on Scene Details by the prose mention
index, which is a separate read and never creates presence; its rules are in
[mentions.md](mentions.md).

## Participation is a union, never a sum

This is the single most repeated rule in the Scene system, and it is one rule:

- `SceneCharacter belongs_to :scene` and `belongs_to :character` and carries a nullable free-text
  `role`, so it is a join model rather than a HABTM association. A blank role means no role and is
  never checked against a vocabulary.
- `SceneItem belongs_to :scene` and `belongs_to :item`, and `SceneLocation belongs_to :scene` and
  `belongs_to :location`, with the same nullable free-text `role` and the same same-Universe rule. They
  are join models for the same reason.
- Participation has **two independent sources** and nothing merges them into one stored row: an
  explicit `SceneCharacter` link, and a Character who speaks in one of the Scene's Dialogue Elements.
  Speech is derived from the union of the block-level roster and line-level turns. `SceneParticipants`
  reports the union — a Character who both participates and speaks is one participant, never two.
  Never create a presence row for a speaker, and never add the sources together for a count.
- Speaking is **not** a presence link: it never creates a `SceneCharacter` row.
- `SceneAppearances` is the same union in the reverse direction, and adds each Event link as a
  third source, so it is also a union and never a sum.

The Story-wide grid that reads this union beside the prose mention layer is in
[appearances.md](appearances.md).

The Characters tab (`/scenes/:id/characters`) is a real read page — a guest and a read-only member see
exactly what a writer sees minus the controls. Its rows are one per Character in the union, ordered by
name: a stored `SceneCharacter` link labelled **Participant** showing its role or **No role recorded**,
and a Character who only speaks labelled **Speaks in N element(s)** and naming the Elements, with no
add/edit/remove menu at all, because there is no stored row to act on. A Character who is both carries
both labels on a single row. A duplicate is the model's uniqueness error rendered in the modal rather
than a hidden option, since a stale page or a second window can submit one anyway. Removing a link
never removes a Character, and never changes who speaks in an Element: those are separate links with
separate consequences.

`/items` and `/locations` follow the same page shape — a read page whose mutations are JSON-only — with
one difference that follows from the domain: neither an Item nor a Location has a derived second
source, so there is no union to reconcile and no row without a link. Every row is a stored link, and
the row list, the page count, and the count a mutation changes are the same rows. The Locations tab is
plural and hierarchical, so each row carries its full ancestor path from `LocationPaths` and the picker
is depth-indented in root-first order. Both tabs offer every Universe Item/Location, because those
records are shared by every Story in the Universe.

The **Events** tab (`/scenes/:id/events`) is the Scene's link to the Universe's shared Events. It is a
real read page — guests and read-only members see the same list without the controls — and its rows are
the Scene's `SceneEvent` links in their own order, each naming the Event and the author's role or **No
role recorded**. **Add event** opens the shared editor with a picker of every Universe Event and an
optional free-text role; a row can repoint its Event, edit the role, move up or down, or be removed. A
Scene may depict any number of Events, and the same Event may be depicted by any number of Scenes;
neither side copies the other. Removing a link deletes neither the Event nor the Scene and never
touches the Scene's `datetime`. The role is never a vocabulary, and the picker offers every Event
rather than hiding the ones already linked, so a duplicate submitted by a stale page is an ordinary
`422` rather than a missing option. The links reach the Universe through their Scene, so only the
Scene's own tabs can change them.

The **Tropes** tab (`/scenes/:id/tropes`) has the same page shape and mutation contract, but its rows
are catalogue assignments rather than shared universe records: it lists only the references this Scene
carries, with each one's description, craft note, source, and context note. **Add trope** opens the
shared editor with a picker of the whole code-owned catalogue (alphabetical and searchable) and an
optional context note; a row can re-annotate or withdraw its assignment. A new Scene has no
assignments to show, so the tab's empty state points at **Add trope** rather than at the Scene editor.
The catalogue, the Story-level annotation that remains on the Story form, and the annotation rules are
owned by [Tropes](tropes.md).

Every one of these modal tabs must wrap `data-controller="modal-form"` in a wrapper element that
contains the modal **and** every control that opens it, because a Stimulus target outside the
controller's element is not a target and the editor would silently never connect.

## Path value objects

`SectionPaths`, `SceneTagPaths`, and `LocationPaths` are value objects, not tables. Each turns one
ordered list into every root-first ancestor path and the depth-indented selector options, so neither
the Scenes list nor the Sections workspace walks ancestors per Scene. Preloading an arbitrary tree
depth with `includes` is not possible and `ancestor_chain` would query per level per Scene, so list
pages build the index once instead.

## "Appears in scenes" traces a record forward

The Character, Item, Location, and Event details pages each end with an **Appears in scenes of
&lt;Story&gt;** section, the reverse of the Events, Characters, Items, and Locations tabs. It is deliberately not a new workspace: the same
links would be broken if it were. `SceneAppearances` reports the **union** of a stored presence link, a
derived Dialogue speaker, and an Event link — one row per Scene, never a sum — ordered by Scene
`position`. A row is labelled with the reason(s) it appears, so **Linked**, **Speaks in N element(s)**,
and **Depicted** are never collapsed into a single word, and a role is only ever shown for a stored
link. The whole section is read-only navigation, so it renders for every access level: the Scenes it
points at are readable by exactly the people who can read the record it is attached to, and every link
carries an explicit `story_id` because a Scene has no Universe-level URL.

The section is scoped to `Current.story`. With no Story selected there is nothing to list, so the
section says so and offers the story list — the same explicit selection the sidebar asks for, never a
fallback to the Universe's first Story.

A Location's details page adds one step to this: its **Who is here** section names the participants
and factions of each Scene that happens there. That section is owned by
[features/locations.md](locations.md); it reads the same participation union and adds no second way
to record presence.

## The Sections workspace's ungrouped block

The Sections workspace keeps its taxonomy tree and adds an **Ungrouped scenes** list below it: only
the Scenes that belong to no Section, in canonical narrative order, because a grouped Scene is read on
its own Section's page. The badge above that list states how many ungrouped Scenes it holds
(`scenes.grouping.count`, a pluralized label rather than a bare figure or an appended "s"), and the
move form offers only the
ungrouped Scenes of that list: the form belongs to the Ungrouped block, so a grouped Scene is
regrouped from its own Section's page through the editor's Section selector instead. The form is not
rendered at all when nothing is ungrouped. Drag-and-drop is not offered, so the move is always
available by keyboard and on touch. Read-only members and guests see the same list with no controls,
and the tree's read-only empty state has its own copy, so a read-only member is not told to add or
drag records.

## The editor and its tabs

Scene Details (`/scenes/:id`) is the canonical, inspectable page: it renders the Title, narrative
position, short description, Section group, Scene Tags, linked Events, formatted in-world time, point
of view, and story context for writers, read-only members, and guests, and gives only writers an
**Edit scene** action. The form lives once, at `/scenes/:id/edit` (`scenes/_form`, reused by `new`), so
there is no second edit surface and no second form for the same fields. The editor's workspace tabs go
through `shared/_content_tabs`: **Scene Details**, **Events**, **Characters**, **Items**, **Locations**,
and **Tropes** are all live links, each its own canonical page. A tab is never a link to a route that
does not exist and never an in-document Bootstrap pane.

The Scene form groups its fields: **Scene tags** holds the optional native multi-select with root-first
tag paths, **Organization** holds the Section selector (with **Ungrouped** and depth-indented Section
names), and **In-world time** holds the `datetime-local` field plus a note pointing at the Events tab.
Each field has copy stating what it does *not* do. The Event selector is deliberately **not** on this
form: a Scene may depict several Events, each with a role and an order, so the links belong to the
Events tab and a new Scene links them after it has been saved. Trope references are deliberately **not**
a field of this form either: the full catalogue is too long to stack there, so the **Tropes** tab lists
only the references the Scene carries and offers the rest through its editor's picker.

`Story#menu_scene_count` uses its own cache scope (`Story::SCENE_MENU_COUNT_SCOPE`, referenced by
`Scene` itself) so it never overwrites `menu_section_count`; `Scene` declares
`invalidates_menu_counts_for :story, cache_scope: Story::SCENE_MENU_COUNT_SCOPE`.

The editor's **Point of view** fieldset holds the optional selector — the universe's characters plus
**None** — and names the character whose perspective presents this scene. It is separate from who
takes part and who speaks: choosing one does not make them a participant, and it does not say which
lines belong to whom. Clearing it records no point of view rather than choosing nobody.

## Counts on the list

The Scenes list shows an **Element** count and a **Characters take part** count. They are read for the
whole page in grouped queries — never one query per row — and the participant count unions explicit
links, block-level speakers, and turn speakers exactly as the Characters tab does. Item and Location
counts are deliberately absent: they would need one extra grouped query each per page, and the three
workspace tabs are the place that detail belongs. Do not render placeholder counts for them.

## Word counts

A Story's prose is Element Content plus Dialogue turn lines. Each of those records stores its own
`word_count` (`WordCountable`, recomputed on every save), so no page loads a body to draw a number.
`WordCounts` sums those stored columns with four fixed queries per Story and answers two
questions: the Story's whole total, including ungrouped Scenes, and each Section's total, which
includes every descendant Section's Scenes because a parent Section is how a chapter groups its
parts. The Sections tree shows a Section's total on its row, the Section page states it as a fact,
and the Story page states the Story's total in the structure card. Element titles, turn
parentheticals, Scene descriptions, and Section descriptions are **not** counted; only prose bodies
are. `bin/rails word_counts:recount` fills the stored counts for records that predate the column.

## The deletion contract

It is asymmetric, and the asymmetry is deliberate:

- Scene-owned **Elements** and **presence links** (characters, items, locations) cascade with Scene
  or Story deletion; an Element's dialogue turns cascade with it. Scene Tag *definitions* are removed
  with their Story.
- A Scene's **trope assignments** survive a soft delete, so a restored Scene returns with them, and
  are removed when the Scene is hard-destroyed. Removing one from the Tropes tab hard-deletes that
  assignment and frees the same catalogue reference for that Scene again; the shared catalogue and
  any other Scene's assignment are untouched.
- **Join-table rows are deliberately retained**, not cascaded: a Scene's Scene Tag assignments and
  Dialogue speaker links, and a Character's tag assignments and speaker links, all survive a soft
  delete. That is what makes a **restore** complete — the record returns with its tags and speakers
  intact — and it is why `soft_delete` walks only the `soft_deletes` list and never touches a HABTM
  join table. ADR 0007's Decision section was written against the hard-delete contract and predates
  this; the divergence is recorded in that ADR's dated execution notes.
- Deleting a **Section** clears Scene references (`section_id` nullified) and deleting an **Event**
  clears the temporal reference, while preserving Scene narrative order. Neither removes a Scene.
- Deleting a shared Character, Item, or Location soft-deletes its presence links in addition to the
  existing model-dependent behavior, and never removes a Scene. Its HABTM tag assignments and
  Element-level speaker links and turn speaker records are retained, for the restore reason above.
  A hard destroy removes turn rows that reference that Character, rather than leaving an orphaned FK.
- Event retains its existing child and temporal-referrer cleanup.

A soft delete follows the shared rules in [data_model.md](../data_model.md#soft-delete): a deleted
Scene is hidden from every ordinary query, its Elements and presence links are soft-deleted with it,
and the positioned controller normalizes the remaining siblings in the same transaction. A Scene or
Element deleted **outside** that controller — a console, an import, a cascade — is normalized by the
model instead, on the same three moments every positioned record uses; the rule for which is in
[data_model.md](../data_model.md#hierarchies--positions). The exact
confirmation copy is in [ADR 0007](../adr/0007-story-owned-scenes-and-elements.md) and must not be
replaced with only "Delete {record}?" merely to save space.
