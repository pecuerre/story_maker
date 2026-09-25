# Universe Maker Rails App - Conventions Summary

> Companion docs: [data_model.md](data_model.md) (schema, tables, validations),
> [architecture.md](architecture.md) (request lifecycle, routing/URL rules, UI patterns, timeline),
> [development.md](development.md) (commands, tests, seeding, CI, deployment),
> [known_quirks.md](known_quirks.md) (verified oddities — read before touching shared code).
> Full index: [README.md](README.md).

## Core Patterns

### Database Schema
- Content records are scoped to a **universe**; the one exception is `Section`, which is scoped
  to a **Story** (`Section belongs_to :story`, `Story belongs_to :universe`). A universe holds many
  stories (e.g. universe *A Song of Ice and Fire* → stories *Game of Thrones*, *House of the Dragon*),
  which share the universe's characters/locations/events/items but each own their sections (the script/plot).
- Every content model and every `_tag` taxonomy model has its own `slug` (see `HasSlug`).
- Typical content columns: `name`, `description`, `universe_id` (FK), `parent_id` (self FK),
  `position` (default 0), `slug`, timestamps. Exceptions (Relation, Ownership, Event, Story) are
  listed in [data_model.md](data_model.md).
- `"_tag"` models are their own hierarchical tables (`parent_id` self-FK); there is no `tag_id`
  column on the content tables — the pairs are joined with HABTM join tables.
- `position` defaults to 0 and enables ordered lists; siblings are normalized to 0..n-1.

### Development data

- `Development::UniverseDataRegistry` is the shared model-order/file/universe registry.
- Every registered universe directory contains every registered model YAML file; use `[]` for an
  intentionally unused model. A new model updates the registry and all relevant universe files.
- Development data uses `Model.slug` references only in association fields. The loader validates
  the exact file set, identifiers, forward references, attributes, and universe/story scope before
  writing; it normalizes hierarchical sibling positions from file order, or requires complete
  unique explicit positions for a sibling group.
- Use `UNIVERSE=<slug> bin/rails db:demo:check` for read-only validation and the explicit
  development-only load/reset tasks for browser data. `db:seed` and `db:prepare` never load
  `db/data/`.

### Models
- Models that own a hierarchy include `Hierarchical` (parent/children, cycle & scope validations).
  `Relation` and `Ownership` do **not** (they are link records between two entities);
  `Story`, `Universe`, `User`, `Session` don't either.
- `Hierarchical` compares parents within their owning scope through the overridable
  `hierarchy_scope` / `hierarchy_scope_attribute` / `hierarchy_scope_error` methods
  (universe by default; `Section` overrides them to compare `story_id` →
  *"must belong to the same story"*).
- Content ↔ tag pairs are declared with the `HasManyTags` DSL:
  content model: `has_many_tags :character_tag, scope: :universe_id`, tag model:
  `has_many_tagd :character, scope: :universe_id` (inverse side). Section/SectionTag use
  `scope: :story_id`. The scope is mandatory and is applied to reads/builds on both sides; a shared
  validation also rejects foreign members assigned in memory or through an ID writer. Tags are
  **optional on every content model** — the DSL adds no presence validation and no controller
  force-assigns a default tag, so records are saved untagged when the user picks none.
- `_tag` models include `HasColor` (validated `#rrggbb` `bgcolor`/`fgcolor`) and `HasSlug`.
- Name presence is validated on: Universe, Character, Location, Item, Section, Story and all
  `_tag` models. Not on: Event (see below), Relation and Ownership (name optional).
- `Relation`, `Ownership` and `Event` add custom validators that keep their non-tag associated
  records inside the same universe. `HasManyTags` independently enforces the shared universe or
  story scope in both directions for all seven content/tag pairs.

### Controllers
- Universe scoping via `Current.universe` (set from the `:universe_slug` param in
  `ApplicationController#set_current_universe`); sections and section tags add
  `Current.story`/`@story` scoping.
