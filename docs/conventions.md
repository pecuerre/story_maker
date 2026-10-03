# Conventions

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
  Scene's own components are narrower still: `SceneElement`, `SceneCharacter`, `SceneItem`, and
  `SceneLocation` belong to a Scene and reach the Universe through it. A
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

The `db/data/` layout, the registry, and the per-file rules are in
[data_model.md](data_model.md#development-data-convention); the task workflow — which command to run
when, and what to run after an edit — is in
[development.md](development.md#required-workflow-after-editing-demo-yaml). Neither belongs here. What
a model author needs to know is only this: adding a persisted model means adding its YAML file to
every registered universe directory **and** registering it in `Development::UniverseDataRegistry`, in
the same change, or `db:demo:check` fails.

### Models
- Models that own a hierarchy include `Hierarchical` (parent/children, cycle & scope validations).
  `Relation` and `Ownership` do **not** (they are link records between two entities);
  `Story`, `Universe`, `User`, `Session` don't either.
- `Hierarchical` compares parents within their owning scope through the overridable
  `hierarchy_scope` / `hierarchy_scope_attribute` / `hierarchy_scope_error_key` methods
  (universe by default; `Section`, `SectionTag`, and `SceneTag` override them to compare `story_id`).
  `hierarchy_scope_error_key` returns an **I18n key** rather than a sentence, so a model narrowing the
  scope names `shared.errors.same_scope.story` instead of writing its own English; see
  [`features/i18n.md`](features/i18n.md#the-models-own-validation-messages). It also validates that
  the parent **exists** — see the optional-reference rule below.
- Content ↔ tag pairs are declared with the `has_many_tags` / `has_many_tagged` DSL and a mandatory
  shared `scope:` (`:universe_id`, or `:story_id` for Section and Scene tags). The DSL, the optional-tag
  rule, the inverse read side, the grouped-count value objects that exist because these scopes cannot
  be eager loaded, and the tree and its editor are all in [features/tags.md](features/tags.md).
- `_tag` models include `HasColor` (validated `#rrggbb` `bgcolor`/`fgcolor`) and `HasSlug`.
  `SectionTag` and `SceneTag` additionally use the story-scoped `Hierarchical` scope.
- Name presence is validated on: Universe, Character, Location, Item, Section, Story and all
  `_tag` models. Not on: Event (see [features/events.md](features/events.md)), Relation and
  Ownership (name optional). The two optional names are handled by the `OptionalName` concern
  (`app/models/concerns/optional_name.rb`), which stores a blank name as NULL and keeps the record's
  slug when a name is cleared or cannot be slugified — `HasSlug` would otherwise resolve that to a
  random hex and discard the composite slug those records' demo-data references depend on.
- `Relation`, `Ownership` and `Event` add custom validators that keep their non-tag associated
  records inside the same universe. `HasManyTags` independently enforces the shared universe or
  story scope in both directions for all eight content/tag pairs (see the taxonomy matrix in
  [data_model.md](data_model.md#tag-taxonomy-matrix)).
- **An optional reference that names nothing is a field error, not a database failure.** Three
  validators own that sentence, one per shape of reference: `Hierarchical`'s
  `parent_reference_exists` (`shared.errors.hierarchy.must_exist`), `Event`'s
  `temporal_references_exist` for its three temporal links (`events.errors.must_exist`), and
  `Scene`'s `optional_references_exist` (`scenes.errors.must_exist`). They answer **422** with a
  message on the attribute that carried the id, because the alternative is the foreign key raising
  `ActiveRecord::InvalidForeignKey` — a **500** with no error summary and no hint which control was
  wrong. The check belongs in the model: the same id can arrive from a form, the development-data
  loader, or a console, and a controller-level check would cover only the first. A reference that
  resolves to a record in the **wrong scope** keeps its own separate message rather than being
  folded into this one, so "does not exist" and "belongs to another universe" stay distinguishable.
  `test/controllers/unknown_reference_ids_test.rb` asserts this for every endpoint that accepts a
  `parent_id`.
- **A concern lives in `app/models/concerns/`**, beside `HasSlug`, `HasManyTags`, `Hierarchical`,
  `HasColor`, `InvalidatesMenuCounts`, and `SoftDeletable`. A model that needs behaviour declares it
  with `include` and, where the behaviour is configurable, a class-level DSL on itself — as
  `app/models/concerns/searchable.rb` does.
- **Soft delete** is `SoftDeletable` (`app/models/concerns/soft_deletable.rb`): a `default_scope`
  hides records with a non-null `deleted_at`, `soft_delete`/`restore` mark and unmark a record, and
  `soft_deletes :assoc` declares the associations that cascade. A delete keeps the row, so a
  soft-deleted record is invisible to ordinary queries but restorable. The unique indexes that would
  block re-creating a record with the same key are partial (`WHERE deleted_at IS NULL`), and the
  matching validations carry the same condition. Controllers call `soft_delete` instead of
  `destroy!`; the positioned controllers go through `PositionedResourceOrder`, which normalizes the
  remaining siblings in the same transaction. See [data_model.md](data_model.md#soft-delete).
- **One optional photo** is `HasPhoto`, included by eighteen models, with the two virtual writers
  `photo_data=` (the cropped square as a `data:` URL) and `remove_photo=` rather than a `photo_id`.
  The full contract, the stored-file rules, and the one control that serves all three page patterns
  are in [features/photos.md](features/photos.md).
- **A polymorphic record reference is resolved only through `RecordTarget`.** A
  `record_type`/`record_id` pair is two untrusted strings, and it is never constantized directly:
  `RecordTarget.model_for` matches the type against `Ability::CONTENT_CLASS_NAMES` first, so the
  registry that CanCan builds its content rules from is also the only gate on what a reference can
  name. `find!` additionally requires the record to resolve to a given universe through
  `UniverseScopeResolver`, and refuses an unknown type, an unknown id, a soft-deleted record, and a
  foreign record as one indistinguishable `ActiveRecord::RecordNotFound` (a **404** in the test
  environment). An unknown type is a missing record rather than a permission decision, so refusing
  it as forbidden would let a stored `record_type` be used as an oracle. `RecordTarget` returns
  instances only, which is deliberate: the content rules are instance blocks, and CanCan answers a
  block rule with `true` when given the class, so a class-level `authorize!` on a content model is
  a silent allow. `Discussion` is its first live caller, and it is why a row storing both a
  polymorphic record **and** its own `universe_id` must validate the two against each other in the
  model: neither half is a foreign key, so nothing below the application would notice them
  disagreeing. See [ADR 0019](adr/0019-collaboration-foundations.md).
- **A remembered change's version is a `VersionStamp`, never a bare `updated_at`.** `VersionStamp.capture`
  normalizes a record's version to a fixed-format UTC string and `VersionStamp.changed?` compares
  stamps as strings. Comparing a `Time` to the string it was serialized from is never equal, so the
  naive comparison reports a conflict on *every* change. The comparison is conservative on purpose:
  an unknown or missing base counts as moved, because a false conflict is answerable and a silently
  overwritten edit is not. Whether a record is *deleted* is a separate question from whether it
  moved — a soft delete bumps `updated_at` — so ask `deleted?` rather than inferring it from the
  stamp. See [ADR 0019](adr/0019-collaboration-foundations.md).
- **A group of related value objects gets its own namespace directory.** `Search` is the current
  example: `app/models/search/` holds the query, scope, catalog, client, and the rest of one
  subsystem, rather than sixteen top-level files. A standalone value object with no siblings to
  group with stays flat (`SceneFilter`, `SectionPaths`, `TimelineLayout`). Zeitwerk resolves both,
  so this is a readability choice — reach for a namespace as soon as a second class would otherwise
  sit beside the first.

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
- A JSON-only mutation controller includes `RequiresJsonMutationFormat` and calls
  `before_action :require_json_mutation_format, only: %i[ create update destroy ]` after its record
  lookup, so a request that does not ask for JSON is refused with `406` **before** anything is
  written. Without the guard, `respond_to` raises `ActionController::UnknownFormat` only after the
  record has been saved, so the write commits behind the error and a retry duplicates it. Keep the
  guard an explicit `before_action` rather than a blanket filter so the callback order stays visible.
- Strong params use Rails 8 `params.expect(model: [ ... ])`. A photo-capable controller `include
  PhotoParams` and splat `*photo_params` into its `params.expect`, so the two virtual photo fields
  are declared once instead of in eighteen controllers; see
  [features/photos.md](features/photos.md).
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
    Characters, Locations, Items, Events, Sections, and the Scene-owned `SceneElementsController`,
    `SceneCharactersController`, `SceneItemsController`, and `SceneLocationsController`. The page
    renders HTML; create/update/destroy are called by Stimulus with `Accept: application/json`.
    `SceneTagsController`, `CharactersController`, `ItemsController`, `EventsController`,
    `SceneElementsController`, `SceneCharactersController`, `SceneItemsController`, and
    `SceneLocationsController` also
    include `RequiresJsonMutationFormat`, so a rejected HTML mutation cannot commit first.
  - **HTML flow** (redirect / re-render): Universes, Stories, Scenes, Relations, Ownerships, Universe
    memberships, Sessions, Passwords.
- Actions: `index` + `create/update/destroy` everywhere, `new` for taxonomy editors and
  memberships. `show/edit` exist for Universes, Stories, and Scenes; `show` also exists for every
  content model (Character, Location, Item, Event, Relation, Ownership, Section) and every tag
  model, because each record has exactly one details page. `ScenesController#move` (narrative
  order) and `#group` (Section grouping) are the two member and collection actions beyond that set.
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
  `group_universe_story_scenes_path` for the Section grouping form. Scene-owned resources are nested
  inside `resources :scenes` and mounted at readable paths:
  `resources :scene_elements, path: "elements"`, `resources :scene_characters, path: "characters"`,
  `resources :scene_items, path: "items"`, and `resources :scene_locations, path: "locations"`.
- **Path helpers must receive their keys explicitly** (`universe_story_path(id: story)`,
  `universe_story_sections_path(story_id: story)`): a positional record is assigned to the first
  path segment (`universe_slug`) and breaks the URL. The `universe_slug` itself is then filled in
  from the current request (recall) — that is why `universe_characters_path()` with no arguments
  works on any page inside a universe. A test scans Ruby and ERB call sites and rejects positional
  arguments to `universe_*_path`/`universe_*_url` helpers.
- All section, section-tag, Scene Tag, and scene URLs include the story id
  (`/u/:universe_slug/s/:story_id/...`), and every Scene-owned URL also includes the scene id. The
  universe-level `/u/:universe_slug/sections`,
  `/u/:universe_slug/section_tags`, `/u/:universe_slug/scene_tags`, and
  `/u/:universe_slug/scenes` paths are intentionally invalid.
- Relations/Ownerships are limited to `index, show, create, update, destroy`; memberships are
  mounted at `/u/:universe_slug/members` with `index`, `new`, `create`, `update`, and `destroy`, and
  are admin-only. The taxonomy workspace is `GET /u/:universe_slug/tags`, with `scope=universe|story`
  and `taxonomy=character|relation|location|event|item|ownership|section` query parameters;
  timeline is `get "timeline", to: "timeline#index"`; `root` → `universes#index`; health check `/up`.
- Platform settings are `resource :settings, only: %i[show update]` at `/settings`, outside the
  universe scope, because a display preference belongs to the browser rather than to a universe
  ([ADR 0013](adr/0013-platform-settings-and-browser-theme.md)). `SettingsController` skips
  `set_current_universe` and `authorize_universe_access` and allows unauthenticated access.
- `Universe#to_param` returns the slug; content models are addressed by numeric `id`.
- **Search is both formats**: `GET /search` searches the platform and
  `GET /u/:universe_slug/search` keeps a universe-scoped search inside that universe's URL so the
  shared callbacks authorize it. Both are a single `get` rather than a `resources` collection, so the
  route advertises no action that does not exist. `search_path_for(universe, query)` builds both, for a
  form that must work on either; a search result's own link is the path stored in the document, not a
  route rebuilt at render time. Why serving two formats is safe here is in
  [features/search.md](features/search.md).

### Views - Three Patterns

Every work page starts with `shared/_page_header` (eyebrow, sentence-case title, optional count,
optional description, right-aligned actions) and uses `shared/_empty_state` instead of bare “No records
yet” text. A workspace that has a **tab strip** does not put its own sentence in the header: it passes
it as `shared/_content_intro`, which renders below the strip and above the list as
`.content-intro`. The header's `description` is for a page that is the thing it describes; the intro
is for the list under the reader's chosen tab. Mutation controls are rendered only when `can_write_universe?`; universe settings and member
controls use `can_administer_universe?`. The shared row/taxonomy partials enforce this so read-only
members and public guests see the same content without misleading edit affordances. Flat entity
rows use `shared/_row_actions`: neutral overflow menus for edit/delete, with
destructive actions marked by text/icon rather than a permanently red button. Flash messages are
rendered once by the application layout through `shared/_flash` as floating toasts fixed to the
top-right corner. Success toasts auto-dismiss after 4 seconds; error toasts after 10 seconds. Both
can be closed manually. The `flash_toast_controller.js` Stimulus controller manages the timers.

The three functional editing patterns are:

**1. Taxonomy tree** (all `_tag` indexes, plus `sections` and `locations`): the row shape, the
`create_url`/`update_url` lambdas, the one-overflow-menu rule, the count badge, and the DOM-built
editor all belong to the tag system, in [features/tags.md](features/tags.md). What is shared with the
other two patterns is only this: a row's only URL surface is `data-update-url` (update, move, delete,
inline rename) and its Details link, the editor is a DOM-built modal so there are no `new`/`edit`
routes, and a successful mutation performs a same-URL Turbo visit so serialized parent/tag
descriptors, page counts, and sidebar counts come from one fresh server render. User-controlled names
and descriptions are assigned with `textContent`/DOM properties, never interpolated into `innerHTML`.

**2. Flat list + Bootstrap modal** (characters, items, events, relations, ownerships):
- `content-surface` + `list-group` rows with shared overflow actions + a modal in the same template.
  Each row also renders `record_details_link` before its actions, so the record's own page is one
  click away and visible to read-only viewers. The name is plain text; the Details link is the only
  link into the record's own page.
- Every record workspace uses `shared/_content_tabs`: URL-backed Bootstrap `nav-tabs` that keep
  related records together while preserving each canonical page. Character tags pinned with
  `show_in_menu` also appear on the Relations page. Their links include `from=workspace`; the tag
  details page renders the same workspace tabs only for that explicit navigation, while the
  taxonomy tree's Details link stays canonical and omits them. Tag management uses
  `shared/_tag_workspace_navigation` under Configuration → Tags; it provides the Universe/Story
  scope tabs and the scope-specific taxonomy selector.
- Driven by `modal_form_controller.js`; multi-selects use `data-controller="tom-select"`. The
  controller's mutation contract is the one decided in
  [ADR 0011](adr/0011-modal-json-mutation-contract.md), and every modal page declares it with
  `data-modal-form-response-value`:
  - **`json`** (characters, items, events, Scene Elements, Scene Characters): the form carries
    `data-action="modal-form#save"`, the
    submit input carries `data-modal-form-target="submit"`, the modal body starts with
    `shared/_modal_errors`, and `shared/_row_actions` receives `delete_via: :json` (the Scene
    workspaces render their own row menu, with the same attributes). The controller
    submits the form itself as `application/x-www-form-urlencoded` with `Accept: application/json`
    and the CSRF token, renders a `422` error hash in the modal, and refreshes the page with a
    same-URL Turbo visit after a successful create, update, or delete. A JSON-only **move** control
    (`data-action="modal-form#move"`, direction in the URL) and a JSON-only **delete** are issued by
    the same controller for the same reason: a `204` destroy and a `PATCH` move both give Turbo no
    replacement to follow.
  - **`html`** (relations, ownerships): the documented redirect/re-render flow is untouched. The
    controller only opens the modal and pre-fills it; the browser submits, and `shared/_row_actions`
    keeps its Turbo `button_to` delete with `data-turbo-confirm`. A refused submission re-renders the
    whole index, so the workspace renders `shared/_error_summary` twice — once on the page the author
    lands on, once inside the editor — and serializes the rejected values into the trigger that
    reopens it: the **Add** trigger for a rejected create, and only the row being edited for a
    rejected update. Nothing is ever silently discarded.
  - `test/controllers/modal_json_contract_test.rb` asserts the declared mode, the error region, the
    submit target, the row's delete control, and that a JSON-only endpoint refuses an HTML mutation
    **before** writing, so a new modal page cannot drift back to the old behavior.
- A multi-select is filled and read through the visible `<select>`, never through Rails' hidden
  companion field that carries the same name. An empty multi-select sends one explicit blank value,
  because otherwise clearing the last tag would leave the stored ids untouched.
- `shared/_error_summary` is the one server-rendered model error summary: "N errors prevented this
  X from being saved" plus each full message. It is shared by the flat-page forms and by the
  HTML-flow modal workspaces, and it is what a re-rendered editor shows when the author reopens it.

**3. Plain full-page forms** (universes, stories):
- `new/edit` pages rendering an `_form` partial with `form_with`, error list on top.
- **Stories only** must pass the URL explicitly
  (`form_with model: story, url: story.persisted? ? universe_story_path(id: story) : universe_stories_path`)
  because the routes are not nested under `resources :universes`.
- **The universe form is the only one with an optional address slug.** A universe's slug is its
  public address (`/u/<slug>`) and is global, so two names can derive the same address
  ([data_model.md](data_model.md#slugs)); the field is how an author answers that collision without
  renaming the world. It renders
  **blank on both forms**, and a blank value is dropped in `universe_params` rather than assigned:
  an explicitly supplied slug wins for that save, a blank one leaves `HasSlug` to derive the
  address from the name, and forwarding a cleared slug would republish the universe on an unrelated
  save. Prefilling it is equally wrong — the callback replaces the value on a rename, so the field
  would show an address the form is not going to use. See
  [the delivery history](delivery_history.md).

- Section/story pages pass URLs scoped by story — see `app/views/sections/index.html.erb`
  (the same applies to `app/views/section_tags/index.html.erb`).

**The photo field** is the same control in all three patterns, which is why it is built in one place
and shared by them. The cropper, the `data:` URL transport, the `PHOTO_FIELD` descriptor, the
`PhotoParams` splat, and where the photo sits on a details page are all in
[features/photos.md](features/photos.md).

**Settings** is a platform page rather than a record page: it uses the full-page form shape with no
record behind it, and it is deliberately absent from the right utility sidebar's **Configuration**
section, because a display preference belongs to the browser rather than to a universe. The two
independent preferences, the vertical tab strip, the labelled-card radio groups, and the
`data: { turbo: false }` requirement are in [features/settings.md](features/settings.md).

## The discussion page

A thread is a **fourth page shape**, and it is the one place a read is not a plain read. The
`show`-never-writes rule is not bent to accommodate it: `DiscussionsController#show` is a
guest-readable read of an append-only list, and the find-or-create that opens a thread happens in
`create`, which the **Discuss** control submits to and which redirects to the thread. A `GET` never
creates anything, which is why the control is a button on a record with no thread and a plain link
on a record that already has one — the second case is a page like any other.

**The composer is the only difference between readers.** A guest and a read-only member see
identical messages; the composer renders only for a user who may write, so `assert_select "main
form", count: 0` still holds on a thread for either of them. The author is `Current.user` and the
request cannot name one — the strong parameter list has no `user_id` at all.

A thread resolves its record twice, and both resolutions are the authorized ones: the thread
through its `universe_id`, the record through `RecordTarget` inside the universe the request has
already authorized. The page's back link is the record's own page, built from the record's search
declaration rather than by naming a route per record type, which is the same answer a stored search
document holds. Body text is plain: markdown in discussions is a later decision, so nothing here
renders a fragment. Where a message is refused, the thread re-renders with the reason beside the
composer rather than redirecting, because a redirect would discard what was typed.

**A message states who wrote it and when.** The author and the moment share one line above the body,
because a conversation whose entries are anonymous blocks is not a conversation. The moment is
`l created_at, format: :short` inside a `<time datetime=…>` carrying `created_at.iso8601`, so the
printed value is localized and the machine value stays the exact instant. A blank author name falls
back to `shared.detail_fact.blank` rather than rendering an empty span: `users.name` carries no
presence validation (known quirk 27), and a message with no visible author is the anonymous block
this line exists to prevent.

**An empty thread has two empty states, like every list.** A writer is invited to start the
conversation; a guest and a read-only member are only told what will appear there. Telling a reader
to be the first to say something names an action the page does not offer them, which is the same
defect `docs/visual_design.md` records for a details page's empty copy, and the same
`empty_writable_description` / `empty_read_only_description` pair the lists use.

The Spanish keys for the moment are this application's, not the framework's: `activesupport` ships
an `en.yml` and **no** `es.yml`, so `time.formats.short` and the `date.abbr_month_names` its `%b`
is written with are translated in `config/locales/es.yml` alongside the other Rails-subset keys. A
`l` call with a format this file does not translate raises for a Spanish reader rather than falling
back, because `raise_on_missing_translations` is on in the test environment.

## Record details pages

A details page is a fourth *page* shape, not a fourth editing pattern: it has no editor, so it is
built from the shared read-only partials and never from a modal. Each record type supplies its own
`facts` array and its own sections, so new information is added to an existing page instead of a new
page being invented.

Every standard element and every element tag has exactly one details page, and it is the destination
of the **Details** link that every list row and taxonomy node renders. The URLs are the ordinary
nested resource show routes:

| Record | Details URL |
|---|---|
| Character, Location, Item, Event | `/u/:universe_slug/characters\|locations\|items\|events/:id` |
| Relation, Ownership | `/u/:universe_slug/relations\|ownerships/:id` |
| Character/Relation/Location/Event/Item/Ownership tag | `/u/:universe_slug/<element>_tags/:id` |
| Section, Section Tag, Scene Tag | `/u/:universe_slug/s/:story_id/sections\|section_tags\|scene_tags/:id` |
| Universe, Story, Scene | `/u/:universe_slug`, `/u/:universe_slug/s/:story_id`, `.../scenes/:id` |

A details page is **read-only and guest-readable**: it renders no mutation control at all, so
authorization only decides whether the page is reachable, and a read-only member and a public guest
see identical content. The record is always loaded through the authorized scope
(`Current.universe.<plural>.find` or `@story.<plural>.find`), so another universe's or story's id is a
`404`.

The page is composed from four shared partials:

- `shared/_record_details` — page header (eyebrow, title, back link) plus the identity card. Its
  optional block renders between the two, so a page that keeps a workspace tab strip open there puts
  the navigation above the card and not below it. A record that has a photo lays the card out in two
  columns with the square on the left; a record without one renders the identity block alone, so the
  page is unchanged from what it was before photos existed. Both branches share
  `shared/_record_details_identity`, so there is one identity layout rather than two; Universe,
  Story, and Scene pages have their own identity partials and follow the same rule. Two optional
  locals sit **outside** both branches, so they span the whole card whichever photo layout is in
  place: `wide_facts` for prose that would wrap into the narrow column, and `footer` for the record's
  own settings as compact `label: value` pairs (`shared/_detail_footer`). Both are optional, and
  `facts` is too — a page whose facts are all prose passes none rather than rendering an empty grid;
- `shared/_detail_facts` — the `[ label, value ]` grid, fed by the `detail_fact` helper so a missing
  value renders explicit copy instead of a blank row. `class_name` is what makes the wide variant the
  same partial rather than a second copy of it;
- `shared/_detail_section` — one related-records section, with a `count` badge, and its empty state
  whenever the count is zero or no block was given;
- `shared/_tagged_record_list` — the records carrying a tag, each linking to its own page and showing
  every tag it carries (not just the one filtering the list), batch-loaded through `RecordTags` so the
  badge row costs one grouped query rather than one per record.

A **taxonomy tag** page is the one details page whose facts are split rather than listed: its
description is a `wide_fact` and its scope and colour are `footer` pairs, with the explanation of what
a scope means behind the scope line's info button. That shape is specified in
[features/tags.md](features/tags.md#the-tag-details-card) and is built by one helper,
`TagsHelper#tag_identity_details`, so all eight tag pages cannot drift apart.

A content page currently identifies the record and then states honestly that the related information
will appear later. A Section additionally lists the scenes grouped under it, each still showing its
narrative position, because grouping never sets order. A tag page lists the records that carry it
through `HasManyTags#tagged_records`, the scoped inverse association, so it cannot disclose another
universe's or story's records. A non-taggable grouping tag instead lists records under each direct
child tag; `TaggedRecordsByTag` batches that grouping through the scoped join table, and `RecordTags`
loads each listed record's other badges in one query. Taggable tags retain the include-descendants
toggle and flat list. Menu links carry `from=workspace`, which keeps their content tabs on the tag
details page; a taxonomy Details link does not carry that marker. `TaggedRecordCounts` answers the
same question for a whole taxonomy in one grouped query, which is what the row's `.record-count` pill
uses.

## List rows

Every list row — flat entity lists, taxonomy nodes, and the Scenes list — has the same shape, so a row
means the same thing in every workspace:

- **left**: the record's name as plain text (never a link), followed by its tag badges and, for a
  taxonomy node or a section, a `.record-count` pill holding the number of related records its own
  page will list together with **what it counts** — "(4 characters)", "(3 scenes)". A bare figure
  next to a name is ambiguous in a list of many rows, so the label is part of the visible text and is
  therefore the pill's own accessible name. `record_count_text(count, label)` formats it and
  `record_count_badge(count, label)` wraps it in the pill, which is styled like the sidebar's
  `.sidebar-count` pills;
- **right**: `record_details_link` — real navigation to that record's own page, rendered for read-only
  members and public guests too, labelled **Details** only, with the record name in its accessible
  name — followed by the action menu (`shared/_row_actions` for flat lists, the taxonomy row's own
  menu for trees, and the Scenes row's Edit/Delete menu).

Both halves of the right-hand group are always visible: nothing on a row depends on hover, so the
list works with a keyboard, on touch, and at a narrow width. A count is never part of the Details
label, which keeps the link short in a long list and keeps the count where it can be scanned next to
the name it belongs to. The Details link is the single, predictable way into a record, which is why it
repeats the record name in its accessible name: many identical-looking links stay distinguishable in
a long list.

The taxonomy tree serializes the formatted count onto the node (`data-record-count-label`) because the
tree controller rebuilds the rename button when an inline rename is cancelled; the text is formatted
by the server, so nothing is pluralized in JavaScript.

All work pages use the shared `page_header`, `content_surface`/`entity-list`, `row_actions`,
`empty_state`, and `record_details`/`detail_section` patterns. The three functional page patterns and
their Stimulus controllers are described under [Views](#views---three-patterns) above; the painted
treatment is in [visual_design.md](visual_design.md).

### Scenes

The Scene domain, its four workspace tabs, its Elements, the participation union, the filter, the
value objects, and the deletion contract are one feature with one home, in
[features/scenes.md](features/scenes.md).

### Helpers

- Taggable tag details retain the include-descendants toggle and flat record list. Non-taggable
  grouping tags use `shared/_tagged_records_by_child_tag.html.erb` to render direct children and their
  records without that toggle, with `TaggedRecordsByTag` batching the child assignments. The read
  side and its query budget are in [features/tags.md](features/tags.md).
- `app/helpers/modal_fields.rb` — field descriptors consumed by the JS controllers:
  - `taxonomy_tag_fields(nodes, extra)` — the shared tag-editor fields (name/description/colors/parent/
    `taggable`); `content_tag_taxonomy_fields(nodes)` adds `show_in_menu` for the four content tags.
    The per-type `*_tag_taxonomy_fields(nodes)` helpers delegate to these, e.g.
    `event_tag_taxonomy_fields`, `section_tag_taxonomy_fields`, `scene_tag_taxonomy_fields`.
  - `*_taxonomy_fields(tags)` — content editors with tag selectors, e.g.
    `location_taxonomy_fields`, `section_taxonomy_fields`. Both delegate to one
    `nested_record_taxonomy_fields(tags, parents, tag_field:, tag_label_key:)`, because Location and
    Section are the only two models with a parent *and* a tag assignment and their editors are the
    same editor apart from those two named values. Keeping them as two hand-written blocks meant
    adding a field to one and not the other, which nothing but the two trees rendering differently
    would have shown.
  - `datetime_local_value(datetime)` — the one expression that turns a stored in-world datetime into
    what a `datetime-local` control has to carry. The six call sites this replaces had drifted before:
    they were formatted minute-precision and dropped the stored second, so opening an editor and
    saving it again rewrote the column. `ScenesHelper#scene_datetime_field_value` is the Scene form's
    version of the same rule and additionally keeps a rejected raw value, so a validation error never
    clears the input.
  - `*_fields_json(record)` — serializes a record for modal pre-filling:
    `event_fields_json`, `character_fields_json`, `item_fields_json`,
    `ownership_fields_json`, `relation_fields_json`. Each carries a `photo_url` alongside the
    record's columns, because the photo is a stored image rather than a column and the shared modal
    is what tells the photo control which row it is about to edit. Every in-world datetime goes
    through `datetime_local_value` above, and every control that receives one
    carries `step: 1`: the serializer and the control's step have to agree, or the browser drops the
    seconds the server sent and an open-and-save rewrites the column to zero. That format is
    deliberately distinct from `DATE_FORMAT`, which is what a *reader* is shown and stays
    minute-precision. A serializer's keys are the editor's field names, so a field the editor renders
    but the serializer omits cannot be prefilled — and vice versa. That agreement is the only thing
    joining a serializer to a `form_with`, and neither failure raises, so it is checked rather than
    assumed: `test/helpers/modal_fields_helper_test.rb` pins each key set, and
    `test/controllers/modal_json_contract_test.rb` reads the serialized values and the rendered form
    back out of the page and compares them for every flat editor.
  - A **descriptor is the editor's definition**, not a description of a form: the taxonomy controller
    builds the whole editor from them and `shared/_taxonomy_node` serializes one prefill value per
    descriptor with `node.public_send`. So a descriptor naming a field its tag model cannot produce
    raises mid-render, and a `label_key` that survives into the serialized JSON publishes a key nobody
    renders. Both are checked for all eight taxonomies, and each taxonomy's descriptors are held to
    its own table's columns, in `test/helpers/modal_fields_helper_test.rb`.
  - `PHOTO_FIELD` / `photo_field` — the one descriptor every photo-capable editor shares. `url: true`
    marks the descriptor as naming a stored image: `shared/_taxonomy_node` then serializes
    `record_photo_url(node)` for it instead of calling `node.public_send(field[:name])`. See
    [features/photos.md](features/photos.md).
- `app/helpers/scenes_helper.rb` — Scene grouping/event/time descriptors and
  `scene_tag_choices`; the latter uses `SceneTagPaths` so nested tag options are root-first and
  query-free. It also owns the two answers every Scene participation surface shares, because the
  Characters, Items, and Locations tabs, the Dialogue speaker picker, and the "Appears in Scenes"
  section all answer the same questions and must not answer them differently:
  - `name_id_choices(records)` — `[ label, value ]` pairs where the label is the author's own record
    name and the value is the id. Rails' order, and the reverse of what a `data-*` pair or a
    serialized hash looks like; a reversed pair still renders a full-looking dropdown and submits the
    wrong value. It shares the *builder*, not the candidate list: `scene_element_speaker_choices`
    offers every universe Character because the same Character may speak in any number of Elements,
    while the three tabs offer the Scene's own rows. `scene_location_choices` is the exception and
    builds depth-indented pairs from `LocationPaths`, so two places called "Room" are not ambiguous.
  - `scene_role_label(entry)` — the free-text role as the row states it, or the honest sentence for a
    blank one. Both `SceneParticipants::Entry` (the tabs) and `SceneAppearances::Entry` (a record's
    own details page) answer `#role`, which is all this reads; only the fallback is chrome.
    `SceneAppearances` calls it for a stored link alone, because a derived speaker and a depicted Event
    never carry a role and stating one would be a claim nobody made.
  `test/helpers/scene_participation_helper_test.rb` holds both, across all four surfaces.
- `app/helpers/application_helper.rb` — `active_if`, `aria_current_for`, `visible?`, `icon`,
  `icon_text_count`, `nav_stories` (the universe page's memoized story list), universe access helpers
  (`can_read_universe?`, `can_write_universe?`, `can_administer_universe?`,
  `universe_access_level`, `universe_access_label`), and `entity_tag_badge` (renders a record's tags
  as colored badges). Sidebar counts are right-aligned pills; a row's own count is a pill too, so
  both use the same quiet treatment. Current links carry
  both `.active` and `aria-current="page"`. Details pages add `record_details_link(path, record:)` —
  the single Details link used by every row and tree node, with the record name in its accessible
  name and no count — plus `record_count_text(count, label)` / `record_count_badge(count, label)`
  for the number that record's page will list and what it counts ("(4 characters)"),
  `detail_fact(label, value, blank:)` for one identity value, and `in_world_range(from, to)`
  for the optional interval Event/Relation/Ownership share. `record_photo_url(record)` is the single
  way a view gets a record's photo URL: it returns `nil` when there is no photo, and it asks the
  router for the attachment's URL rather than calling a method on `Photo`, because an Active Storage
  URL belongs to the request that serves it.
- `app/views/shared/_content_tabs.html.erb` renders related universe pages as URL-backed
  Bootstrap navigation; it does not use `data-bs-toggle="tab"` because each tab is a separate
  request and canonical URL. It accepts an optional `class_name` and explicit `active` tab state
  for nested selectors. A tab hash without `:path` renders an `aria-disabled` placeholder with its
  `:pending_reason` as the title, so a workspace never links to a route that does not exist yet.
- `app/views/shared/_taxonomy_tree.html.erb` accepts an optional `confirm_message` lambda that
  supplies the destructive copy for each node, an optional `read_only_empty_description` so a
  read-only member is not told to add or drag records, and the `details_url`/`details_count`/
  `details_count_label` trio that renders the row's Details link and count pill. `_row_actions`
  accepts the same kind of `confirm_text`.
- **A select that must not offer the record being edited declares it on the control.** One modal form
  serves every row, so the server cannot exclude a row's own record from an option list and the row's
  identity has to travel with the trigger: `_row_actions` adds `data-modal-form-record-id`, and
  `modal_form_controller.js` removes that one `<option>` from every `select[data-modal-form-exclude-self]`
  before it fills the stored values, restoring it before the next row opens. The Events page's three
  temporal selects are the current callers; the create trigger carries no id, so a create offers
  everything. The option list is never rebuilt from a cached copy — detaching and re-appending a
  `<select>`'s children loses which option it holds, and the form would then submit a value the author
  never chose. Model validations and database constraints remain the authority; this is only the
  browser not offering a choice the server would refuse.
- **A record with dependents passes its own confirmation; the default is only the fallback.** The
  destructive templates are mandated by
  [ADR 0007](adr/0007-story-owned-scenes-and-elements.md), which owns the sentences and what they
  must say. A flat JSON-only row that owns dependents passes `confirm_text` to `_row_actions`; a
  taxonomy whose nodes own dependents passes a `confirm_message` lambda. Every current caller does:
  Characters, Items, and Events on the flat-list path, and Locations, Sections, and Scene Tags on
  the tree path. `shared.row_actions.delete_confirm` and the tree controller's `Delete … and its
  children?` exist for a record with nothing to announce, and must not be reached by one that does.
- `app/views/shared/_record_details.html.erb`, `_detail_facts.html.erb`,
  `_detail_section.html.erb`, and `_tagged_record_list.html.erb` compose every record's details
  page. `_record_details` renders its optional block between the page header and the identity card,
  which is where a menu tag page passes `shared/_menu_tag_content_tabs` so the tab strip stays with
  the header instead of below the card. `_detail_section` renders its empty state whenever `count`
  is zero or no block is given, so a page states what it does not know instead of showing an empty
  box.
- Both identity branches render `shared/_record_details_identity`, so there is one identity layout
  rather than two, and `shared/_record_photo` is the `<figure>` they use. Universe, Story, and Scene
  have no shared details partial and do the same inline through `scenes/_show_identity`.
- `app/views/shared/_modal_errors.html.erb` is the one error region inside a modal form
  (`data-modal-form-target="errors"`, `role="alert"`, `tabindex="-1"`, rendered hidden). The modal
  controller fills it with the server's error hash and moves focus here; the region is never
  duplicated per error, and the per-control message is built next to its own field.
  `app/views/shared/_mutation_status.html.erb` is the page-level live region rendered once by the
  layout next to `shared/_flash`: it reports a mutation that never went through a form (a row
  delete) or a request that failed outside a modal. A short confirmation is visually hidden and only
  announced; a failure renders a visible alert and takes focus.
- `app/views/shared/_tag_workspace_navigation.html.erb` and `app/helpers/tags_helper.rb` build the
  Configuration → Tags scope/taxonomy navigation and the model-specific tree configuration, and
  `TagsHelper#tagged_record_counts` is the per-page grouped count. All of it is in
  [features/tags.md](features/tags.md).
- `app/helpers/timeline_helper.rb` — popover title/content for timeline events.
- `app/helpers/searches_helper.rb` — the scope list both search surfaces render
  (`search_scope_options`, which disables what the page cannot honour), the scope the top-bar box
  shows (`search_selected_scope`, the *resolved* scope, so a widened search never displays a choice
  that does not describe it), and `search_path_for(universe, query)`, which points a form at
  `/search` or `/u/:universe_slug/search`.

The search subsystem — the request, the scopes, authorization, the registry, the dropdown's
behaviour, and the contrast rules a browser test measures — has its own home in
[features/search.md](features/search.md), and so do the Scene, tag, photo, and navigation
subsystems it shares helpers and Stimulus controllers with.

### JavaScript Controllers (`app/javascript/controllers/`)
- `taxonomy_tree_controller.js` — hierarchy editing: drag/drop, inline rename, modal, JSON CRUD. A
  rejected modal save renders the same summary-plus-field-message contract as the flat-list modal,
  and the editor claims focus back on `shown.bs.modal` when the rejection arrived while the modal
  was still opening. Its single-field paths (inline rename, create, move, delete) announce the
  server's own message when the response body carries one. Its editor is built in `document.body`,
  outside the controller element, so anything it looks up inside the editor is queried on the editor,
  not read as a Stimulus target.
- `modal_form_controller.js` — Bootstrap modal CRUD for the flat list views, including the JSON
  submission, `422` error rendering, pending state, JSON delete, and the same-URL refresh described
  in [ADR 0011](adr/0011-modal-json-mutation-contract.md). **A dismiss that lands while the dialog is
  still opening is deferred to `shown.bs.modal` instead of being dropped**, and the taxonomy tree
  editor does the same on its own instance: Bootstrap's `hide()` returns without doing anything while
  the instance is transitioning in, and the `btn-close` button, the footer's **Cancel**, Escape, and a
  backdrop click all resolve to the one instance each controller owns. Wrapping `hide()` covers all
  four triggers at once, so no editor has to be dismissed twice.
- `photo_crop_controller.js` — the square photo editor, which serves all three page patterns from one
  implementation. It is described in [features/photos.md](features/photos.md), including the rule
  that it must stay a **named** class export.
- `timeline_controller.js` — redraws the edges between Timeline nodes on resize, and opens each
  node's Bootstrap popover. It is not a pan/zoom surface: the Timeline is a static layered view.
- `popover_controller.js` — a Bootstrap popover on a control that is not otherwise interactive, used
  by the info button beside a tag's `scope:` line. Its title and content are Stimulus values rendered
  by the server rather than client-side literals, for the reason in
  [features/i18n.md](features/i18n.md#a-string-the-browser-has-to-have); its only job beyond that is
  constructing the instance and releasing it on disconnect.
- `tom_select_controller.js` — enhanced multi-selects (tom-select) for tag pickers.

Both editors that mutate through `fetch` send the page's `csrf-token` meta tag as `X-CSRF-Token`
from the same code path, and a page without a token sends no header at all rather than the string
`"undefined"`.

Client-side rules:
- A user-controlled value is only ever text or an attribute. `test/javascript/no_html_sink_test.js`
  fails if a new `innerHTML`/`outerHTML`/`insertAdjacentHTML`/`document.write` sink appears in
  `app/javascript` without a reviewed, commented exception; the only one is the Timeline's static
  SVG arrow markers.
- A user-facing string is a **`t()` call against the layout's blob**, never a literal.
  `test/javascript/no_client_string_literals_test.js` fails when a quoted string that reads as
  prose appears in `app/javascript`; `app/javascript/i18n.js` is the only lookup, and
  `ClientStrings` (`app/models/client_strings.rb`) is the only list of what it may resolve. The
  whole contract, including what a controller asks the server for, is in
  [features/i18n.md](features/i18n.md#a-string-the-browser-has-to-have).
- Every shared editor's serialization, error-rendering, and DOM-building logic has a `bun test`
  case in `test/javascript/`, next to the controller it covers. Browser tests are for what only a
  browser can show (focus, Turbo navigation, a real token on the wire).
- `bun run lint:js` (Biome, recommended rules) is part of CI alongside `bin/rubocop`.


### Navigation

The navbar and both workspace columns — what they contain, in what order, the three scope hues, and
the two-step universe-then-story selection — are one feature with one home, in
[features/navigation.md](features/navigation.md).

## Events and the Timeline

Event's three special properties (`Hierarchical` plus self-referencing temporal relations, optional
tags, title-driven identity, `must_be_identifiable`) and the Timeline's layering algorithm have one
home, in [features/events.md](features/events.md).

