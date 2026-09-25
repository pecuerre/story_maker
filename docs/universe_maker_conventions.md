# Universe Maker Rails App - Conventions Summary

> Companion docs: [data_model.md](data_model.md) (schema, tables, validations),
> [architecture.md](architecture.md) (request lifecycle, routing/URL rules, UI patterns, timeline),
> [development.md](development.md) (commands, tests, seeding, CI, deployment),
> [known_quirks.md](known_quirks.md) (verified oddities — read before touching shared code).
> Full index: [README.md](README.md).

## Core Patterns

### Database Schema
- Content records are scoped to a **universe**; the story-scoped exceptions are `Section`, `Scene`,
  `SectionTag`, and `SceneTag` (`Section belongs_to :story`, `Scene belongs_to :story`,
  `SectionTag belongs_to :story`, `SceneTag belongs_to :story`, and `Story belongs_to :universe`). A
  universe holds many
  stories (e.g. universe *A Song of Ice and Fire* → stories *Game of Thrones*, *House of the Dragon*),
  which share the universe's characters/locations/events/items but each own their sections (the script/plot)
  and their ordered scenes.
- Every content model and every `_tag` taxonomy model has its own `slug` (see `HasSlug`).
- Typical content columns: `name`, `description`, `universe_id` (FK), `parent_id` (self FK),
  `position` (default 0), `slug`, timestamps. Exceptions (Relation, Ownership, Event, Story) are
  listed in [data_model.md](data_model.md).
- `"_tag"` models are their own hierarchical tables (`parent_id` self-FK); there is no `tag_id`
  column on the content tables — the pairs are joined with HABTM join tables.
- `position` defaults to 0 and enables ordered lists; positioned controller mutations delegate to
  `PositionedResourceOrder`, which transactionally maintains contiguous positions for hierarchical
  and explicitly configured flat collections.

### Development data

- `Development::UniverseDataRegistry` is the shared model-order/file/universe registry.
- Every registered universe directory contains every registered model YAML file; use `[]` for an
  intentionally unused model. A new model updates the registry and all relevant universe files.
- Development data uses `Model.slug` references only in association fields. The loader validates
  the exact file set, identifiers, forward references, attributes, and universe/story scope before
  writing; it normalizes hierarchical sibling positions from file order, or requires complete
  unique explicit positions for a sibling group.
- Use `UNIVERSE=<slug> bin/rails db:demo:check` for read-only validation and the explicit
  development-only load/reset tasks for browser data. After any `db/data/**/*.yml` add/delete/update,
  rebuild the local development database rather than expecting a file watch or create-only load to
  synchronize it. UI-only changes are intentionally discarded. `db:seed` and `db:prepare` never
  load `db/data/`.

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
  `has_many_tagd :character, scope: :universe_id` (inverse side). Section/SectionTag and
  Scene/SceneTag use `scope: :story_id`. The scope is mandatory and is applied to reads/builds on
  both sides; a shared validation also rejects foreign members assigned in memory or through an ID
  writer. Tags are **optional on every content model** — the DSL adds no presence validation and no
  controller force-assigns a default tag, so records are saved untagged when the user picks none.
  `has_many_tagd` also records the inverse association name
  (`Model.tagged_records_association`, e.g. `:characters`), and `tagged_records` is the read side
  used by a tag's details page: the scoped association ordered by name, or `none` on a content
  model. Because both scopes are instance-dependent lambdas, Rails cannot eager load or group
  through these associations; use `TaggedRecordCounts` for a whole taxonomy at once.
- `_tag` models include `HasColor` (validated `#rrggbb` `bgcolor`/`fgcolor`) and `HasSlug`.
  `SectionTag` and `SceneTag` additionally use the story-scoped `Hierarchical` scope.
- Name presence is validated on: Universe, Character, Location, Item, Section, Story and all
  `_tag` models. Not on: Event (see below), Relation and Ownership (name optional).