- `ApplicationController#authorize_universe_access` runs after universe resolution and before story
  selection. Universe-scoped controllers explicitly allow only public read actions at the
  authentication layer, then `Ability` enforces read/write/admin access. Do not add a
  controller-specific visibility check that bypasses this callback.
- Positioned/hierarchical controllers include `MaintainsSiblingPositions`
  (`maintains_sibling_positions_for :model`) and override `sibling_collection` when the scope is
  not the universe (Sections and SectionTags use `@story.sections` / `@story.section_tags`).
- Strong params use Rails 8 `params.expect(model: [ ... ])`.
- Universe authorization is a three-level policy: `read`, `write`, and `admin`. Public universes
  grant guest read and signed-in write access; private universes require an owner or membership.
  A private-universe non-member, including a guest, receives 404 so slug enumeration cannot
  distinguish it from an unknown universe. The owner is always admin, and a membership's level
  applies uniformly to all universe/story components. Admin membership management is an HTML flow
  at `/u/:universe_slug/members`.
- Response formats:
  - **JSON-only mutations** (`respond_to` → `format.json`, no HTML): every `_tag` controller plus
    Characters, Locations, Items, Events, Sections. The page renders HTML; create/update/destroy
    are called by Stimulus with `as: :json`.
  - **HTML flow** (redirect / re-render): Universes, Stories, Relations, Ownerships, Universe
    memberships, Sessions, Passwords.
- Actions: `index` + `create/update/destroy` everywhere, `new` for taxonomy editors and
  memberships. In the current implementation, `show/edit` exist only for Universes and Stories;
  the accepted Scene contract in slice 11.0 adds the documented Scene list/editor actions in later
  delivery slices.

### Routes
- Universe content lives under `scope "u/:universe_slug", as: :universe` → helpers are prefixed
  `universe_*` and URLs look like `/u/<universe-slug>/...` (see `config/routes.rb`).
- Stories are a full resource in that scope with sections and section tags nested underneath:
  `resources :stories, path: "s" do resources :sections; resources :section_tags end` →
  `/u/:universe_slug/s/:story_id/sections`, helpers `universe_story_*`,
  `universe_story_section(s)`, `universe_story_section_tag(s)`.
- **Path helpers must receive their keys explicitly** (`universe_story_path(id: story)`,
  `universe_story_sections_path(story_id: story)`): a positional record is assigned to the first
  path segment (`universe_slug`) and breaks the URL. The `universe_slug` itself is then filled in
  from the current request (recall) — that is why `universe_characters_path()` with no arguments
  works on any page inside a universe. A test scans Ruby and ERB call sites and rejects positional
  arguments to `universe_*_path`/`universe_*_url` helpers.
- All section and section-tag URLs include the story id (`/u/:universe_slug/s/:story_id/...`).
  The universe-level `/u/:universe_slug/sections` path is intentionally invalid.
- Relations/Ownerships are limited to `index, create, update, destroy`; memberships are mounted at
  `/u/:universe_slug/members` with `index`, `new`, `create`, `update`, and `destroy`, and are
  admin-only. The taxonomy workspace is `GET /u/:universe_slug/tags`, with `scope=universe|story`
  and `taxonomy=character|relation|location|event|item|ownership|section` query parameters;
  timeline is `get "timeline", to: "timeline#index"`; `root` → `universes#index`; health check `/up`.
- `Universe#to_param` returns the slug; content models are addressed by numeric `id`.

### Views - Three Patterns

Every work page starts with `shared/_page_header` (eyebrow, sentence-case title, optional count and
description, right-aligned actions) and uses `shared/_empty_state` instead of bare “No records yet”
text. Mutation controls are rendered only when `can_write_universe?`; universe settings and member
controls use `can_administer_universe?`. The shared row/taxonomy partials enforce this so read-only
members and public guests see the same content without misleading edit affordances. Flat entity
rows use `shared/_row_actions`: neutral overflow menus for edit/delete, with
destructive actions marked by text/icon rather than a permanently red button. Flash messages are
rendered once by the application layout through `shared/_flash`.

The three functional editing patterns are:

