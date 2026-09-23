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

### Models
- Models that own a hierarchy include `Hierarchical` (parent/children, cycle & scope validations).
  `Relation` and `Ownership` do **not** (they are link records between two entities);
  `Story`, `Universe`, `User`, `Session` don't either.
- `Hierarchical` compares parents within their owning scope through the overridable
  `hierarchy_scope` / `hierarchy_scope_attribute` / `hierarchy_scope_error` methods
  (universe by default; `Section` overrides them to compare `story_id` →
  *"must belong to the same story"*).
- Content ↔ tag pairs are declared with the `HasManyTags` DSL:
  content model: `has_many_tags :character_tag` (HABTM only), tag model:
  `has_many_tagd :character` (inverse side). Tags are **optional on every content model** —
  `has_many_tags` adds no presence validation and no controller force-assigns a default tag, so
  records are saved untagged when the user picks none (tag them later or never).
- `_tag` models include `HasColor` (validated `#rrggbb` `bgcolor`/`fgcolor`) and `HasSlug`.
- Name presence is validated on: Character, Location, Item, Section, Story and all `_tag` models.
  Not on: Event (see below), Relation, Ownership (name optional), Universe.
- `Relation`, `Ownership` and `Event` add custom validators that keep every associated record
  inside the same universe.

### Controllers
- Universe scoping via `Current.universe` (set from the `:universe_slug` param in
  `ApplicationController#set_current_universe`); sections and section tags add
  `Current.story`/`@story` scoping.
- Positioned/hierarchical controllers include `MaintainsSiblingPositions`
  (`maintains_sibling_positions_for :model`) and override `sibling_collection` when the scope is
  not the universe (Sections and SectionTags use `@story.sections` / `@story.section_tags`).
- Strong params use Rails 8 `params.expect(model: [ ... ])`.
- Response formats:
  - **JSON-only mutations** (`respond_to` → `format.json`, no HTML): every `_tag` controller plus
    Characters, Locations, Items, Events, Sections. The page renders HTML; create/update/destroy
    are called by Stimulus with `as: :json`.
  - **HTML flow** (redirect / re-render): Universes, Stories, Relations, Ownership, Sessions,
    Passwords.
- Actions: `index` + `create/update/destroy` everywhere, `new` for taxonomy editors,
  `show/edit` exist only for Universes and Stories.

### Routes
- Universe content lives under `scope "u/:universe_slug", as: :universe` → helpers are prefixed
  `universe_*` and URLs look like `/u/<universe-slug>/...` (see `config/routes.rb`).
- Stories are a full resource in that scope with sections and section tags nested underneath:
  `resources :stories do resources :sections; resources :section_tags end` →
  `/u/:universe_slug/stories/:story_id/sections`, helpers `universe_story_*`,
  `universe_story_section(s)`, `universe_story_section_tag(s)`.
- **Path helpers must receive their keys explicitly** (`universe_story_path(id: story)`,
  `universe_story_sections_path(story_id: story)`): a positional record is assigned to the first
  path segment (`universe_slug`) and breaks the URL. The `universe_slug` itself is then filled in
  from the current request (recall) — that is why `universe_characters_path()` with no arguments
  works on any page inside a universe.
- Relations/Ownerships are limited to `index, create, update, destroy`; timeline is
  `get "timeline", to: "timeline#index"`; `root` → `universes#index`; health check `/up`.
- `Universe#to_param` returns the slug; content models are addressed by numeric `id`.

### Views - Three Patterns

**1. Taxonomy tree** (all `_tag` indexes, plus `sections` and `locations`):
- Use the `shared/taxonomy_tree` partial (wraps `shared/_taxonomy_node`) with the
  `new_url`/`create_url`/`edit_url`/`update_url`/`delete_url` lambdas + `model_param` +
  `modal_fields` locals.
- `taxonomy_tree_controller.js` provides drag/drop reordering, inline name editing and the
  modal editor (fields come from `data-taxonomy-tree-modal-fields-value`).

**2. Flat list + Bootstrap modal** (characters, items, events, relations, ownerships):
- `list-group` rows with edit/delete buttons + a modal in the same template.
- Driven by `modal_form_controller.js`; multi-selects use `data-controller="tom-select"`.

**3. Plain full-page forms** (universes, stories):
- `new/edit` pages rendering an `_form` partial with `form_with`, error list on top.
- **Stories only** must pass the URL explicitly
  (`form_with model: story, url: story.persisted? ? universe_story_path(id: story) : universe_stories_path`)
  because the routes are not nested under `resources :universes`.

