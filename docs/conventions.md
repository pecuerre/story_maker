# Conventions

> Companion docs: [data_model.md](data_model.md) (schema, tables, validations),
> [architecture.md](architecture.md) (request lifecycle, routing/URL rules, UI patterns, timeline),
> [development.md](development.md) (commands, tests, seeding, CI, deployment),
> [known_quirks.md](known_quirks.md) (verified oddities — read before touching shared code).
> Full index: [README.md](README.md).

## Core Patterns

### Database Schema
- Content records are scoped to a **universe**; the story-scoped exceptions include `Section`, `Plot`,
  `Scene`, `SectionTag`, and `SceneTag` (`Section belongs_to :story`, `Plot belongs_to :story`,
  `Scene belongs_to :story`,
  `SectionTag belongs_to :story`, `SceneTag belongs_to :story`, and `Story belongs_to :universe`). A
  Scene's own components are narrower still: `SceneElement`, `SceneCharacter`, `SceneItem`, and
  `SceneLocation` belong to a Scene and reach the Universe through it; `SceneDialogueTurn` belongs to
  a `SceneElement` and delegates through that owner. A
  universe holds many
  stories (e.g. universe *A Song of Ice and Fire* → stories *Game of Thrones*, *House of the Dragon*),
  which share the universe's characters/locations/events/items but each own their script structure,
  Plot arcs, and ordered scenes. The distinct Plot domain is in
  [features/plots.md](features/plots.md).
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
  (universe by default; `Section`, `SectionTag`, and `SceneTag` declare `hierarchy_scoped_by :story_id`,
  which is what `hierarchy_scope_attribute` now reads, and override only `hierarchy_scope`).
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
- Name presence is validated on: Universe, Character, Location, Item, Section, Story, User and all
  `_tag` models. Not on: Event (see [features/events.md](features/events.md)), Relation and
  Ownership (name optional). The two optional names are handled by the `OptionalName` concern
  (`app/models/concerns/optional_name.rb`), which stores a blank name as NULL and keeps the record's
  slug when a name is cleared or cannot be slugified — `HasSlug` would otherwise resolve that to a
  random hex and discard the composite slug those records' demo-data references depend on.
- **A composite slug that embeds a tag reads that tag deterministically.**
  `HasManyTags#first_tag_slug` picks the first tag *by slug* rather than off the collection's
  arbitrary order, so two records carrying the same tags in a different assignment order reach the
  same address — which a symbolic `db/data` reference and a class-level lookup both depend on. It
  reads the association in Ruby rather than querying, because the record being slugged is new and its
  join rows do not exist yet.
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
  `HasColor`, `InvalidatesMenuCounts`, `OrderedSequence`, `SoftDeletable`, and `TemporalInterval`. A
  model that needs behaviour declares it with `include` and, where the behaviour is configurable, a
  class-level DSL on itself — as `app/models/concerns/searchable.rb` does.
- **An interval that cannot run backwards** is `TemporalInterval`, declared with
  `has_temporal_interval from: …, to: …`: `Event` on its two datetimes, `Relation` and `Ownership` on
  `from_date`/`to_date`. A range with both ends whose end precedes its start is refused on the **end**
  attribute (`shared.errors.interval.must_not_be_reversed`), because that is the field whose value
  cannot be right. **An absent end is not this rule**: a nil end is an interval that is still open or
  whose end is unknown, both legitimate, and only a range with both ends present is checked.
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
  block rule with `true` when given the class, so a caller that holds a class has nothing to
  authorize. `Discussion` is its first live caller, and it is why a row storing both a
  polymorphic record **and** its own `universe_id` must validate the two against each other in the
  model: neither half is a foreign key, so nothing below the application would notice them
  disagreeing. See [ADR 0019](adr/0019-collaboration-foundations.md).
- **A class-level check is answered by `Ability`, never by CanCan.** `Ability#can?` intercepts any
  subject that is a class and answers the question the object-based policy otherwise cannot: *does
  this user hold this action on at least one record of this class inside the universe the request
  has already authorized?* CanCan would otherwise answer `true` for any subject its instance blocks
  were declared on, having consulted no universe at all. Each rule is declared once, through
  `define_rule`, and yields both answers from the same access level, so a class check and a record
  check cannot disagree about the same user and the same universe. The universe is passed into the
  constructor by `ApplicationController#current_ability` — the ability stays a policy object and
  never reads `Current` itself — so the answer is scoped to one universe and cannot reach beyond it;
  with no such universe there is nowhere to look and the answer is `false`. A class with no rule of
  its own (`Universe#create`, which has no record and no universe to scope to, and every
  non-content model) still falls through to CanCan, which refuses it as an unauthorized action. The
  rows a class check looks in are the model's own path to its universe, walked in SQL by
  `UniverseScopeResolver.records_in` — the same `owner_association_for` answer, one hop at a time,
  that `universe_for` walks in memory for a record.
- **A record's universe is resolved by `UniverseScopeResolver`, and a model deeper than one hop
  declares its own `#universe`.** Record-level authorization (`Ability#universe_for`) and the rendered
  mutation controls (`ApplicationHelper#universe_for_record`) both ask this one resolver, so they
  cannot drift into disagreeing about which universe owns a row. The walk is bounded to `story`,
  `scene`, and `section` — deliberately, so a record can never reach the wrong universe by accident —
  and a model one level below those, such as a speaker link under a Scene Element, defines
  `#universe` to delegate through its owner; the walk finds it on the first step and no entry is
  added. A model that does not is caught two ways, and the two are not the same repair:
  `universe_for` resolves to `nil`, which reads as a denial to `Ability` and as no controls to the
  views and raises nothing anywhere, so a test requires every persisted row of every model in
  `Ability::CONTENT_CLASS_NAMES` to resolve; and `records_in`, which filters in SQL and so cannot
  follow a Ruby delegation, raises `UniverseScopeResolver::UnresolvableModel` naming the model.
  Defining `#universe` clears the first and not the second — the class path additionally needs a
  `universe_id` column, or the model stays out of the content registry so no class-level check is
  asked of it.