**1. Taxonomy tree** (all `_tag` indexes, plus `sections` and `locations`):
- Use the `shared/taxonomy_tree` partial (wraps `shared/_taxonomy_node`) with the
  `new_url`/`create_url`/`edit_url`/`update_url`/`delete_url` lambdas + `model_param` +
  `modal_fields` locals.
- `taxonomy_tree_controller.js` provides drag/drop reordering, inline name editing and the
  modal editor (fields come from `data-taxonomy-tree-modal-fields-value`).

**2. Flat list + Bootstrap modal** (characters, items, events, relations, ownerships):
- `content-surface` + `list-group` rows with shared overflow actions + a modal in the same template.
- Every record workspace uses `shared/_content_tabs`: URL-backed Bootstrap `nav-tabs` that keep
  related records together while preserving each canonical page. Tag management uses
  `shared/_tag_workspace_navigation` under Configuration → Tags; it provides the Universe/Story
  scope tabs and the scope-specific taxonomy selector.
- Driven by `modal_form_controller.js`; multi-selects use `data-controller="tom-select"`.

**3. Plain full-page forms** (universes, stories):
- `new/edit` pages rendering an `_form` partial with `form_with`, error list on top.
- **Stories only** must pass the URL explicitly
  (`form_with model: story, url: story.persisted? ? universe_story_path(id: story) : universe_stories_path`)
  because the routes are not nested under `resources :universes`.

- Section/story pages pass URLs scoped by story — see `app/views/sections/index.html.erb`
  (the same applies to `app/views/section_tags/index.html.erb`).

### Planned Scene conventions (slice 11.0; not implemented)

[ADR 0007](adr/0007-story-owned-scenes-and-elements.md) accepts the first Scene contract. Keep the
current disabled **Scenes** sidebar placeholder until slice 11.1 provides a real, selected-Story
route.

- **Model:** `Scene belongs_to :story`, includes `HasSlug`, and is flat rather than hierarchical. A
  required `name` is labelled **Title**; description, same-Story Section, same-Universe Event, one
  optional single-point `datetime` using Event-compatible storage/editor precision and timezone
  semantics, Tags, and world-record links are optional. Do not use the current hierarchical
  `MaintainsSiblingPositions` implementation unchanged: slice 11.1 must generalize/refactor it or
  add a compatible flat-ordering concern that preserves its sibling-position conventions and tests.
  Do not add `Hierarchical` to Scene or SceneElement; their contiguous `position` sequences need
  dedicated transactional flat-ordering behavior.
- **Elements:** `SceneElement belongs_to :scene`; it is an ordered child component rather than a
  standalone navigable content model and has no public slug requirement. Its `kind` is `narration`
  or `dialogue`, `name` is required and labelled **Title**, `body` is optional, and `position` is
  flat. Narration rejects speakers; Dialogue requires at least one same-Universe Character speaker.
- **Tags:** `SceneTag` and `Scene` use the existing `has_many_tags` / `has_many_tagd` DSL with
  mandatory `scope: :story_id`; tags are optional and have no default. Scene Tag definitions belong
  under Configuration → Tags → Story Tags, while assignment belongs on Scene Details.
- **World links:** use real join models for `SceneCharacter`, `SceneItem`, and `SceneLocation` so
  their nullable free-text `role` is persisted. Use a unique join model for
  `SceneElementSpeaker`. Validate same-Universe scope in application code and resolve it through
  Scene in both `Ability` and shared helpers.
- **Controller scope:** resolve `@story` through `Current.universe.stories.find(...)`, then resolve
  Scenes and related records through that Story. Never use `Scene.find`, a universe-level Scene
  route, or a controller-specific visibility rule. Public read actions still pass through the
  shared authorization callback.
- **Routes:** nest Scenes under Stories and related records under Scenes. Canonical paths are
  `/u/:universe_slug/s/:story_id/scenes`, `/u/:universe_slug/s/:story_id/scenes/:scene_id`,
  `/characters`, `/items`, `/locations`, and `/elements` beneath the Scene path. Pass `story_id`,
  `scene_id`, and any record id as named route-helper keys; never use positional records.