- `Relation`, `Ownership` and `Event` add custom validators that keep their non-tag associated
  records inside the same universe. `HasManyTags` independently enforces the shared universe or
  story scope in both directions for all seven content/tag pairs.

### Controllers
- Universe scoping via `Current.universe` (set from the `:universe_slug` param in
  `ApplicationController#set_current_universe`); sections, section tags, and scenes add
  `Current.story`/`@story` scoping.
- `ApplicationController#authorize_universe_access` runs after universe resolution and before story
  selection. Universe-scoped controllers explicitly allow only public read actions at the
  authentication layer, then `Ability` enforces read/write/admin access. Do not add a
  controller-specific visibility check that bypasses this callback.
- Positioned/hierarchical controllers include `MaintainsSiblingPositions`
  (`maintains_sibling_positions_for :model`) and override `sibling_collection` and
  `sibling_position_scope_owner` when the scope is not the universe (Sections, SectionTags, and
  Scenes use `@story` as owner). Use `maintains_flat_positions_for` for a parentless sequence; the
  concern then omits the ordering parent entirely, so a flat resource does not need a `parent_id`
  column. Do not infer flat ordering from `section_id` or another organizational association.
- Strong params use Rails 8 `params.expect(model: [ ... ])`.
- Universe authorization is a three-level policy: `read`, `write`, and `admin`. Public universes
  grant guest read and signed-in write access; private universes require an owner or membership.
  A private-universe non-member, including a guest, receives 404 so slug enumeration cannot
  distinguish it from an unknown universe. The owner is always admin, and a membership's level
  applies uniformly to all universe/story components. Admin membership management is an HTML flow
  at `/u/:universe_slug/members`.
- Password-reset responses set `Cache-Control: no-store` and `Referrer-Policy: no-referrer`.
  `PasswordResetPathFilter` redacts reset-token path segments from Rails request logs; upstream
  proxy/access-log retention remains an external deployment responsibility.
- Response formats:
  - **JSON-only mutations** (`respond_to` → `format.json`, no HTML): every `_tag` controller plus
    Characters, Locations, Items, Events, Sections, including `SceneTagsController`. The page
    renders HTML; create/update/destroy are called by Stimulus with `as: :json`. `SceneTagsController`
    checks the request format before entering the positioned service so a rejected HTML mutation
    cannot commit first.
  - **HTML flow** (redirect / re-render): Universes, Stories, Scenes, Relations, Ownerships, Universe
    memberships, Sessions, Passwords.
- Actions: `index` + `create/update/destroy` everywhere, `new` for taxonomy editors and
  memberships. `show/edit` exist for Universes, Stories, and Scenes; `show` also exists for every
  content model (Character, Location, Item, Event, Relation, Ownership, Section) and every tag
  model, because each record has exactly one details page. `ScenesController#move` (narrative
  order) and `#group` (Section grouping) are the two member and collection actions beyond that set,
  and the accepted Scene contract adds the remaining documented Scene actions in later delivery
  slices.
- A `show` action is **read-only and guest-readable** (`allow_unauthenticated_access only: %i[index
  show]`), loads its record through the authorized scope, and renders no mutation control. Because
  a details page has no form, `can_write_universe?` only decides whether an editor link is
  rendered, and read-only members and guests see identical content.

### Routes
- Universe content lives under `scope "u/:universe_slug", as: :universe` → helpers are prefixed
  `universe_*` and URLs look like `/u/<universe-slug>/...` (see `config/routes.rb`).
- Stories are a full resource in that scope with sections, section tags, Scene Tags, and scenes nested
  underneath:
  `resources :stories, path: "s" do resources :sections; resources :section_tags; resources :scene_tags; resources :scenes end`
  → `/u/:universe_slug/s/:story_id/sections`, helpers `universe_story_*`,
  `universe_story_section(s)`, `universe_story_section_tag(s)`, `universe_story_scene_tag(s)`,
  `universe_story_scene(s)`, `move_universe_story_scene_path` for the narrative-order move, and
  `group_universe_story_scenes_path` for the Section grouping form.