- Section/story pages pass URLs scoped by story — see `app/views/sections/index.html.erb`
  (the same applies to `app/views/section_tags/index.html.erb`).

### Helpers
- `app/helpers/modal_fields.rb` — field descriptors consumed by the JS controllers:
  - `*_tag_taxonomy_fields(nodes)` — editors for a tag model (name/description/colors/parent),
    e.g. `event_tag_taxonomy_fields`, `section_tag_taxonomy_fields`.
  - `*_taxonomy_fields(tags)` — content editors with tag selectors, e.g.
    `location_taxonomy_fields`, `section_taxonomy_fields`.
  - `*_fields_json(record)` — serializes a record for modal pre-filling:
    `event_fields_json`, `character_fields_json`, `item_fields_json`,
    `ownership_fields_json`, `relation_fields_json`.
- `app/helpers/application_helper.rb` — `active_if`, `visible?`, `icon`, `icon_text_count`,
  `nav_universes`, `nav_stories` (top bar dropdowns), `entity_tag_badge` (renders a record's tags
  as colored badges).
- `app/helpers/timeline_helper.rb` — popover title/content for timeline events.

### JavaScript Controllers (`app/javascript/controllers/`)
- `taxonomy_tree_controller.js` — hierarchy editing: drag/drop, inline rename, modal, JSON CRUD.
- `modal_form_controller.js` — Bootstrap modal CRUD for the flat list views.
- `timeline_controller.js` — pan/zoom + popovers for the Timeline view.
- `tom_select_controller.js` — enhanced multi-selects (tom-select) for tag pickers.
- `hello_controller.js` — Rails scaffold leftover.

### Navigation (Top bar) — `app/views/layouts/_navbar.html.erb`
Left to right:
- **Dashboard** — placeholder (`#`).
- **Universes** — dropdown: `nav_universes` list (current universe highlighted), *All
  universes*, *New universe*.
- **[current universe]** — only when `Current.universe` is present: a dropdown named after the
  universe listing `nav_stories` (current story highlighted as `active`), plus *All stories* and
  *New story*. This is where the stories menu now lives (it used to be the sidebar's WHAT card).
  The toggle also gets `active_if(:stories)` so it lights up on story pages.
- **[current story]** — only when `Current.story` is present: a link to that story's page
  (`universe_story_path(id: …)`).

### Navigation (Sidebar) — `app/views/layouts/_left_sidebar.html.erb`
Both sidebars render only when `Current.universe` is present (with no universe selected the main
column takes the full width), grouped by question cards:
- **WHAT** *(story-scoped — hidden until a story is selected)*: Plot (placeholder `#`),
  World Building (placeholder), Tropes (placeholder). The Stories entry moved to the top bar.
- **HOW** *(story-scoped — hidden until a story is selected)*: Scenes (placeholder), Sections +
  Section Tags — the Sections link targets `Current.story` (remembered per universe in the
  session; there is **no** fallback to the first story).
- **WHO**: Characters, Relations, Meetings (placeholder), Dialogs (placeholder).
- **WHERE**: Locations, Routes (placeholder), Map (placeholder), Distances (placeholder),
  Connections (placeholder).
- **WHEN**: Events, Timeline.
- **WITH**: Items, Ownerships.
Each real entry shows `icon_text_count` with a count and a tag-icon shortcut (`active_if`).

## Event Model (implemented)

Correction of an older (wrong) note: **Event does have a `_tag` taxonomy** — `EventTag` +
`events_event_tags` HABTM + `EventTagsController` + sidebar tag shortcut, exactly like the other
content models. What actually makes Event special:

1. `Event` includes `Hierarchical` (parent/position) **plus** the self-referencing
   `before_event`, `after_event`, `simultaneous_event` associations (cycle-safe: `display_string`
   walks with a visited list and `cannot_reference_self` guards the ids).
2. Tags are **optional** — as on every content model (`has_many_tags` adds no presence
   validation). Event was simply the first model to work this way; the old
   `required: false` opt-in is gone.
3. Identity is title-driven: users enter `title`; `set_name` copies `title → name` **on create
   only**; `Event#display_string` renders the label, falling back to dates, then relations
   (`"before Event #3"`), and finally `"Event #id"`.
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