- **Responses:** Scene index/show/new/create/edit/update/destroy and narrative moves use HTML
  redirect/re-render. Element and role-bearing presence-link create/update/destroy use JSON-only
  Stimulus modals with `422` error hashes. Do not add an action that ambiguously accepts both.
- **Ordering:** the global Scene list is ordered by `(position, id)` and is not grouped by Section.
  Section assignment changes only `section_id`. Visible Move up/Move down controls and keyboard
  behavior are required; drag-and-drop is optional. Element ordering is independent within Scene.
- **UI:** use the existing flat-list and full-page form patterns for the Scene list/editor, and the
  existing modal pattern for Elements and role-bearing links. Do not create a fourth page pattern.
  URL-backed Details/Characters/Items/Locations tabs preserve canonical URLs and `aria-current`.
- **Helpers:** add only the Scene-specific field/JSON descriptors needed by the new forms. Scene
  JSON must not be used to mix the stable HTML Details form with mutation responsibilities. Update
  shared count/preload behavior without copying the current taxonomy stale-option or modal 406
  weaknesses.

### Helpers
- `app/helpers/modal_fields.rb` — field descriptors consumed by the JS controllers:
  - `*_tag_taxonomy_fields(nodes)` — editors for a tag model (name/description/colors/parent),
    e.g. `event_tag_taxonomy_fields`, `section_tag_taxonomy_fields`.
  - `*_taxonomy_fields(tags)` — content editors with tag selectors, e.g.
    `location_taxonomy_fields`, `section_taxonomy_fields`.
  - `*_fields_json(record)` — serializes a record for modal pre-filling:
    `event_fields_json`, `character_fields_json`, `item_fields_json`,
    `ownership_fields_json`, `relation_fields_json`.
- `app/helpers/application_helper.rb` — `active_if`, `aria_current_for`, `visible?`, `icon`,
  `icon_text_count`, `nav_universes`, `nav_stories` (top bar dropdowns), universe access helpers
  (`can_read_universe?`, `can_write_universe?`, `can_administer_universe?`,
  `universe_access_level`, `universe_access_label`), and `entity_tag_badge` (renders a record's tags
  as colored badges). Counts are right-aligned pills, not parenthesized text; current links carry
  both `.active` and `aria-current="page"`.
- `app/views/shared/_content_tabs.html.erb` renders related universe pages as URL-backed
  Bootstrap navigation; it does not use `data-bs-toggle="tab"` because each tab is a separate
  request and canonical URL. It accepts an optional `class_name` and explicit `active` tab state
  for nested selectors.
- `app/views/shared/_tag_workspace_navigation.html.erb` and `app/helpers/tags_helper.rb` build the
  Configuration → Tags scope/taxonomy navigation and the model-specific tree configuration.
- `app/helpers/timeline_helper.rb` — popover title/content for timeline events.

### JavaScript Controllers (`app/javascript/controllers/`)
- `taxonomy_tree_controller.js` — hierarchy editing: drag/drop, inline rename, modal, JSON CRUD.
- `modal_form_controller.js` — Bootstrap modal CRUD for the flat list views.
- `timeline_controller.js` — pan/zoom + popovers for the Timeline view.
- `tom_select_controller.js` — enhanced multi-selects (tom-select) for tag pickers.

### Navigation (Top bar) — `app/views/layouts/_navbar.html.erb`
Left to right:
- **Universes** — dropdown: `nav_universes` list (current universe highlighted), *All universes*,
  and *New universe* for signed-in users. The current-universe menu also exposes *Members* to admins.
- **Universe: [name]** — present when `Current.universe` exists; makes the current universe scope
  explicit and links back to the universe overview/all universes.
- **Story: [name or Select]** — present when `Current.universe` exists; lists `nav_stories`, *All
  stories*, and *New story*. A selected story is highlighted, but there is no duplicate standalone
  current-story link.
