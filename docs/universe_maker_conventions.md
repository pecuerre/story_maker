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
- Name presence is validated on: Universe, Character, Location, Item, Section, Story and all
  `_tag` models. Not on: Event (see below), Relation and Ownership (name optional).
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
- Relations/Ownerships are limited to `index, create, update, destroy`; timeline is
  `get "timeline", to: "timeline#index"`; `root` → `universes#index`; health check `/up`.
- `Universe#to_param` returns the slug; content models are addressed by numeric `id`.

### Views - Three Patterns

Every work page starts with `shared/_page_header` (eyebrow, sentence-case title, optional count and
description, right-aligned actions) and uses `shared/_empty_state` instead of bare “No records yet”
text. Flat entity rows use `shared/_row_actions`: neutral overflow menus for edit/delete, with
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
- Every record and taxonomy workspace uses `shared/_content_tabs`: URL-backed Bootstrap `nav-tabs`
  that keep related records and their corresponding tag managers together while preserving each
  canonical page.
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
- `app/helpers/application_helper.rb` — `active_if`, `aria_current_for`, `visible?`, `icon`,
  `icon_text_count`, `nav_universes`, `nav_stories` (top bar dropdowns), `entity_tag_badge`
  (renders a record's tags as colored badges). Counts are right-aligned pills, not parenthesized
  text; current links carry both `.active` and `aria-current="page"`.
- `app/views/shared/_content_tabs.html.erb` renders related universe pages as URL-backed
  Bootstrap navigation; it does not use `data-bs-toggle="tab"` because each tab is a separate
  request and canonical URL.
- `app/helpers/timeline_helper.rb` — popover title/content for timeline events.

### JavaScript Controllers (`app/javascript/controllers/`)
- `taxonomy_tree_controller.js` — hierarchy editing: drag/drop, inline rename, modal, JSON CRUD.
- `modal_form_controller.js` — Bootstrap modal CRUD for the flat list views.
- `timeline_controller.js` — pan/zoom + popovers for the Timeline view.
- `tom_select_controller.js` — enhanced multi-selects (tom-select) for tag pickers.

### Navigation (Top bar) — `app/views/layouts/_navbar.html.erb`
Left to right:
- **Universes** — dropdown: `nav_universes` list (current universe highlighted), *All universes*,
  *New universe*.
- **Universe: [name]** — present when `Current.universe` exists; makes the current universe scope
  explicit and links back to the universe overview/all universes.
- **Story: [name or Select]** — present when `Current.universe` exists; lists `nav_stories`, *All
  stories*, and *New story*. A selected story is highlighted, but there is no duplicate standalone
  current-story link.
- **Account** — signed-in email and logout action, or **Log in** for guests.

Nonfunctional dashboard links do not appear in the navbar. The right utility sidebar is the
intentional home for temporary collaboration, analytics, and AI placeholders; those entries are
`aria-disabled` and should be replaced with real destinations as the product areas are defined.

### Navigation (Sidebar) — `app/views/layouts/_left_sidebar.html.erb`
The workspace sidebar renders only when `Current.universe` is present. It is one continuous
navigation surface (not a stack of cards) and becomes a left Bootstrap offcanvas below `lg`:
- **Story workspace**: Story overview + Sections when a story is selected; otherwise All stories
  plus a prompt to select one. **Scenes** is a reserved placeholder link. New story is available
  from the navbar's Story dropdown, not from the sidebar.
- **Universe Bible**: direct links to Characters, Locations, Events, Timeline, and Items. Relations,
  Ownerships, and every tag taxonomy are reached from their corresponding workspace tabs.
- **Configuration**: a separate, currently empty organization/settings section reserved for
  future configuration tools.
- Real entries show `icon_text_count`; counts are aligned pills. Active entries use a soft primary
  background and `aria-current="page"`. The reserved Scenes and right-sidebar entries are the
  intentional `#` placeholders for future functionality.

### Navigation (Right sidebar) — `app/views/layouts/_right_sidebar.html.erb`
The right utility sidebar renders only when `Current.universe` is present. It is a permanent
14rem column at `xl` and above, and a Bootstrap `offcanvas-end` below `xl`. It currently groups
future **Collaboration**, **Analytics**, and **AI** links; no model or route exists for these
entries yet. On smaller screens, the **Tools** button opens the panel from the mobile workspace
bar.

## Event Model (implemented)

Correction of an older (wrong) note: **Event does have a `_tag` taxonomy** — `EventTag` +
`events_event_tags` HABTM + `EventTagsController` + labeled Event tags navigation, like the other
content models. What actually makes Event special:

1. `Event` includes `Hierarchical` (parent/position) **plus** the self-referencing
   `before_event`, `after_event`, `simultaneous_event` associations (cycle-safe: `display_string`
   walks with a visited list and `cannot_reference_self` guards the ids).
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