- **Path helpers must receive their keys explicitly** (`universe_story_path(id: story)`,
  `universe_story_sections_path(story_id: story)`): a positional record is assigned to the first
  path segment (`universe_slug`) and breaks the URL. The `universe_slug` itself is then filled in
  from the current request (recall) — that is why `universe_characters_path()` with no arguments
  works on any page inside a universe. A test scans Ruby and ERB call sites and rejects positional
  arguments to `universe_*_path`/`universe_*_url` helpers.
- All section, section-tag, Scene Tag, and scene URLs include the story id
  (`/u/:universe_slug/s/:story_id/...`). The universe-level `/u/:universe_slug/sections`,
  `/u/:universe_slug/section_tags`, `/u/:universe_slug/scene_tags`, and
  `/u/:universe_slug/scenes` paths are intentionally invalid.
- Relations/Ownerships are limited to `index, show, create, update, destroy`; memberships are
  mounted at `/u/:universe_slug/members` with `index`, `new`, `create`, `update`, and `destroy`, and
  are admin-only. The taxonomy workspace is `GET /u/:universe_slug/tags`, with `scope=universe|story`
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
  `modal_fields` locals, plus `details_url`/`details_count`/`details_count_label` for the row's
  **Details** link.
- A row carries three things: the **name** (the only inline-rename target, sized to its own text so
  clicking the empty space beside it does nothing), the **Details** link (visible at every access
  level), and one **overflow menu** holding Add child, Insert before, Insert after, Move up, Move
  down, Edit, and Delete. Move up/down are disabled menu items at the sequence boundaries, so the
  row itself has no add or arrow buttons.
- `taxonomy_tree_controller.js` provides safe DOM-built modal fields and nodes, inline name
  editing, insertion boundaries, and the move/insert menu actions. HTML5 drag/drop is an
  optional enhancement. After every successful mutation it performs a same-URL Turbo visit so
  serialized parent/tag descriptors, page counts, and sidebar counts come from one fresh server
  render. User-controlled names and descriptions are assigned with `textContent`/DOM properties,
  never interpolated into `innerHTML`. The controller never builds a whole row: only the rename
  button is created in JavaScript, because a create always refreshes the same URL, so there is no
  second copy of the row layout to drift.

**2. Flat list + Bootstrap modal** (characters, items, events, relations, ownerships):
- `content-surface` + `list-group` rows with shared overflow actions + a modal in the same template.
  Each row also renders `record_details_link` before its actions, so the record's own page is one
  click away and visible to read-only viewers.
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