- **Account** — signed-in email and logout action, or **Log in** for guests.

Nonfunctional dashboard links do not appear in the navbar. The right utility sidebar is the
intentional home for future richer collaboration, analytics, and AI placeholders; those entries are
`aria-disabled` and should be replaced with real destinations as the product areas are defined.

### Navigation (Sidebar) — `app/views/layouts/_left_sidebar.html.erb`
The workspace sidebar renders only when `Current.universe` is present. It is one continuous
navigation surface (not a stack of cards) and becomes a left Bootstrap offcanvas below `lg`:
- **Story workspace**: Story overview + Sections when a story is selected; otherwise All stories
  plus a prompt to select one. **Scenes** is a reserved placeholder link. New story is available
  from the navbar's Story dropdown, not from the sidebar.
- **Universe Bible**: direct links to Characters, Locations, Events, Timeline, and Items. Characters
  and Items open their related record tabs (Relations and Ownerships respectively); Locations,
  Events, and Sections remain single-record workspaces.
- **Configuration**: a separate organization/settings section. **Tags** opens the shared taxonomy
  workspace, with **Universe Tags** selected by default and **Story Tags** for story-scoped
  taxonomies. Universe admins see **Members** in the right-side **Settings** section.
- Real entries show `icon_text_count`; counts are aligned pills. Active entries use a soft primary
  background and `aria-current="page"`. The reserved Scenes and right-sidebar entries are the
  intentional `#` placeholders for future functionality.

### Navigation (Right sidebar) — `app/views/layouts/_right_sidebar.html.erb`
The right utility sidebar renders only when `Current.universe` is present. It is a permanent
14rem column at `xl` and above, and a Bootstrap `offcanvas-end` below `xl`. Its **Settings** section
contains the universe **Members** access manager for admins. It also keeps the future
**Collaboration**, **Analytics**, and **AI** placeholder groups; no model or route exists for those
entries yet. On smaller screens, the **Tools** button opens the panel from the mobile workspace
bar.

## Event Model (implemented)

Correction of an older (wrong) note: **Event does have a `_tag` taxonomy** — `EventTag` +
`events_event_tags` HABTM + `EventTagsController` + labeled Event tags navigation, like the other
content models. What actually makes Event special:

1. `Event` includes `Hierarchical` (parent/position) **plus** the self-referencing
   `before_event`, `after_event`, `simultaneous_event` associations. `display_string` walks with a
   visited list, and `cannot_reference_self` checks both object identity and the foreign-key id.
   Database check constraints close the insert-time gap where an ID is assigned only during save.
   Destroying an event nullifies every incoming temporal reference; a referrer that existed only to
   point at that event is removed first so `must_be_identifiable` remains true for retained rows.
2. Tags are **optional** — as on every content model (`has_many_tags` adds no presence
   validation). Event was simply the first model to work this way; the old
   `required: false` opt-in is gone.
3. Identity is title-driven: users enter `title`; `set_name` copies `title` to `name` on create
   and whenever the title changes. It is prepended before `HasSlug`, so the event slug follows the
   title on create and rename. `Event#display_string` renders the label, falling back to dates, then
   relations (`"before Event #3"`), and finally `"Event #id"`.
4. `must_be_identifiable`: an event needs a title, a start/end datetime, or a relation to
   another event; related events must belong to the same universe.
5. UI: flat list + modal (pattern 2), `modal_fields.rb` provides `event_fields_json`; the modal
   also offers before/after/simultaneous selects and a tom-select tag picker.
6. Mutations are JSON-only; `EventsController` includes `MaintainsSiblingPositions`.
7. Route: `resources :events` inside the universe scope.
8. Feeds the Timeline (see [architecture.md](architecture.md#timeline) for the algorithm).

## Timeline (implemented)

`TimelineController` (`get "timeline"`) hands the universe's events to `TimelineLayout`
(app/models/timeline_layout.rb), which layers them for the Timeline view; rendering is done by
`timeline/index` + `timeline_controller.js` with popovers from `TimelineHelper`.