- **A remembered change's version is a `VersionStamp`, never a bare `updated_at`.** `VersionStamp.capture`
  normalizes a record's version to a fixed-format UTC string and `VersionStamp.changed?` compares
  stamps as strings. Comparing a `Time` to the string it was serialized from is never equal, so the
  naive comparison reports a conflict on *every* change. The comparison is conservative on purpose:
  an unknown or missing base counts as moved, because a false conflict is answerable and a silently
  overwritten edit is not. Whether a record is *deleted* is a separate question from whether it
  moved — a soft delete bumps `updated_at` — so ask `deleted?` rather than inferring it from the
  stamp. `DraftConflictDetector` is where both are asked, and it asks deletion **first**, because
  `soft_delete` writes `deleted_at` *and* moves the stamp: checking the version first would report
  every already-deleted record as moved and make "already gone" unreachable. That needs a record
  `RecordTarget.find` refuses, so the detector resolves through `RecordTarget.find_including_deleted`
  and reads the deleted state through `RecordTarget.soft_deleted?` rather than with a query of its
  own. See [ADR 0019](adr/0019-collaboration-foundations.md).
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
- **A controller never looks up its own `@universe` or `@story`.** It registers
  `before_action :set_universe` or `before_action :set_story` and reads the instance variable:
  both callbacks are defined once in `ApplicationController` and assign `Current.universe` and
  `Current.story`, which the request has already resolved and already scoped-checked. Adding a
  private `set_story` that does `Current.universe.stories.find(params.expect(:story_id))` is the
  shape that must not come back — the same row, found a second time, by an object nothing
  authorized. The rule and the failure it prevents are in
  [architecture.md](architecture.md#one-resolution-one-object); the guard is
  `test/controllers/authorize_once_act_on_it_test.rb`.
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
- **A positioned model also repairs its own sequence, so the service is not the only thing keeping
  positions contiguous.** The controller concern owns an *application* mutation; `OrderedSequence`
  owns what happens when a write reaches the model instead — `destroy!`, `soft_delete`, `restore`
  from a console, an import, or a cascade — and renumbers the whole group on each of those three
  moments. A hierarchical model gets it from `Hierarchical`; a flat one declares
  `ordered_sequence_within :owner`. Read the three moments, the restore-inclusion rule, and the
  `positions:normalize` command that repairs what neither can reach, in
  [data_model.md](data_model.md#hierarchies--positions). It is deliberately *not* a
  second write path for creates and moves: those still go through `PositionedResourceOrder`, which is
  the only place that locks the scope owner.
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
- Never read top-level params with `params.permit`. A form posts keys beyond the ones an action
  needs — `authenticity_token` and `commit` on every Rails form — so permitting a bare list
  classifies those as unpermitted and logs them on each request, which is noise that hides a real
  unpermitted-parameter report. Read bare scalars by name instead: `params.expect(:email_address,
  :password)` returns an Array when more than one key is asked for, so destructure it and pass the
  values on by keyword. `expect` also calls `require`, so a missing or renamed field answers `400`
  rather than authenticating against a `nil`.
- Universe authorization is a three-level policy: `read`, `write`, and `admin`. Public universes
  grant guest read and signed-in write access; private universes require an owner or membership.
  A private-universe non-member, including a guest, receives 404 so slug enumeration cannot
  distinguish it from an unknown universe. The owner is always admin, and a membership's level
  applies uniformly to all universe/story components. Admin membership management is an HTML flow
  at `/u/:universe_slug/members`.
- **In a universe that is not `direct`, a mutation is remembered rather than written.** Every mutation
  controller includes `DraftMutation` and calls one of three methods as the first statement of the action
  that would otherwise write — `remember_draft_create(record, attributes)`,
  `remember_draft_update(record, attributes)` (or `remember_draft_update(record)` for a link the action has
  already assigned), `remember_draft_delete(record)` — and each returns `true` once it has remembered a
  change and rendered the response, so the call is written `return if …` and the live write below it stays
  untouched. The call is **inside the action, not a `before_action`**: only there does the controller hold
  both the record it would have written and the attributes it was going to write with it, and a callback
  would have to answer "what would this action write?" a second time — two answers that drift. It is also
   deliberately a call a controller can forget, so `test/controllers/draft_mutation_test.rb` walks all
   twenty-one mutation controllers in both modes rather than testing the concern alone: a controller that omitted
   it would write straight through and nothing else would notice. This includes Story create/update/delete;
   `move` and `group` are mutations too, and
  remember the position or the section they asked for. A remembered change is **not validated when it is
  remembered** — it is the author's statement of intent, and the applier re-runs the live mutation path, where
  the model's own validations are authoritative; a second answer here would be a second opinion about the
  same record. See [ADR 0020](adr/0020-remembering-mutations-instead-of-writing-them.md).
- What a remembered `create` stores is the submitted attributes **plus the column that places the record in
  its scope** (`universe_id`, `story_id`, or `scene_id`, read the way `UniverseScopeResolver` walks), because a
  payload of submitted values alone cannot say which story or scene the record belongs to. The submitted
  attributes — not the record's own attributes — are the payload, because they are the only source for the
  values no column holds: tag id lists, and the two virtual photo fields, which `HasPhoto` keeps in instance
  variables and never marks as changed. Nothing else is copied out of the record: a column the author never
  submitted (a nil `position`, a not-yet-generated `slug`) would be remembered as a value to write rather than
  as a value to let the live path decide.
- **Which column that is has one answer, read from the model rather than re-derived.**
  `UniverseScopeResolver.owner_association_for(model)` names the owner association a model's columns give it,
  and three callers read it: `DraftMutation` choosing the column to merge into a create's payload,
  `DraftApplier` choosing the collection to order and the scope to resolve, and `DraftChange#scope_attribute`
  naming the same column so a draft's own page can recognise it as plumbing rather than print it.
- **`DraftsController` is the only page that reads a draft, and it requires a signed-in user.** A draft
  belongs to a person, so there is no guest-readable version of `/u/:universe_slug/drafts`. A draft is read
  as its own author's inside the universe the request has already authorized — `Draft` is deliberately not a
  content class (ADR 0019), so there is no CanCan rule to ask and the scope is the query itself. Another
  author's draft, a draft in another universe, and a draft that does not exist are one **404**. `index` and
  `show` are reads; `apply` and `discard` are writes, and the shared universe policy asks for `write` from
  the action's name alone. It is the only page that reads a draft's **whole** change list: the list
  workspaces and the sidebar panel read the same draft through `DraftPreview`, which is the same query
  under the same scope rather than a second way in.
- **An apply writes through the live mutation path, and the applier derives a model's ordering rather than
  listing it.** `DraftApplier` routes an ordered collection through `PositionedResourceOrder` and an
  unordered one through `save`/`update`/`soft_delete`, deciding which from the model's own columns — a
  `position` column means the service maintains that sequence, a `parent_id` column means its siblings are
  scoped by one — with the sibling collection being the owner's association that every positioned
  controller's `sibling_collection` already returns. `test/services/draft_applier_test.rb` holds that
  derivation against every routed controller that declares itself positioned, in both directions, because a
  second list of ordered models would drift from the fifteen controllers that declare their own. Whether a
  change *can* be written is not decided here: `DraftApplier` asks `DraftConflictDetector` and writes
  only a change it calls writable, so the apply's skip decision and the resolution page's list of
  conflicts are one answer rather than two comparisons. The five reasons are `SKIP_REASONS` — `:moved`
  and `:deleted` (the two conflicts, from the detector), `:missing`, `:gone` (a delete whose record is
  already deleted, which is reported rather than claimed as written), and the applier's own
  `:unplaceable` and `:refused`. A create is not asked about a version at all: it names no record, and
  its two failures are about a stored scope column and the live path's refusal. A change the applier
  cannot *interpret* is a prior question rather than one of these five, and `DraftIntegrity` owns it —
  see [the drafts page](#the-drafts-page). The draft is closed
  either way; the reasoning, and why refusing the whole apply was rejected, are in
  [ADR 0021](adr/0021-applying-a-draft-through-the-live-mutation-path.md).
- Password-reset responses set `Cache-Control: no-store` and `Referrer-Policy: no-referrer`.
  `PasswordResetPathFilter` redacts reset-token path segments from Rails request logs; upstream
  proxy/access-log retention remains an external deployment responsibility.
- Response formats:
  - **JSON-only mutations** (`respond_to` → `format.json`, no HTML): every `_tag` controller plus
    Characters, Locations, Items, Events, Sections, Plots, and the Scene-owned `SceneElementsController`,
    `SceneDialogueTurnsController`, `SceneCharactersController`, `SceneItemsController`, and
    `SceneLocationsController`. The page
    renders HTML; create/update/destroy are called by Stimulus with `Accept: application/json`.
    `SceneTagsController`, `CharactersController`, `ItemsController`, `EventsController`,
    `SceneElementsController`, `SceneDialogueTurnsController`, `SceneCharactersController`,
    `SceneItemsController`, and `SceneLocationsController` also
    include `RequiresJsonMutationFormat`, so a rejected HTML mutation cannot commit first.
  - **HTML flow** (redirect / re-render): Universes, Stories, Scenes, Relations, Ownerships, Universe
    memberships, Sessions, Passwords, Drafts, Review Requests.
- Actions: `index` + `create/update/destroy` everywhere, `new` for taxonomy editors and
  memberships. `show/edit` exist for Universes, Stories, and Scenes; `show` also exists for every
  content model (Character, Location, Item, Event, Relation, Ownership, Section, Plot) and every tag
  model, because each record has exactly one details page. `ScenesController#move` (narrative
  order) and `#group` (Section grouping) are the two member and collection actions beyond that set.
- **A route may only advertise an action the controller has, and a GET may only name an action with a
  template.** A `resources` line names seven verbs whether or not they exist, and the two ways of
  being wrong look different from the outside: a missing action answers `ActionNotFound` (**404**),
  while an action with no template answers `ActionController::MissingExactTemplate` (**500**). The
  modal-edited content models — Characters, Locations, Items, Events, Sections, Plots — therefore carry
  `only: %i[index show create update destroy]` and **no `new`/`edit` page at all**: the modal holds
  the form, and the `parent_id` the old `new` action read is still accepted by `create`. Sessions and
  passwords are the other two narrow surfaces, at `new`/`create`/`destroy` and `new`/`create`/`edit`/
  `update` respectively. `test/routing/route_action_contract_test.rb` holds both halves of the
  contract, per request verb rather than per action, because a mutation correctly renders no template.
- A `show` action is **read-only and guest-readable** (`allow_unauthenticated_access only: %i[index
  show]`), loads its record through the authorized scope, and renders no mutation control. Because
  a details page has no form, `can_write_universe?` only decides whether an editor link is
  rendered, and read-only members and guests see identical content.

### Routes
- Universe content lives under `scope "u/:universe_slug", as: :universe` → helpers are prefixed
  `universe_*` and URLs look like `/u/<universe-slug>/...` (see `config/routes.rb`).
- Stories are a full resource in that scope with sections, plots, section tags, Scene Tags, and scenes nested
  underneath:
  `resources :stories, path: "s" do resources :sections; resources :plots; resources :section_tags; resources :scene_tags; resources :scenes end`
  → `/u/:universe_slug/s/:story_id/sections`, helpers `universe_story_*`,
  `universe_story_section(s)`, `universe_story_plot(s)`, `universe_story_section_tag(s)`, `universe_story_scene_tag(s)`,
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
- **Drafts are `index`/`show` plus two member POSTs**, mounted at `/u/:universe_slug/drafts`:
  `resources :drafts, only: %i[ index show ]` with `post :apply, on: :member` and `post :discard, on:
  :member`. The two are POSTs rather than `resources` verbs because each is a decision the author makes
  about their own pending work and neither is idempotent — an `apply` writes records, and a `discard`
  closes the draft — and there is no `create` or `destroy` because a draft is opened by the remembering
  path and is never deleted, only moved to another status.
- **Review requests are the same shape**, mounted at `/u/:universe_slug/review_requests`:
  `resources :review_requests, only: %i[ index show ]` with `post :approve, on: :member` and `post
  :reject, on: :member`, for the same reason and one more — an `approve` writes every remembered change
  in somebody else's draft. Every action is admin-only, and `approve` is also where a conflict page
  posts back to.
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

- **The mutation budget on that form is the one field whose empty value is an answer.**
  `universes#edit` and `#update` ask for `admin` on the universe, so
  `universes.mutation_limit` is a governance setting like `collaboration_mode` and lives on this
  form rather than on a page of its own ([ADR 0028](adr/0028-per-universe-mutation-budget.md) is
  the decision). It binds its value **explicitly** —
  `universe.mutations_unlimited? ? nil : universe.mutation_limit` — because Rails' own binding is
  not the one this field needs: `Tags::Base#value_before_type_cast` asks the model for the
  before-cast value only when that value **came from the user** in this request, and a record read
  from the database falls back to the public reader. `NULL` is how an admin says "no limit at all",
  and `Universe#mutation_limit` answers `DEFAULT_MUTATION_LIMIT` for such a row, so the default
  field would print 60 where the admin chose none and would impose 60 on the next save. Clearing
  the field is how a limit is removed: the blank value is forwarded as `nil` and stored, the
  **inverse** of the slug rule above, where a blank value is dropped. An **omitted** parameter is
  not an answer in either case, so a caller that never mentions the budget cannot clear one.

  **The three per-group ceilings below it are that same field, rendered from a map.**
  `Universe::MUTATION_GROUP_COLUMNS` is the list, so the form loops over it instead of writing three
  copies, and every rule above applies to each: the explicit binding
  (`mutation_group_unlimited?(group) ? nil : mutation_group_limit(group)`), the blank-means-`nil`
  forwarding, the omitted-means-untouched rule, and the `min` that states the model's own rule. The
  model, the controller's permitted list (`LIMIT_PARAMS`), and the labels — named after the column,
  `universes.form.<column>` — all come from the same map, so a fourth group is one entry and one
  column rather than four places to remember ([ADR
  0029](adr/0029-per-endpoint-throttle-groups.md) is the decision).

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
back to `shared.detail_fact.blank` rather than rendering an empty span: a message with no visible
author is the anonymous block this line exists to prevent, and `User` validates `name`'s presence, so
a blank one can now only arrive from a direct write or an import that bypassed the model.

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

## The drafts page

A draft is **the reader's own pending work**, so this is a fifth page shape rather than another reading
of `show`. It is not a record's details page, and the "a `show` renders no mutation control" rule does
not apply to it: acting on a draft *is* what the page is for. What the rule above it does say is kept —
every action requires a session, `index` and `show` are reads the universe policy answers at `read`,
and the controls are rendered only while `Draft#open?`, so an applied or discarded draft offers
nothing to do.

**Which control is primary is the universe's collaboration mode, and the mode is on the actions as
well as on the buttons.** A `wikipedia` universe has one author and no reviewer, so the primary control
is **Apply changes**, which writes the remembered changes live. A `github` universe has a reviewer, so
the same control becomes **Submit for review**, which hands the draft over instead — and **Discard** is
the third control in both, because throwing away your own pending work needs neither a reviewer nor a
mode. `apply` refuses a `github` universe and `submit` refuses every other, each with
`drafts.flash.wrong_mode`: hiding the other mode's button is where the rule is *read*, and refusing the
action is where it is *decided*. A draft in a `github` universe may also be closed, so `apply`'s mode
check comes first — it is the more fundamental of the two refusals.

**The handover is a form with a field, not a `button_to`.** The author's optional message cannot travel
on a control, which is the same reason a reviewer's approval is a form (see
[The reviewer's page](#the-reviewers-page)). It is a parameter of the submission rather than a column
an author edits — `Draft#submit!(message:)` writes it onto the `ReviewRequest` it creates — because a
rejected draft comes back as working work and the next handover gets its own message. A blank message
is stored as `nil`, for `review_notes`' reason: an empty box would read back as something the author
wrote. The list's row offers the same handover as a plain button, since a message is optional and a list
row has nowhere to type one; the draft's own page is where it is written.

**Nothing about a draft's changes is read to submit one**, for `reject`'s reason on the other side: a
submission carrying a change the applier cannot read is still submittable and still rejectable, and
refusing it would leave the author with a draft only **Discard** can clear. **Only a working draft can be
submitted**: a submitted one is already with a reviewer and the partial unique index would refuse the
second row anyway, and it is refused with `drafts.flash.waiting_for_review` rather than the closed-draft
sentence, because it is very much still open.

**The author reads where their submission stands, on their own page.** `drafts/_submission_status` renders
the **newest** `ReviewRequest` — not the pending one — because a rejected submission hands the draft
back, so the draft says `draft` again and the row carrying the reviewer's reason is the only thing that
still holds it. It shows the stored status, the moment, the author's own message and the reviewer's
notes, because `ReviewRequest` requires a rejection to say why and those notes are written *for the
author*. That is the half slice 5.2 left open: the notes were stored and only ever printed where the
reviewer stood, which made the requirement a message into a place the author cannot reach. The same two
facts travel to the author in a [notification](#notifications) when they are not on the page at all.

**A submitted draft refuses new changes, in the caller's own response shape.** `DraftMutation` appends
a change to the author's open draft, and `Draft::OPEN_STATUSES` is `%w[draft submitted]`, so a `github`
author who kept editing after **Submit for review** used to have those changes land in the middle of
the draft a reviewer was reading — after the submission message was written, with nothing in the
request saying which changes were in it when it was made. Nothing was hidden: the reviewer's page and
the applier both read the draft live. What was lost is the guarantee that what was reviewed is what
was submitted, and a `DraftIntegrity`-shaped refusal restores it. A **JSON** editor gets a **`422` with
a `base` message**, which is the one attribute with no field beside it and so belongs in the shared
error summary; an **HTML** workspace gets a **redirect to the draft's own page with the sentence as an
alert**, because that page is where the one control that clears this state — **Discard** — lives. The
refusal returns `true`, so a caller cannot fall through to the direct write underneath it. It belongs to
`github` alone rather than to `draft_based?`: nothing is ever submitted in a `wikipedia` universe, so
there is no such state to refuse. Both ways out of it are the author's own — wait for a decision, or
withdraw — and a rejection hands the draft straight back to being editable.

**Discarding a submitted draft withdraws the submission with it**, in one transaction
(`ReviewRequest#withdraw!`). Otherwise the reviewer's queue keeps waiting on work the author has thrown
away and approving it would still write the changes, because `DraftApplier` asks whether a draft is open
nowhere. A withdrawal is the author's own answer rather than a reviewer's, so the row carries **no
reviewer and no notes** — nobody reviewed it — which is also why `withdrawn?` is not `decided?`: "decided"
answers "did a reviewer rule on this", which is the question an audit asks. It stays in the queue's
history rather than disappearing, and both the queue and the submission's page say who ended it.

**Three pages: one list, one draft, and the conflicts an apply stops on.** `/u/:universe_slug/drafts`
lists the reader's own drafts in that universe with the actionable one first, because history sorted
above the pending work would push the draft the reader came for out of the list;
`/u/:universe_slug/drafts/:id` shows one draft's changes in the order they were remembered. There is
no `new` page and no `create`: a draft is opened by the remembering path (`Draft.open_for!`), never by
an author. The third page is not reached by a link — it is what `apply` answers when the draft it is
applying holds a conflict, and it posts back to the same action (below).

**A conflict stops the apply and is asked about instead of written or skipped.** `apply` runs
`DraftConflictDetector` on *this* request, before anything else, and if it finds a conflict it renders
`drafts/conflicts` as a `422` — an apply being refused until it is told what to do — with one row per
conflict: the record and its kind, the state that put it here, the author's remembered values beside
the record's current ones under the same labels, one sentence saying what each of the two buttons
would do *to that row*, and then **Apply theirs** / **Apply mine**. Nothing is written until every
conflict has an answer, because a half-applied draft and a remembered create are the duplicate-write
hazard [ADR 0021](adr/0021-applying-a-draft-through-the-live-mutation-path.md) closes.

The answers are **per-request parameters, never stored**: one form holds every conflict, each row's
two buttons carry that row's answer in their `name`/`value`, and an answer decided on an earlier pass
comes back in a hidden field rendered *before* its row's buttons — Rack keeps the last value of a
repeated key, so re-pressing a row overrides rather than loses. Only values `DraftApplier::ANSWERS`
holds are read, and only for a change that still conflicts on the request that uses them, which is
why an answer is an instruction to write over somebody else's record and neither the controller nor
the applier may skip its half of that check. A change answered `"theirs"` is dropped on purpose: it
is reported in `Result#answered`, not in `skipped`, so the apply is not partial and the flash adds
`drafts.flash.kept_theirs` as a sentence of its own rather than as a count in the progress one.

**A row states what a change says, and never that it was written.** Each change names its action
(create, update, delete), the record it is about, and the values it carries. A remembered create names
no record, so its row is titled by the type it would create; a change whose record has since been
deleted keeps its row and loses its link, because a link to a page that answers 404 is a dead
affordance. Whether a change was applied is not a fact the page can *infer* — the apply itself moves
every version it writes, so a comparison cannot distinguish "written by this draft" from "changed by
somebody else" — but it is a fact the apply **stored**, so a closed draft says it (below). Three stored
values need reading rather than printing, and `DraftsHelper` owns all three: a submitted id list (a
tag assignment, a Dialogue's speakers) is printed as the names its own association resolves, the scope
column is printed as the **name** of the story or scene it places the record under — a bare `story_id`
is nothing a reader can name, and the reader does not otherwise know which of a universe's stories a
change belongs to — and the two virtual photo writers are stated as a new photo or a removed one rather
than as a `data:` URL and a boolean. A `universe_id` scope prints nothing, because the page is already
inside the universe that column names; see [Reading a draft's changes](#reading-a-drafts-changes).

**A closed draft says when it was closed and what its run did.** An applied or discarded draft is
still served by its own page and still lists every change it remembered — that is what
[ADR 0021](adr/0021-applying-a-draft-through-the-live-mutation-path.md) promised when it decided that
a skipped change stays listed — and it now carries a **history** the flash cannot be: the moment it
stopped being actionable (`closed_at`, one column rather than one per closing reason because `status`
already names which closure it was) and the run's tally. Each change's own row adds the outcome the
apply stored, beside the values it carries and never instead of them, because a change the universe
refused is still what the author asked for and is still redoable by hand. The sentences are
`drafts.history.*` and `drafts.outcomes.*`, and every surface that reports a closed draft reads them
through `DraftsHelper#draft_history_sentence` so the page and the history list cannot compose the same
fact separately. The draft's own page is the only one of these on the pending-changes route: the list
there is scoped to the open statuses. `DraftApplier` writes the moment, the tally, and one `DraftChangeOutcome` per change from
a single `Result` inside its transaction; [ADR 0024](adr/0024-an-applies-outcome-is-stored-and-a-closed-draft-stays-inspectable.md)
owns that decision, and `docs/data_model.md` owns the columns.

**A closed draft is also reported by the universe's change history.** `HistoriesController` lists every
closed draft in one universe, grouped by the day it closed, and each change is the same
`drafts/_change` row the draft's own page draws — so a history list and a draft page cannot come to
disagree about what a change said. The day grouping lives in **one** partial, `histories/_day`, because
the per-person history under **Collaborators** is the same reading at a narrower scope; the date is the
draft's `closed_at` rather than a change's own `created_at`, which is when it was first remembered and
can be days before it became live. It asks for `admin`, like the review queue and not like the drafts
pages: it names every author who has closed a draft here, and that is the review queue's question rather
than the drafts pages' "may this person act on their own work". A **discarded** draft is listed, because
omitting it would answer "who changed this universe" with a list that silently drops the work somebody
threw away — nothing in the model marks those changes as never having existed, so the page reports the
empty tally that `draft_history_sentence` already prints. **Both** the changes and the draft's author are
preloaded: an association read in the view is one query per draft rather than one per author, and
`draft_changes_query_count_test.rb` is what holds that.

**A collaborator is an author with a closed draft, read from `drafts` and not from memberships.** A
member who has changed nothing has not collaborated, and a writer in a public universe is never a
member at all, so the membership table answers neither half. An open draft does not count either: it is
pending work, it belongs to **Pending changes**, and it has not changed the universe yet. A
**discarded** draft does count, because remembering a change here is collaborating here even when the
run never wrote it, and the list's copy says so rather than leaving the number to be guessed at. The
**Collaborators** page and its per-person page are the change history at a narrower scope, so they
reuse `histories/_day` and `drafts/_change` rather than composing a second list; the two are separate
pages rather than one filtered page because the sidebar figure has to count **people** and the list's
own figure has to count **changes**, and one page would have to be right about both in its chrome. The
per-person lookup is scoped through the universe's closed drafts, so "has not collaborated here" and
"does not exist" are one **404** rather than an empty page confirming that a user id is somebody's at
all. `Collaborators` is the query object behind both pages and its sidebar figure: two grouped counts
and one load of the names, never an author resolved per row.

**Both drafts pages carry the workflow in three steps.** `drafts/_workflow_guide` renders
`drafts.guide` on the list and on a draft, because those two pages are one place in this workflow: the
list is where an author finds out something is waiting, and the draft is where they decide about it. A
draft-based universe is the one place in this application where pressing **Save** does not change what
the universe holds, and every other sentence about that — the flash that says a change was
*remembered*, a row's badge, the two controls — is a consequence of one of the three steps rather than
an explanation of it, so an author arriving from that flash has three questions and a list of
remembered changes answers none of them. It is one partial and one set of keys so the two pages cannot
disagree, it is drawn from `content-surface` with no styling of its own so it reads as a sentence and
not as a control, and it is rendered only where `DraftPreview#available?` holds — in a `direct`
universe the steps would describe a workflow that does not happen. **The third step is the mode's**,
because it is the only one that differs: `drafts.guide.steps.apply` for a `wikipedia` universe,
`drafts.guide.steps.submit` for a `github` one. The first two steps are the same either way, and a
guide describing an apply in a universe whose page has no apply would describe a control that is not
there. The list says the same thing once above its rows, in `drafts.index.review_note` or
`drafts.index.apply_note`, because "which control will my rows carry" is the question an author has when
they arrive from a remembered-change flash — and it is a property of the universe, so one sentence above
the list rather than one per row. **One sentence under the steps says what the steps do not**:
`drafts.guide.one_draft`, which is that a draft is one line of work per author per universe ([ADR
0027](adr/0027-a-draft-is-one-line-of-work.md)) and that a second direction therefore means applying or
discarding what is waiting. The three steps answer "how does a change become live" and are silent on
"what if I want to start something else", and this is the page an author reads before deciding — the
flash that follows **Start editing** reports the same rule after they have already pressed it.

**The page has to be reachable.** The right utility sidebar's **Collaboration** group carries a
**Pending changes** entry with a panel of what is waiting above it, rendered only where a draft can
exist — a `direct` universe never opens one — and only for a signed-in reader, because a draft belongs
to a person. An editor who is told their change was remembered and cannot then find it has no way to
see it, apply it, or throw it away; which block that entry belongs to is in
[features/navigation.md](features/navigation.md). Neither the panel nor the entry's presence depends on
the reader having something pending: it is how a reader with nothing pending reaches the drafts list,
and a control that appears and disappears with a count is a control whose absence has to be explained.
That list is scoped to the open statuses, so it carries pending work only; a closed draft's history is
read on the draft's own page and on the universe's history page. **The panel's rows are read in one pass** through
`DraftChanges::Reader`, and capped by `DraftPreview::PANEL_LIMIT`: it is on every page, so its cost is
every page rather than one, and both bounds are needed — a bounded five rows resolved one at a time is
still five queries everywhere. The reading itself is in [Reading a draft's
changes](#reading-a-drafts-changes).

**A draft holding a change the applier cannot read says so on its own page.** `DraftIntegrity` answers
a prior question to the conflict detector's — can the applier read the row at all — and the two do not
overlap: a create naming a `record_type` outside the content registry, or a payload naming a value the
model has no writer for, is not a conflict because there is nothing to choose between. The applier still
raises on both ([ADR
0021](adr/0021-applying-a-draft-through-the-live-mutation-path.md) decided that, and the transaction is
what makes it safe), but a raise escaping a controller answers `404`, which reads as "this draft does not
exist" for a draft the reader is looking at. So `DraftIntegrity` is asked first, `apply` refuses with a
`422` that renders this page, and nothing is written: the draft stays open, its changes stay listed, and
**Discard** — the author's only way out of a change the universe cannot describe — is untouched. The
notice is `shared/_draft_damaged` and the keys are `drafts.damaged.*`, one partial and one set of words
for every surface that has to state it.

The check that decides which rows those are is **raise-equivalence, not unreadability in general**: an
update or a delete whose `record_type` is outside the registry is not flagged, because the detector
resolves the record first and reports `:missing` without raising, and refusing the whole run over a
change it would have skipped is a new refusal dressed as a clearer answer. A payload key is checked
against an unsaved instance rather than against `column_names`, because what a payload may name is
"something with a writer" — a tag id list and the two virtual photo fields have writers and no columns,
and a check against the columns would report ordinary remembered values as damage.

## The reviewer's page

A submission is somebody else's draft, so its pages are the drafts page read from the other side:
`/u/:universe_slug/review_requests` is the queue and `/u/:universe_slug/review_requests/:id` is one
submission, with `approve` and `reject` as two POSTs for the reason `apply` and `discard` are. **Every
action asks for `admin`** on the universe, through the `UniverseAuthorization` line memberships use
rather than the `index`/`show` → `read` rule. The queue names every author who has submitted something
and what they want done with it, so a plain writer is not a reader of it either. A reviewer reaches it
from the right sidebar's **Review requests** entry, which is offered on the same `admin` answer;
[features/navigation.md](features/navigation.md) owns that entry.

**An approval is the author's apply, in full, and it is shared rather than reimplemented.** `approve`
runs the same `DraftConflictDetector`, renders the same conflict rows (`drafts/_conflict`, one partial
for both callers), posts its answers back to itself, calls the same `DraftApplier`, and reports the run
with the same flash sentences. `AppliesDrafts` is where the three of those live, because each is a
question asked once and answered twice: what is in conflict, what the request answered (an answer is an
instruction to write over somebody else's record, so both the controller's filter and the applier's are
kept), and what the run did. Only the rendering differs — the reviewer's conflicts page has its own
header and posts to `approve` — because a resolution page that asked a reviewer different questions
would be two answers to one conflict.

**The decision and the run are one transaction, and a decision cannot be taken twice.** The applier
closes the draft inside its own transaction, so the request's approval has to land in the same one: an
approved request over a draft that was not applied claims a review that never happened and is
unreachable afterwards. Both actions therefore refuse a request that is already answered, with a
redirect to its own page and the reason, exactly as `DraftsController` refuses an applied draft — the
duplicate-write hazard is the same one.

**Both decisions carry notes, and only a rejection requires them.** The approval is a form rather than a
`button_to` because a reviewer's note is for the author and most approvals still have something to say —
"applied mine over Thursday's rename" is the sentence that explains a decision the author can otherwise
only discover happened. So the page carries two forms over the one column: an approval's note is
optional and is stored as `nil` when the box is empty, because an empty string would read back later as
something a reviewer said; a rejection's is required by `ReviewRequest` and its refusal re-renders the
page with the reason beside the field. The note is held apart from the record (`review_notes_field`)
because an approval is **reached twice** when a change has moved: the conflict page posts back to
`approve` and carries the note with it, so the reviewer writes the sentence once.

**Two things are deliberately not rules.** An author who is also the universe owner **may approve their
own submission** — it grants them nothing they could not do by applying the draft directly, and a rule
against it would only stop the owner from being told a draft was ready. And these pages are **not gated
to `github` mode**: a submission can only exist where one was made, and the mode is enforced on the one
control that can make one — [`DraftsController#submit`](#the-drafts-page), which refuses every other
mode, while the reviewer's pages stay reachable in any mode.

**The author's message is printed above the changes, labelled as their words.** It is the context for
reading the diffs, and a reviewer has to be able to see where the author's sentence ends and the
application's reading begins, because everything below that block is the latter. It is optional by
design, so the block is absent rather than empty. **A withdrawn submission says what happened** instead
of naming a reviewer who never saw it, and offers neither decision — it is history, and
[`ReviewRequest#withdraw!`](#the-drafts-page) is what makes it so.

**Both decisions notify the author** — see [Notifications](#notifications), which owns what is
written and who it reaches. The notice for an approval is written inside the decision's own
transaction, which is also why it is here rather than on `ReviewRequest`: an approval is an apply, so
the decision cannot commit without the run, and a decision that committed without its notice would
leave an author waiting for a verdict that had already been given.

**A rejection is the one reversible decision, because it hands the draft back.**
`ReviewRequest#reject!` moves the request and the draft's status in one transaction (`submit!`'s reason
read backwards), so a rejection cannot leave a draft nobody can edit or a queue entry the author still
owns. The draft returns to `draft`, not to a closed status: a rejection is somebody else's decision
about the author's work, and the changes are still theirs to edit and submit again. A refused rejection —
notes are required, and `ReviewRequest` says why — restores the stored state on the instance so the page
still offers the controls, and re-renders with the reason beside the field rather than redirecting, which
is the rule every other form here follows.

**Nothing about the draft's changes is read to reject one.** That is why a submission holding a change
the applier cannot read is still rejectable, and why `reject` renders `show`: refusing it must not be a
reviewer's only option, or one damaged row would block the queue behind the author's problem to fix.

## Notifications

One person is told what happened to them while they were elsewhere, and the questions that takes are
the model, the writes, and the bell. [ADR 0025](adr/0025-a-notification-is-a-stored-sentence.md) is
why this is a stored sentence with a recipient rule per kind rather than a pointer, and the reasoning
behind the rules below lives there.

**What a notification is: a stored sentence, not a pointer.** `Notification`'s `payload` carries the
universe's slug and name, whatever it is about, the other person's name, and a reviewer's note where
there is one. It has **no foreign key to any of them**, and that is the whole design rather than an
omission: the submission it names is destroyed with its draft and with its universe, and a thread is
destroyed with its record and with its universe, so a row that resolved any of that to print itself
would raise on a page that has to keep working. The trade is names stored twice, validated by
nothing, deliberately. The column is `kind` rather than the `type` the plan named, because `type` is
Active Record's single-table-inheritance discriminator and a row whose type was `"review_submitted"`
would be looked up as a class name — the same answer ADR 0019 gave for `draft_changes.payload`.
`created_at` with no `updated_at`: nothing reports when a reader opened their bell.

**Who is told, and who is not.** The three kinds have three different recipient rules, and each is
the answer to a different question rather than a variation on one.

- A **submission** goes to the universe's administrators (`Universe#administrators`: the owner plus
  the `admin` members — the owner is included explicitly because `UniverseMembership` refuses to
  record one) and to nobody else, because `admin` access is the whole of who may read a reviewer's
  queue. The **author is not told about their own submission**: they pressed the control that caused
  it and the page they land on already says it, so an author who is also their universe's only
  administrator gets nothing — which is correct rather than unfortunate, since there is nobody else
  who could review the draft.
- A **decision** goes to the author alone, because the decision is addressed to them.
- A **reply** goes to everybody else who has posted in that thread and can still read the universe
  (`Notification.discussion_replied!`). The recipients are the thread's **other authors** rather than
  the universe's people, because a thread is the one place here where two people have chosen to talk
  to each other about one record: a member who has never posted is not in the conversation and is not
  told about it, and the author of the reply is not told about their own message. The recipients are
  read from the thread's stored messages rather than from a participants column, because a thread has
  a history rather than a membership — so somebody who posted three times is one recipient, and one
  row each, as `notify` is for every kind. A participant whose membership was **removed after they
  posted** is dropped, because telling a reader that a reply arrived in a universe they can no longer
  open discloses that they said something, to somebody who may not know they ever did.

Every notice is written **inside the transaction that made the event** — `Draft#submit!`,
`ReviewRequest#reject!`, the approval's own transaction in `ReviewRequestsController`, and
`DiscussionMessage#post!` — because a decision that committed without its notice leaves an author
waiting for a verdict that has already been given, and a message that landed while its notice failed
to write leaves the thread looking like it did not answer. An approval stopped by a conflict announces
nothing, because the decision was never taken. `post!` is the one of these that answers `true`/`false`
rather than raising, because an empty composer is an ordinary form error the thread re-renders beside
the field rather than a crash; the transaction still rolls back, so a refused reply writes no message
and no notice.

**A reply is the one kind whose target is universe-scoped rather than one of this application's own
pages.** `NotificationsHelper#notification_target` links it at
`universe_discussion_path(universe_slug:, id:)`, because `DiscussionsController#show` resolves the
thread through `Current.universe` and its path therefore carries the universe's slug — which is the
same slug the payload stores, and why the notice still follows a reader who is standing in a
different universe. It is also the one target whose reader may open it: `show` is guest-readable, so
a recipient who is a plain member, a read-only member, or the universe's owner lands on the thread
rather than on a refusal, which is not true of the reviewer's page. The record's **name** travels in
the payload and its class does not: the sentence says which conversation this is, because "somebody
replied" in a bell opened from another universe is a sentence with nothing in it, and the class would
add nothing printable. The name is read through `RecordTarget` rather than through the thread's own
`record` association, for `Discussion`'s reason — a stored `record_type` must never be constantized —
and a soft-deleted record therefore leaves the stored name in place where a join would resolve
nothing, with `notifications.a_record` as the fallback for a row that never had one.

**The two writes, and why they are POSTs.** `POST /notifications/:id/read` and `POST
/notifications/read_all`, both on the page rather than in the dropdown: a reader who has read three of
five entries has not read the other two, and a dropdown that marked a row read as it was rendered
would answer that on the reader's behalf. `read_all` is a `POST` because a GET that marked a row read
would let a link, a prefetch, or a crawler silence a bell on the reader's behalf.
`test/controllers/csrf_mutation_test.rb` covers both refusals.

**The bell is a glance; the page is the list.** `layouts/_notifications` prints at most
`Notification::PANEL_LIMIT` entries and links to `/notifications`, which holds the rest, the two
controls, and the count. The dropdown's figure is the **unread** count and is **uncached**, for
`pending_review_request_count`'s reason with one difference: that figure moves because *this* request
just decided a submission, while this one moves because somebody else did something in another
browser, which nothing here can expire on — so a `MenuCountCache` entry would promise a stale bell
for up to its TTL. It is one `COUNT` over `[user_id, read]`, asked only for a signed-in reader. The
**bell stays when everything is read**: a reader who has read everything still has a list, and hiding
the bell would hide the way into it. The uncached figure is also what makes a live refresh of it worth
having: writing a row publishes to that reader's own stream, which is how the badge moves under a
reader who is on a different page — see [Real-time updates](#real-time-updates).

**A notification is not an authorization.** Each kind links at the surface its own reader may open: a
submission notice leads to the reviewer's page, because the reviewer's page is where the approval and
rejection controls are; a decision notice leads to the author's own draft page, which carries the
submission's status and the reviewer's notes (`drafts/_submission_status`), because the reviewer's page
would answer **404** to somebody with no admin access; a reply notice leads to the thread. All three
carry the universe's slug in their own payload rather than reading the one the reader is standing in,
so the navbar can show a notice about a universe the reader is not currently in; a universe renamed
since the notice was written makes its link a 404, which is the accepted price of a row that still
renders. A row with nothing to link at prints its sentence and no link, so one row this application
did not write cannot take the page down with it — and because the three kinds name a different id in
the payload, `notification_target` asks for its own and a half-filled payload is no link rather than a
link to `/u//discussions/`.

## Real-time updates

When something another reader did changes what this page would show, this page says so without being
asked. `LiveUpdates` owns what is published and to whom; `live_update_controller.js` owns what the
browser does about it; `config/cable.yml` owns which adapter delivers it.
[ADR 0026](adr/0026-a-live-update-is-a-refresh-and-never-a-page.md) records why a broadcast is a
refresh rather than rendered content, and why the client decides whether to apply it.

**A live update is a signal, never a page.** Every broadcast is a Turbo Stream `refresh` carrying one
`data-live-update` marker, and nothing else. The alternative — broadcasting the rendered rows, the
message, the count — would be rendered by `ApplicationController.render` outside any request: with no
session, no `Current`, no locale of the reader receiving it, and no authorization answer for them. A
Spanish reader would be sent an English sentence, and a member whose access had since been withdrawn
would be shown a universe they can no longer open. A refresh sends nothing but *look again*: the
reader's own browser re-requests the page through their own session, in their own language, and the page
answers for them. That is the same boundary [ADR 0016](adr/0016-internationalization-and-browser-locale.md)
draws for the client-side strings, and the same reason `Notification` stores a sentence rather than a
pointer.

**Three streams, because there are three audiences.** A **universe** stream says *the records here
changed* to everyone with that universe open — which is what an applied draft means, since a Character
that did not exist a second ago is now stored and every list of the universe is stale. A **discussion**
stream says *this thread has another message* to the readers already looking at it: a thread is a
conversation between the people who posted in it, not a universe-wide event. A **reader** stream says
*your bell has something new* to one person, and it is the delivery for every notification this
application writes.

**The review workflow's three events are announced through `Notification`, not by three more
broadcasts.** A submission goes to the universe's administrators, a decision to the author, and a reply
to the thread's other authors — and [Notifications](#notifications) already owns those recipient rules
for the stored rows. A second copy of them here would be free to disagree with the rows.

**A broadcast is published after the transaction that caused it commits**, which is why it hangs off an
`after_commit` on the record rather than off the write path: `Draft` when it becomes `applied`,
`DiscussionMessage` when it is created, `Notification` when it is written. A refresh published inside a
transaction invites the reader to re-read a universe that has not been written yet, and waiting for the
outermost commit is also what makes a reviewer's approval correct — that write is wrapped in the
decision's own transaction above the applier's. A rolled-back apply and a refused reply therefore
announce nothing.

**The reader's own browser is not told.** `turbo_stream_refresh_tag` carries `request-id`, and the
client controller leaves any broadcast carrying one to Turbo's own echo check: Turbo drops a refresh
whose request id the page has just made itself, which is how the person who pressed **Apply changes**
is not reloaded underneath the navigation they are already doing.

**The stream name is signed, and that is the authorization.** `turbo_stream_from` signs what it
renders; `Turbo::StreamsChannel` refuses a subscription whose signature does not verify, so a reader
cannot name a stream their own pages never named. The subscriptions are in `layouts/_live_updates`,
rendered only where the request has already authorized that reader for that universe — which is why a
**guest has no subscription at all**, for `ApplicationCable::Connection`'s reason: a websocket with no
session is refused, so the element would open a connection rejected on arrival. Guests read this
application by loading pages, which is what they did before this existed.

**A refresh is applied only when the page holds nothing unsent.** This application has unsent work in a
composer, in a reviewer's notes, in a submission message, and in a modal editor's JSON payload, and a
refresh throws all of it away without asking. `live_update_controller.js` cancels Turbo's own handling
at `turbo:before-stream-render` and decides for itself, by one question: *does this page hold anything
the reader typed that the server did not send?* A field is unsent when its value differs from the value
the server rendered into it (`defaultValue`), and an open Bootstrap modal counts for the same reason a
dirty field does. When the answer is no, the refresh is applied; when it is yes, the refresh is **held**
and the floating notice in the same partial appears, so the reader decides when their work is worth
losing. `range` and `color` inputs are excluded from the question — the photo editor's zoom slider
arrives with no value and its controller writes `100` into it, so asking would report every list
workspace as unsent and hold every update in the application.

## The editing session

The universe page carries a **Start editing** / **Stop editing** control, and the reader's editing
session is a **session value, not a record** (`DraftEditingSession`): one boolean per universe in
`session[:draft_editing_universe_ids]`, keyed the way `current_story_ids` is, so a visit spanning two
universes does not make the second inherit the first's session. `Authentication#clear_session_context`
drops it at every session boundary, so one account's claim cannot cross accounts on a shared browser; a
draft outlives the session, and the sidebar entry is how it is reached afterwards.

**It is a claim, not a gate.** No mutation path reads the flag. In a draft-based universe every mutation
is remembered whether the reader pressed the control or not ([ADR
0020](adr/0020-remembering-mutations-instead-of-writing-them.md)), and the control is deliberately not a
second answer to that question — a reader who forgot to press it would otherwise write straight through
a universe whose mode exists to stop exactly that ([ADR
0022](adr/0022-an-editing-session-claims-the-browser-and-one-draft-stays-open.md)). What entering a
session does is **open the draft before the first change is made** (`Draft.open_for!`, which resumes an
existing draft rather than replacing it), and what the flag gives the page is a count: the pending count
is a link into the drafts page, because a number is only interesting as a way into the changes it is
counting. That count is `draft_preview.count`, which the universe page's button and the sidebar's panel
both read, because it is one fact about one draft read once per request; the sentence for it is
`drafts.pending.count`, and two keys for one fact is how a fact goes stale in one place.

The control is rendered where the server accepts it: a draft-based universe, a signed-in reader, and
`write` access — the same three conditions `draft_editing_available?` states and the two actions enforce
through the shared universe policy. Both actions need `write`, so an author whose access is revoked
mid-session loses the control with the access rather than keeping a mode whose changes could not be
remembered. **Stopping is not discarding**: the draft stays open and every remembered change stays in it,
and the flash states how much is still waiting, so a release is never read as a loss.

Both actions are a singleton `resource` (`POST`/`DELETE /u/:universe_slug/editing`), the same shape
`resource :session` uses, and there is no `show`: the universe page renders the current state, and a GET
never begins an editing session. A toggle posted from a stale page in a universe that has since become
`direct` is answered with the universe and `drafts.flash.not_draft_based` rather than silently accepted.

**One open draft per author per universe is a partial unique index** on `[user_id, universe_id]` over the
open statuses, so two tabs cannot each open one. History is outside the index, which is what lets a
second editing session have a row of its own. `Draft.open_or_start_for!` resolves the race the index leaves by
re-reading the winner's row rather than raising, and re-raises if that row is gone — the index's status
list is compared against `Draft::OPEN_STATUSES` by `test/models/draft_test.rb` so the two cannot drift.
`open_for!` is that method without the answer attached, so the race has one implementation whatever a
caller asks of it.

**A start says which of the two things it did.** A draft is **one line of work** per author per universe
([ADR 0027](adr/0027-a-draft-is-one-line-of-work.md)), so entering an editing session either opens a draft
or puts the reader back into the one they already had open here — and those are different sentences. The
flash is `drafts.flash.editing_started` when this author had no open draft and
`drafts.flash.editing_resumed`, with how many remembered changes are waiting on it, when they did. The
count is the one the stop's own flash names, because it is the same question asked at the other end of
the same session, and it is read off the draft `start!` returned rather than counted again. `start!`
returns the `Draft::Opening` for that reason: the caller does not ask whether a draft existed a moment
earlier and risk an answer about a different request. A second line of work is bought by **closing** the
first — apply, discard, or (in a `github` universe) submit it and let a reviewer close it — and stopping
is not one of them, because stopping releases the browser's claim and leaves the draft open.

## Pending changes in a list

In a universe that remembers changes, a list shows two things: what is stored, and what the reader's
own open draft would do to it. Both come from `DraftPreview`, built once per request by
`DraftsHelper#draft_preview` and answered three ways — what is waiting, what is waiting **on this
record**, and what new records the draft would have created.

**The draft is the query; the content query is untouched.** A remembered create names no record
([ADR 0019](adr/0019-collaboration-foundations.md)), so there is no row a content query could return and
no join that would produce one. A list therefore keeps its own ordering, `includes`, and count, and the
preview is a parallel source beside it — see [ADR
0023](adr/0023-pending-changes-are-read-from-the-draft-and-drawn-as-badges.md). Every list workspace
carries it: the six universe-level flat lists (Characters, Locations, Items, Events, Relations,
Ownerships), the Sections tree, the eight taxonomy trees, and the Scenes list.

**A pending record is an unsaved instance of the model**, built from the payload sliced to
`model.column_names`, so a pending row renders through the same `record_label` ladder a live row uses
and no model gains a second way of naming itself — with the one exception below, for a record the
ladder has nothing to name. What a pending row cannot have is a **Details link, an editor, a delete
menu, or a position** — all four need an id — so `shared/_row_actions` and `shared/_taxonomy_node` are
never handed one.

**A pending row shows the tags and the photo the author gave it, and reads the two by different
routes.** Neither is a column, so the slice above does not carry them, and dropping both is what made
a remembered create show *less* than had been submitted: a character the author had just tagged
*Protagonist* and given a portrait appeared to have lost both. The two are read differently because
they are different things. The **tag list is assigned onto the record's own association**, from records
rather than ids, so `entity_tag_badge` reads a pending row through the same ladder it reads a live row
through — one rendering path, and no second one for pending rows. Assigning the resolved records is
also what makes it free: an id writer leaves the association unloaded and every pending row in a list
would ask the tag table for itself when its badges rendered, which is finding 66's per-row read back
on a surface that had stopped paying it; the ids come from `DraftChanges::Reader`, which resolves a
whole draft's payloads in one query per tag class. The **photo cannot be assigned**, because
`HasPhoto#photo_data=` also marks the value as *submitted*, and that flag turns on decoding the data
URL, re-encoding it to a square, and writing a `Photo` row — an image pipeline for a record that is
never saved. It is held beside the record instead and read through
`DraftsHelper#draft_pending_photo`, which **gates it on `PhotoProcessing::DATA_URL`** so that a
payload naming something that is not a submitted image cannot become an `img src`. The gate is
deliberately the cheap half: whether the bytes decode is the applier's answer to give, and a row that
draws a crop the apply later refuses is the truthful one, because the change is still remembered and
nothing about it has been written. This is the one surface a photo appears on outside a details page —
a live list row has nowhere to put one, since `record_photo_url` needs a `Photo` row and a pending
record has no id for it to hang from.

**A pending row with nothing to be called by is titled by the type it would create.** A remembered
create is not validated when it is remembered ([ADR
0020](adr/0020-remembering-mutations-instead-of-writing-them.md)), so a pending record can be one the
universe would refuse to write — and one with nothing to name it by has no label to print: an Event
falls through `display_label` to a phrase about an id it does not have, and a nameless Character has
a blank label, so the row would carry a badge with no subject or with a subject that reads like a
stored record. `DraftsHelper#draft_pending_record_label` answers with the type in that case, which is
the sentence `drafts.show.new_record` already gives that change on a draft's page and in the sidebar
panel. Whether the record can name itself is the **model's** question, so `Event` publishes
`#identifiable?` (the same set `#display_label` reads and `#must_be_identifiable` refuses to save
without) rather than the view comparing a rendered label against a translated fallback. Nothing is
validated and no row is withheld: whether the applier will accept a remembered create is not knowable
before the apply — an outcome is recorded when the apply runs, not predicted before it
([ADR 0024](adr/0024-an-applies-outcome-is-stored-and-a-closed-draft-stays-inspectable.md)) — so the row
says what the change would create and leaves the decision to the apply, where the model's own validations
are authoritative.

**A row is never rewritten to match its badge.** A pending **edit** shows the values that are stored
today and a pending **deletion** shows the record with its links and menu, because none of that has
stopped being true; the badge is the only new thing on the row. The three states are
`drafts.pending.states`, and a **deletion wins an edit** on the same record rather than badging one
row twice.

### What a badge says beyond its state

The badge **word** never changes and never grows: `Pending edit` is still `Pending edit`. What a
badge may add is a **tooltip**, and the rule is one sentence — **`DraftsHelper#draft_pending_title`
is the only reading of it, and every badge goes through it**, because the question is asked in every
list workspace, on a tag's list of tagged records, and on all eighteen details pages, and a badge is
drawn on every row of every page of the universe.

For **more than one** remembered change on a stored record the tooltip adds the **fields an edit
would write** and **how many changes are waiting**. It names **fields, never values**, because the row
underneath still shows the stored ones and printing both beside each other would leave a reader
guessing which is the universe; the names go through the same `draft_change_label` derivation the
draft's page uses, so a badge says "Character tags" where the draft's page does.

Four answers are deliberate rather than incidental:

- **A single remembered change adds nothing.** One edit is already fully described by the state
  sentence, so a count of one repeats it and one field name would be a sentence about the most
  ordinary badge on the page. This is the case the state sentence already covers.
- **A remembered delete names no field, whatever its count.** A delete carries no payload, so there
  is nothing the draft would write; the count is still true and is still said.
- **A remembered create names no field either.** A pending create row already renders every value the
  author submitted, so the fields would list what is on the row directly above the badge.
- **The field list is bounded at `DraftsHelper::FIELD_LIMIT`** and counts the overflow, for the reason
  `DraftPreview::PANEL_LIMIT` bounds the panel rather than a reason about taste. Bounding the list
  does not make it a partial answer.

The fields come out of `DraftPreview::Pending`, which carries the state, the count, and the union of
the payload keys in the order the author first submitted them — **deduplicated by key and by name**,
because two remembered edits to one column are one field and the two photo writers share one label.
They are **not** filtered to what the model can answer: a key the payload names and the model does not
have is still something the draft would try to write, and the applier is what refuses it.

**This costs no query.** `DraftPreview` builds the state, the count, and the keys in the **same single
pass** over `draft.draft_changes`, and those rows are already loaded with their payloads, so naming a
badge's fields is arithmetic over data the request has. `test/controllers/draft_changes_query_count_test.rb`
holds that as a difference between one remembered edit and six.

**Pending rows are appended after the real rows**, in the order they were remembered, never sorted
into the list: a record with no id has no place in a sequence the controller computed from real rows,
and re-sorting would mean re-deriving each controller's ordering in Ruby. Two places refuse them
outright, for the same reason — a record that does not exist cannot answer a question about one that
does. A **filtered** Scenes list stays filtered, and a remembered Scene that names a `section_id` is
not listed among the ungrouped ones.

**A story-scoped workspace lists only the creates that name its own story.** A draft belongs to a
universe, not to a story, so one author's draft can hold a remembered Scene under every story in it —
and a Scenes list has to answer "what this list would hold". `DraftPreview#creates_for` takes a
`within:` for exactly this, and the caller passes `story:` from `DraftsHelper#draft_pending_creates_for`;
it is a keyword rather than a second method so a caller cannot quietly ask the unscoped question from
a page that has a story of its own. The comparison is on the record's own `story_id` — the same column
`DraftChange#scope_attribute` names and `DraftMutation` stored, so there is no second derivation of
"where does this record go". A create whose payload names no story is **excluded rather than shown**,
because a Scene with no story is one the applier cannot place.

Three kinds of workspace pass it, and **the other kinds must not**. The Scenes list, the Scenes
grouping partial, the Sections tree, and the two story-scoped tag pages are inside a story. The six
universe-level flat lists and the seven universe-level taxonomies are not, and omitting the keyword is
correct there rather than an oversight: **a universe-scoped model's scope column is `universe_id`,
which no story narrows**, so every pending character a draft remembers belongs on the Characters list
whatever story that list is reached from.

**A pending row says nothing about where it would land, and that is deliberate.** It has no id, so it
has no position and no parent, and the applier — not the reader — decides both. The two questions the
row *can* answer are answered instead: the drafts page prints the **story or scene a create would be
written under**, resolved through `DraftChanges::Reader` once per owner class (see
[Reading a draft's changes](#reading-a-drafts-changes)), and the list workspaces above narrow so the
page a row appears on is itself the answer to which story it belongs to. What remains unsaid is the
ordering, which is the applier's and could not be printed truthfully before it runs.

**A list whose only content is a pending create does not say it is empty.** The empty-state guard on
every list reads `@records.any? || pending.any?`, and `shared/_taxonomy_tree` does the same for the
tree, because telling a writer they have no characters while a row with a name sits under the message
is two answers to one question. **That guard reads the same narrowed collection the rows do**, so a
story with no scenes of its own says so even when a sibling story has a remembered scene waiting: the
row would be the wrong one, and showing it would be two answers to one question.

In a taxonomy tree the pending row is **`.taxonomy-pending`, never `.taxonomy-node`**: the tree
controller counts `.taxonomy-node` children to place separators and compute positions, so a row in that
list would be draggable and renameable before it exists. `restoreEmptyState` checks for it, so the
client does not put the empty state back on a tree the server rendered a pending row into.

### The three surfaces that are not list workspaces

The badges live in the list workspaces and nowhere else, and a reader reasonably looks in three other
places. Each was a separate question, and each is answered rather than left to be discovered.

**A record's own details page carries the badge**, read by `shared/_record_details` rather than passed
in, because "does this page's record have remembered work on it" is the same question on all eighteen
models and a caller that had to remember to ask would be a caller that forgets. The alternative — that
"Details" is deliberately a clean record of what is stored — was rejected for the reason the badge
exists at all: the badge makes no claim about the values. The page still shows what is stored, exactly
as **a row is never rewritten to match its badge** requires, so the reader finds the same page plus one
fact they would otherwise have to remember. A remembered **create** has no page to carry the badge,
because there is nothing to link to.

**A tag's list of the records carrying it lists pending rows too**, which follows from a pending row
carrying its tags: the tag page is a list workspace like any other, and it is where a reader asks which
records carry a tag. `DraftsHelper#draft_pending_records_for_tag` reads the element class off the tag's
own association rather than a list of taxonomies, so it cannot disagree with `tagged_records` about
which records a taxonomy is for, and it takes the **descendants toggle** as an argument so a pending
row carrying a child tag appears under the parent exactly when a stored one carrying it would. A
**grouping tag** asks per child tag, so a pending row is filed under the one tag it carries rather than
under the parent or under all of them. `shared/_detail_section` therefore reads a `pending_count`
separately from its `count`: the badge stays a fact about stored records, while the section refuses to
say it is empty when a pending row is the only thing in it.

**The global search dropdown is left clean, deliberately.** It indexes stored documents, and a
remembered create has none, so a pending row there would be a result with nothing to open. See
[`features/search.md`](features/search.md#a-search-does-not-answer-with-pending-records) — the
decision is recorded on the surface it belongs to rather than left as an omission here.

## Reading a draft's changes

A draft's changes are read through **`DraftChanges::Reader`**, which resolves a whole collection in a
fixed number of queries: one per record class the changes name, one per tag class their payloads
carry, and one per **owner class** the scope columns they carry name. Every other list in the
application preloads through a grouped query, and these pages are the contract for the ones that read
a draft — a draft's own page, a reviewer's page, the conflict page, and the sidebar's pending panel,
which is on **every page of the universe**.

**The collection is passed, not inferred.** A `DraftChange` does not know its siblings, so a surface
renders `drafts/_change` with `collection:` **and** passes the same array as a `changes` local; a
partial rendered with one change falls back to a reader of one, and the per-row read is back for that
row alone. The array has to be materialized once — an association proxy is a new object per call, and
the reader is memoized by the collection's identity, so a proxy would be a new reader per row.

**Records come through the same gate as everywhere else.** The reader asks `RecordTarget.model_for`
rather than constantizing a stored `record_type`, a soft-deleted record stays invisible because the
class's default scope applies to `where` exactly as it did to `find_by`, and a **create resolves no
record without a query** — it names none, and asking was a `WHERE id IS NULL` that could not answer.

**A tag list keeps the author's order.** Ids are mapped back onto the submitted payload order rather
than printed as the query returned them, and an id that no longer resolves is dropped, because the
change is the author's statement about the ids that are still there.

**A scope column resolves to the record it names, keyed by the change and by the owner's class.**
`Entry#scope` is the story or scene a change would be written under — the answer the drafts page prints
instead of a bare id. Three rules make it general rather than a story special case:

- **The key is the change, not the record type.** A draft routinely holds several changes of one type
  under different stories, which is the case the drafts page exists to let a reader compare. Keyed by
  type, every one of them would read the last answer and the page would name one story for all of
  them. The records are still fetched in one query per owner class; only the keying is per change.
- **The class is the owner's, not the changed type.** A `Scene`'s `story_id` names a `Story` and a
  `SceneElement`'s `scene_id` names a `Scene`, so an answer keyed by the changed type would look a
  scene up among the scene elements. The owner class is read from
  `UniverseScopeResolver.owner_association_for`, the same derivation `DraftChange#scope_attribute`
  already made.
- **A `universe_id` scope resolves nothing.** The page is already inside the universe that column
  names, so loading it would cost a query on every draft page to print what the reader can see from
  the address bar. This is the one case where the drafts page prints no scope row at all; every
  narrower owner is named, and one that no longer resolves says so in the shared blank cell rather
  than printing a number that resolves to nothing.

**Labels stay in the view layer.** The reader holds records; `record_label` turns them into words. A
service that re-derived the ladder would be the second copy ADR 0023 refused to write.

**The outcomes are preloaded onto the collection the view iterates.** `includes` returns a new
relation, so a preload whose value is discarded attaches to instances nobody renders and every row
resolves its own outcome. Both controllers that draw these rows resolve the collection in a
`before_action`, because each of them has more than one action that renders the same template.

**The conflict page's "theirs" half is one read per row, and that is the floor.** It reads the live
record's own tag list, which is in no remembered payload and so has nothing preloaded for it; it reads
the association it has just loaded rather than re-fetching the ids, and it cannot go lower — the HABTM
associations carry an instance-dependent scope and cannot be eager loaded. Only the "yours" half reads a
payload, and that half is batched.

`test/controllers/draft_changes_query_count_test.rb` holds the page-level surfaces, including the
one that names a scope, and `test/services/draft_changes/reader_test.rb` holds the answers — that a
batched read returns the same set the per-row read did, refusal by refusal.

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
  `details_count_label` trio that renders the row's Details link and count pill. It also requires a
  `hierarchy` local — a `HierarchyIndex` over the page's own load — because the recursive node partial
  descends through it rather than through `node.children`. `_row_actions`
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
- `live_update_controller.js` — decides what happens when another reader's write arrives as a
  Turbo Stream refresh: it cancels Turbo's own handling and applies the refresh only when the page holds
  nothing unsent, otherwise it reveals the floating notice. It is described in
  [Real-time updates](#real-time-updates), including the `TYPED_TYPES` set it asks its unsent-work
  question of and why `range` inputs are not in it.

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