**Record details pages** are a fourth *page* shape, not a fourth editing pattern: a details page has
no editor, so it is built from the shared read-only partials `shared/_record_details`,
`shared/_detail_facts`, `shared/_detail_section`, and `shared/_tagged_record_list` and never from a
modal. Each record type supplies its own `facts` array and its own sections, so new information is
added to an existing page instead of a new page being invented. See
[architecture.md](architecture.md#record-details-pages) for the URL table and the scoping rules.

### Scene conventions (core, references, grouping, and tags shipped in 11.1–11.4; later slices pending)

[ADR 0007](adr/0007-story-owned-scenes-and-elements.md) accepts the first Scene contract. The
**Scenes** sidebar entry is a real story-scoped link when a story is selected and stays an
`aria-disabled` placeholder (with the existing "select a story" hint) when no story is current.

- **Model:** `Scene belongs_to :story`, includes `HasSlug`, and is flat rather than hierarchical (no
  `parent_id`). A required `name` is labelled **Title**; `description` is optional and a title-only
  Scene is valid. `belongs_to :section, optional: true` and `belongs_to :event, optional: true`
  carry the organizational group and the in-world fact, and the single optional `datetime` carries
  the in-world time point. `has_many_tags :scene_tag, scope: :story_id` supplies optional Story
  Tag assignments. `Scene#universe` resolves through `story.universe`; register `Scene` in
  `Ability::CONTENT_CLASS_NAMES` and `MaintainsSiblingPositions` with
  `maintains_flat_positions_for :scene` and `@story` as the sibling collection and scope owner.
- **Scope is application-level.** `section_belongs_to_story`, `event_belongs_to_story_universe`,
  `optional_references_exist`, and `datetime_is_a_valid_point` are model validations, so an unknown
  optional id or an unparseable datetime becomes a `422` field error through the ordinary HTML
  re-render flow rather than a foreign-key `500` or a silently dropped value. `Section` and `Event`
  both declare `has_many :scenes, dependent: :nullify`: the deletion contract is asymmetric and
  never removes a shared world record or a Scene.
- **Scene Tags:** `SceneTag belongs_to :story`, includes `Hierarchical`, `HasColor`, `HasSlug`, and
  the inverse `has_many_tagd :scene, scope: :story_id`. Definitions use the same positioned
  controller contract as Section Tags, while the Scene form uses `scene_tag_ids` and the shared
  scoped association; no default tag is assigned.
- **Ownership resolution:** `UniverseScopeResolver` is the single answer to which universe owns a
  record. `Ability#universe_for` and `ApplicationHelper#universe_for_record` both delegate to it, so
  record-level authorization and the mutation controls a view renders cannot drift. It resolves a
  record through its own `#universe` or through a declared owner association (`story`, `scene`,
  `section`). A model nested deeper than one of those (a speaker link under a Scene Element) defines
  its own `universe` method delegating through its owner. Do not re-implement the walk in a view or
  a controller, and do not add a controller-specific visibility rule.
- **Section paths:** `SectionPaths` builds every root-first ancestor path and the depth-indented
  selector options from one ordered Section list. Preloading an arbitrary tree depth with
  `includes` is not possible and `ancestor_chain` would query per level per Scene, so list pages
  build the index once instead of walking ancestors in a row.
- **Elements (planned):** `SceneElement belongs_to :scene`; it is an ordered child component rather
  than a standalone navigable content model and has no public slug requirement. Its `kind` is
  `narration` or `dialogue`, `name` is required and labelled **Title**, `body` is optional, and
  `position` is
  flat. Narration rejects speakers; Dialogue requires at least one same-Universe Character speaker.
- **Tags (implemented in 11.4):** `SceneTag` definitions are hierarchical, story-scoped, and
  managed under Configuration → Tags → Story Tags → Scene tags. The same workspace keeps Section
  Tags as a separate tab. Scene Details shows preloaded badges, and its one stable HTML form owns
  optional `scene_tag_ids` assignment; tags are never required or automatically assigned.
- **World links (planned):** use real join models for `SceneCharacter`, `SceneItem`, and
  `SceneLocation` so
  their nullable free-text `role` is persisted. Use a unique join model for
  `SceneElementSpeaker`. Validate same-Universe scope in application code and resolve it through
  Scene in both `Ability` and shared helpers.
- **Controller scope:** resolve `@story` through `Current.universe.stories.find(...)`, then resolve
  Scenes through that Story. Never use `Scene.find`, a universe-level Scene route, or a
  controller-specific visibility rule. Public read actions still pass through the shared
  authorization callback.
- **Routes:** Scenes and Scene Tags are nested under Stories. Canonical Scene paths are
  `/u/:universe_slug/s/:story_id/scenes`, `/u/:universe_slug/s/:story_id/scenes/:scene_id`,
  `.../scenes/new`, `.../scenes/:id/edit`, the member `PATCH .../scenes/:id/move`, and the
  collection `PATCH .../scenes/group`. The Scene Tag workspace is
  `/u/:universe_slug/s/:story_id/scene_tags`; its index renders HTML and its mutations are
  JSON-only. Grouping is a collection action because the workspace form posts the chosen `scene_id`
  next to the chosen `section_id`, which keeps the move working without client-side scripting. Pass
  `story_id`, `id`, and any record id as named route-helper keys; never use positional records. Do
  not add Character/Item/Location/Element routes until the slice that implements them exists.
- **Responses:** Scene index/show/new/create/edit/update/destroy, narrative moves, grouping, and
  Scene Tag assignment use the HTML redirect/re-render flow (`303` for PATCH/DELETE). Scene Tag
  definition mutations are JSON-only, as are Element and role-bearing presence-link mutations in
  later slices; both return `422` error hashes. Do not add an action that ambiguously accepts both.
  Documented per-action failures: a malformed `section_id`/`event_id`/`datetime` or foreign Scene
  Tag assignment in the editor is a `422` re-render; a foreign or unknown grouping target or scene
  is a `404`; a missing `direction` or a missing grouping key is a `400`.
- **Ordering:** the global Scene list is ordered by `(position, id)` and is not grouped by Section.
  Move up/Move down are real `button_to` forms that post `direction=up|down` to the member `move`
  action; they are keyboard operable, disabled at the boundaries, and never the only way to
  reorder. The controller converts a direction into the neighboring position and lets
  `PositionedResourceOrder` clamp and normalize, so a boundary move is an explicit no-op.
  Section assignment is a separate action that changes only `section_id` and never touches
  `position`.
- **UI:** the list uses the existing flat-list surface, Scene Details (`/scenes/:id`) is the
  canonical inspectable page with the same content for every access level, and the full-page form
  pattern (`scenes/_form`, reused by `new` and `edit`) is the only editor. Scene Tag badges are
  preloaded in the list and Details; the form's native optional selector uses full root-first tag
  paths and is the only Scene assignment surface. Do not create a fourth page pattern or a second
  form for the same fields. The editor's workspace tabs go through
  `shared/_content_tabs`: **Scene Details** is a live link, and **Characters**, **Items**, and
  **Locations** are `aria-disabled` placeholders until their slices add a destination. A tab is
  never a link to a route that does not exist and never an in-document Bootstrap pane.
- **Helpers:** add only the Scene-specific descriptors the new forms need. Scene JSON is not used to
  mix the stable HTML form with mutation responsibilities. Update shared count/preload behavior
  without copying the current taxonomy stale-option or modal 406 weaknesses.
- **Sidebar count:** `Story#menu_scene_count` uses its own cache scope
  (`Story::SCENE_MENU_COUNT_SCOPE`, referenced by `Scene` itself) so it never overwrites
  `menu_section_count`; `Scene` declares
  `invalidates_menu_counts_for :story, cache_scope: Story::SCENE_MENU_COUNT_SCOPE`.

### Helpers
- `app/helpers/modal_fields.rb` — field descriptors consumed by the JS controllers:
  - `*_tag_taxonomy_fields(nodes)` — editors for a tag model (name/description/colors/parent),
    e.g. `event_tag_taxonomy_fields`, `section_tag_taxonomy_fields`, `scene_tag_taxonomy_fields`.
  - `*_taxonomy_fields(tags)` — content editors with tag selectors, e.g.
    `location_taxonomy_fields`, `section_taxonomy_fields`.
  - `*_fields_json(record)` — serializes a record for modal pre-filling:
    `event_fields_json`, `character_fields_json`, `item_fields_json`,
    `ownership_fields_json`, `relation_fields_json`.
- `app/helpers/scenes_helper.rb` — Scene grouping/event/time descriptors and
  `scene_tag_choices`; the latter uses `SceneTagPaths` so nested tag options are root-first and
  query-free.
- `app/helpers/application_helper.rb` — `active_if`, `aria_current_for`, `visible?`, `icon`,
  `icon_text_count`, `nav_universes`, `nav_stories` (top bar dropdowns), universe access helpers
  (`can_read_universe?`, `can_write_universe?`, `can_administer_universe?`,
  `universe_access_level`, `universe_access_label`), and `entity_tag_badge` (renders a record's tags
  as colored badges). Counts are right-aligned pills, not parenthesized text; current links carry
  both `.active` and `aria-current="page"`. Details pages add `record_details_link(path, record:,
  count:, count_label:)` — the single Details link used by every row and tree node, with the count
  repeated in its accessible name — plus `detail_fact(label, value, blank:)` for one identity value
  and `in_world_range(from, to)` for the optional interval Event/Relation/Ownership share.
- `app/views/shared/_content_tabs.html.erb` renders related universe pages as URL-backed
  Bootstrap navigation; it does not use `data-bs-toggle="tab"` because each tab is a separate
  request and canonical URL. It accepts an optional `class_name` and explicit `active` tab state
  for nested selectors. A tab hash without `:path` renders an `aria-disabled` placeholder with its
  `:pending_reason` as the title, so a workspace never links to a route that does not exist yet.
- `app/views/shared/_taxonomy_tree.html.erb` accepts an optional `confirm_message` lambda that
  supplies the destructive copy for each node, an optional `read_only_empty_description` so a
  read-only member is not told to add or drag records, and the `details_url`/`details_count`/
  `details_count_label` trio that renders the row's Details link. `_row_actions` accepts the same
  kind of `confirm_text`.
- `app/views/shared/_record_details.html.erb`, `_detail_facts.html.erb`,
  `_detail_section.html.erb`, and `_tagged_record_list.html.erb` compose every record's details
  page. `_detail_section` renders its empty state whenever `count` is zero or no block is given, so
  a page states what it does not know instead of showing an empty box.
- `app/views/shared/_tag_workspace_navigation.html.erb` and `app/helpers/tags_helper.rb` build the
  Configuration → Tags scope/taxonomy navigation and the model-specific tree configuration.
  `TagsHelper#tagged_record_counts` and `app/models/tagged_record_counts.rb` answer the "how many
  records carry this tag" question for a whole taxonomy in one grouped query.
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
navigation surface (not a stack of cards) and becomes a left Bootstrap offcanvas below `lg`. It is
ordered as three scoped blocks — universe, story, tools — and each block is a context header plus
the section it introduces, so the reader always knows which scope a link belongs to:
- **Current universe** context: universe name, visibility plus access label, and the story count
  (from the navbar's memoized story list, so it costs no query).
- **Universe Bible**: direct links to Characters, Locations, Events, Timeline, and Items. Characters
  and Items open their related record tabs (Relations and Ownerships respectively); Locations,
  Events, and Sections remain single-record workspaces.
- **Current story** context: the story name, its cached section/scene counts, and a short
  description — or an explicit **None selected** state with a prompt when no story is current.
- **Story workspace**: Story overview + Sections + Scenes when a story is selected; otherwise All
  stories plus a prompt to select one. New story is available from the navbar's Story dropdown, not
  from the sidebar. **Scenes** is a real story-scoped link with its own cached count once a story is
  selected, and an `aria-disabled` `#` placeholder while no story is current — it never falls back
  to the universe's first story.
- **Configuration**: a separate organization/settings section. **Tags** opens the shared taxonomy
  workspace, with **Universe Tags** selected by default and **Story Tags** for story-scoped
  taxonomies. Universe admins see **Members** in the right-side **Settings** section.
- Real entries show `icon_text_count`; counts are aligned pills. Active entries use a soft primary
  background and `aria-current="page"`. Placeholder entries are flat gray with no hover emphasis, and
  the right-sidebar entries are the intentional `#` placeholders for future functionality.
- Each block has one hue: universe blue, story muted crimson, tools green. The crimson is
  deliberately not the danger red reserved for destructive actions.

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
