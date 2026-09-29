# Scenes

[ADR 0007](../adr/0007-story-owned-scenes-and-elements.md) accepts the first Scene contract, and the
whole of it is implemented. This is the one home for the Scene domain, its four workspace tabs, its
Elements, and the deletion and validation rules that make them safe.

Schema is in [data_model.md](../data_model.md#stories--sections); the page patterns the Scene pages
reuse are in [conventions.md](../conventions.md#views---three-patterns).

## Model and scope

`Scene belongs_to :story`, includes `HasSlug`, and is **flat rather than hierarchical** — no
`parent_id`. A required `name` is labelled **Title**; `description` is optional and a title-only Scene
is valid. `belongs_to :section, optional: true` and `belongs_to :event, optional: true` carry the
organizational group and the in-world fact, and the single optional `datetime` carries the in-world
time point. The event reference and the datetime are **independent**: neither writes, clears, nor
validates against the other, and a disagreement between them is not detected. `has_many_tags
:scene_tag, scope: :story_id` supplies optional Story Tag assignments. `Scene#universe` resolves
through `story.universe`.

`SceneTag belongs_to :story`, includes `Hierarchical`, `HasColor`, `HasSlug`, and the inverse
`has_many_tagd :scene, scope: :story_id`. Definitions use the same positioned controller contract as
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
through a declared owner association (`story`, `scene`, `section`). `SceneElement`, `SceneCharacter`,
`SceneItem`, and `SceneLocation` all reach their Universe through `scene`, so none needs a new entry;
a model nested deeper than one of those defines its own `universe` method delegating through its
owner. Do not re-implement the walk in a view or a controller, and do not add a controller-specific
visibility rule.

Controllers resolve `@story` through `Current.universe.stories.find(...)`, then Scenes through that
Story, and Scene-owned records through that Scene. Never use `Scene.find`, a universe-level Scene
route, or a controller-specific visibility rule. Public read actions still pass through the shared
authorization callback.

## Validation, not exceptions

Same-Story and same-Universe scope is an application rule: a real foreign key cannot prove it. The
`Scene` model adds `section_belongs_to_story`, `event_belongs_to_story_universe`,
`optional_references_exist`, and `datetime_is_a_valid_point`. A malformed `section_id`/`event_id`
therefore renders a `422` field error through the ordinary HTML re-render flow instead of raising a
foreign-key exception, and an unparseable `datetime` is reported instead of being silently cast to
`nil`. The editor re-renders the submitted raw value, so a rejected entry is never cleared from the
field.

The Scene-owned records prove their shared Universe the same way: `SceneElement#speakers_belong_to_the_scene_universe`,
`SceneCharacter#character_belongs_to_the_scene_universe`, `SceneItem#item_belongs_to_the_scene_universe`,
and `SceneLocation#location_belongs_to_the_scene_universe` compare against `scene.story.universe_id`.
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
| Scene Characters tab | `.../scenes/:scene_id/characters` | HTML index, JSON mutations |
| Scene Items tab | `.../scenes/:scene_id/items` | HTML index, JSON mutations |
| Scene Locations tab | `.../scenes/:scene_id/locations` | HTML index, JSON mutations |

Scenes have no Universe-level route. Every Scene and Scene Tag route includes its Story, and all
route-helper keys are passed by name.

`ScenesController` answers HTML only and follows the redirect/re-render flow: a successful
create/update redirects to Scene Details, a move redirects back to the list with a `303`, and grouping
redirects back to the Sections workspace with a `303`. The Scene record flow never uses the shared
modal path, so it inherits nothing from it. The Element and presence-link mutations do: they reuse
`modal_form_controller.js` under
[ADR 0011](../adr/0011-modal-json-mutation-contract.md) instead of a second editor, so their JSON
submission, `422` rendering, pending state, and post-mutation refresh are the same contract already
covered for Characters, Items, and Events.

Documented per-action failures: a malformed `section_id`/`event_id`/`datetime` or foreign Scene Tag
assignment in the editor is a `422` re-render; a foreign or unknown grouping target, scene, Element,
presence link, or Character is a `404`; a missing or unknown `direction`, a create with no
`character_id`, or an update with neither field is a `400`. `SceneElementsController` has **no** read
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
growing without limit. `SceneFilter` (`app/models/scene_filter.rb`) is the value object that owns the
contract: `q` (title and short description), `section_id` (a Section of this Story or the literal
`ungrouped`), `scene_tag_id` (a Scene Tag of this Story), and inclusive in-world `from`/`to`
**days**. Filters combine with `AND`. Rules that must not drift:

- The filter never reorders, regroups, or renumbers.
- A filter value is validated against the already-loaded story-scoped lists, so a foreign or unknown
  id is dropped and reported (`flash.now[:alert]`) instead of reaching the query. The tag filter
  narrows through the scoped inverse association (`SceneTag#tagged_records.select(:id)`), so it
  cannot disclose another Story's scenes.
- A scene without an in-world time is never inside a date range: a null is never inside a range.
- The position badge, the story total, and the Move boundary state come from the whole sequence — one
  aggregate query (`COUNT(*)`, `MIN(position)`, `MAX(position)`) — never from the filtered rows, so a
  narrowed list cannot mistake its first visible row for the first scene of the Story.
- `query_params` is the only source of the filter in a link or a redirect, which is why the index
  redirects a form submission once (`302`) to the canonical query, and why the recognized keys of a
  `move` or `destroy` are carried back to the same list.
- Two empty states are kept apart: a Story without scenes says **No scenes yet** (and only a writer is
  told to add one), while a filter matching nothing says **No scenes match these filters**, repeats the
  active filters, and offers **Clear filters**.
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

**Dialogue speakers** are a plain many-to-many link (`has_and_belongs_to_many :characters, join_table:
:scene_element_speakers`), because it carries no data of its own and records no turn order. Do not give
it a role or a turn index: a later structured-dialogue model owns that concern. A Dialogue must name
at least one same-Universe Character; Narration may name none. `Character` declares the same link from
its side, so deleting a Character removes its speaker links.

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
  `SceneParticipants` reads both and reports their **union** — a Character who both participates and
  speaks is one participant, never two. Never create a presence row for a speaker, and never add the
  two sources together for a count.
- Speaking is **not** a presence link: it never creates a `SceneCharacter` row.
- `SceneAppearances` is the same union in the reverse direction, and adds the `event` reference as a
  third source, so it is also a union and never a sum.

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

Both tabs must wrap `data-controller="modal-form"` in a wrapper element that contains the modal **and**
every control that opens it, because a Stimulus target outside the controller's element is not a
target and the editor would silently never connect.

## Path value objects

`SectionPaths`, `SceneTagPaths`, and `LocationPaths` are value objects, not tables. Each turns one
ordered list into every root-first ancestor path and the depth-indented selector options, so neither
the Scenes list nor the Sections workspace walks ancestors per Scene. Preloading an arbitrary tree
depth with `includes` is not possible and `ancestor_chain` would query per level per Scene, so list
pages build the index once instead.

## "Appears in scenes" traces a record forward

The Character, Item, Location, and Event details pages each end with an **Appears in scenes of
&lt;Story&gt;** section, the reverse of the three tabs. It is deliberately not a new workspace: the same
links would be broken if it were. `SceneAppearances` reports the **union** of a stored presence link, a
derived Dialogue speaker, and an Event reference — one row per Scene, never a sum — ordered by Scene
`position`. A row is labelled with the reason(s) it appears, so **Linked**, **Speaks in N element(s)**,
and **Depicted** are never collapsed into a single word, and a role is only ever shown for a stored
link. The whole section is read-only navigation, so it renders for every access level: the Scenes it
points at are readable by exactly the people who can read the record it is attached to, and every link
carries an explicit `story_id` because a Scene has no Universe-level URL.

The section is scoped to `Current.story`. With no Story selected there is nothing to list, so the
section says so and offers the story list — the same explicit selection the sidebar asks for, never a
fallback to the Universe's first Story.

## The Sections workspace's ungrouped block

The Sections workspace keeps its taxonomy tree and adds an **Ungrouped scenes** list below it: only
the Scenes that belong to no Section, in canonical narrative order, because a grouped Scene is read on
its own Section's page. The badge above that list states how many ungrouped Scenes it holds
(`pluralize(size, "ungrouped scene")`) rather than a bare figure, and the move form offers only the
ungrouped Scenes of that list: the form belongs to the Ungrouped block, so a grouped Scene is
regrouped from its own Section's page through the editor's Section selector instead. The form is not
rendered at all when nothing is ungrouped. Drag-and-drop is not offered, so the move is always
available by keyboard and on touch. Read-only members and guests see the same list with no controls,
and the tree's read-only empty state has its own copy, so a read-only member is not told to add or
drag records.

## The editor and its tabs

Scene Details (`/scenes/:id`) is the canonical, inspectable page: it renders the Title, narrative
position, short description, Section group, Scene Tags, linked Event, formatted in-world time, and
story context for writers, read-only members, and guests, and gives only writers an **Edit scene**
action. The form lives once, at `/scenes/:id/edit` (`scenes/_form`, reused by `new`), so there is no
second edit surface and no second form for the same fields. The editor's workspace tabs go through
`shared/_content_tabs`: **Scene Details**, **Characters**, **Items**, and **Locations** are all live
links, each its own canonical page. A tab is never a link to a route that does not exist and never an
in-document Bootstrap pane.

The Scene form groups its fields: **Scene tags** holds the optional native multi-select with root-first
tag paths, **Organization** holds the Section selector (with **Ungrouped** and depth-indented Section
names), and **In-world time** holds the Event selector (with **None**) and the `datetime-local` field.
Each field has copy stating what it does *not* do.

`Story#menu_scene_count` uses its own cache scope (`Story::SCENE_MENU_COUNT_SCOPE`, referenced by
`Scene` itself) so it never overwrites `menu_section_count`; `Scene` declares
`invalidates_menu_counts_for :story, cache_scope: Story::SCENE_MENU_COUNT_SCOPE`.

## Counts on the list

The Scenes list shows an **Element** count and a **Characters take part** count. Both are read for the
whole page in one grouped query each — never one query per row — and the participant count is the same
union the Characters tab shows. Item and Location counts are deliberately absent: they would need one
extra grouped query each per page, and the three workspace tabs are the place that detail belongs. Do
not render placeholder counts for them.

## The deletion contract

It is asymmetric, and the asymmetry is deliberate:

- Scene-owned Elements, tag assignments, speaker links, and presence links **cascade** with Scene or
  Story deletion. Scene Tag definitions are removed with their Story.
- Deleting a **Section** clears Scene references (`section_id` nullified) and deleting an **Event**
  clears the temporal reference, while preserving Scene narrative order. Neither removes a Scene.
- Deleting a shared Character, Item, or Location removes its Scene links in addition to the existing
  model-dependent behavior, and never removes a Scene.
- Event retains its existing child and temporal-referrer cleanup.

A soft delete follows the shared rules in [data_model.md](../data_model.md#soft-delete): a deleted
Scene is hidden from every ordinary query, its Elements and presence links are soft-deleted with it,
and the positioned controller normalizes the remaining siblings in the same transaction. The exact
confirmation copy is in [ADR 0007](../adr/0007-story-owned-scenes-and-elements.md) and must not be
replaced with only "Delete {record}?" merely to save space.
