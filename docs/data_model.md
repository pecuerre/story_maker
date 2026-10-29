# Data Model

Everything about the schema: tables, ownership/scoping rules, tag taxonomy matrix, validations
and the slug system. Verified against `db/schema.rb` (SQLite, schema version
`2026_10_29_140000`) and the models in `app/models/`.

## Ownership graph

```
User (owner)
 └── Universe  (1..n stories; everything below is scoped to exactly one universe)
      ├── UniverseMembership ──> User (read/write/admin)
      ├── Photo (Active Storage attachment, one 300x300 square, optional on every record below)
       ├── Story ── Section ──> Section's parent Section (tree)
       │   ├── Plot ── HABTM Scene (story-owned narrative through-lines)
      │   │                     └── HABTM SectionTag ──┐
      │   ├── SceneTag (tree, story-scoped) ── HABTM SceneTag assignment
      │   └── Scene (contiguous narrative position) ──> Section
       │       ├── SceneEvent (ordered Event link, optional free-text role) ──> Event
       │       ├── SceneElement (contiguous flat position) ── HABTM Character (block speakers)
       │       │   └── SceneDialogueTurn (contiguous flat position) ──> Character (line speaker)
       │       ├── SceneCharacter (explicit presence, optional free-text role) ──> Character
       │       ├── SceneItem (explicit presence, optional free-text role) ─────> Item
       │       └── SceneLocation (explicit presence, optional free-text role) > Location
      ├── Discussion (one per record, polymorphic) ──> DiscussionMessage ──> User
       ├── Character ──> parent Character   ── HABTM CharacterTag (tree), HABTM Faction
       │   └── CharacterKnowledge (when / what learned / source Character / plan change)
       ├── Faction    ── HABTM FactionTag (tree)
       │   └── FactionRelationship (directed faction → faction)
       ├── Location  ──> parent Location    ── HABTM LocationTag  (tree)
       ├── Route (from Location → to Location, measured path)
      ├── CanonRule (universe-wide, or owned by one Story)
      ├── Item      ──> parent Item        ── HABTM ItemTag      (tree)
      ├── Event     ──> parent Event, before/after/simultaneous Event ── HABTM EventTag (tree, optional)
      ├── Relation  (character1 × character2) ── HABTM RelationTag (tree)
      ├── Ownership (character × item, dated) ── HABTM OwnershipTag (tree)
      └── (Session belongs to User, unrelated to universes)
```

**The one rule to remember:** world building (characters, factions and faction relationships, locations, routes, canon rules, items, events, relations,
ownerships **and every `_tag` model except SectionTag and SceneTag**) belongs to the **universe** and
is shared by all of its stories. Only **sections** (the script: books → chapters → scenes …),
**scenes**, and their **section/scene tags** (chapter/book/episode or scene-beat labels) belong to a
**story** — each story owns its own structure taxonomy and Plot arcs. A canon rule is the one
world-building record that may name a story, which narrows who follows it without moving it out of
the universe's list. A Scene's own components (Elements and
presence links) belong to one **Scene**; a Dialogue turn is nested under its Element. They resolve
their Universe through those owners.

### Universe access

Access is a property of the universe, not of an individual story or content record:

- A **public** universe is readable by guests and writable by every signed-in user. A membership
  can grant admin access; a read/write membership does not reduce the public contributor baseline.
- A **private** universe is readable by its owner and members with `read`, `write`, or `admin`
  access. `read` can view only, `write` can view and change content, and `admin` can additionally
  change universe settings and manage memberships.
- The owner is always an admin. A user's access to a universe applies to every story and every
  universe- or story-scoped component beneath it.

`Universe#access_level_for`, `readable_by?`, `writable_by?`, and `administrable_by?` are the
application-level policy methods used by both the `Ability` class and the request authorization
concern. The membership table only records explicit private-universe access and optional public
admin grants; it is not a replacement for the public-universe baseline.

## Soft delete

Every content table that has a user-facing delete action carries a nullable `deleted_at` datetime
(`NULL` means live). A delete marks the column instead of removing the row, so the data survives and
can be restored. The `SoftDeletable` concern (`app/models/concerns/soft_deletable.rb`) provides:

- a `default_scope` that hides soft-deleted records from every ordinary query;
- `soft_delete` / `restore` to mark and unmark a record, each in its own transaction;
- `deleted?`, and the `with_deleted` / `only_deleted` scopes to opt back in;
- a `soft_deletes :assoc` declaration for the associations that cascade;
- the `soft_delete` and `restore` **model callbacks**, which run inside that transaction
  immediately after the write that set or cleared `deleted_at`. `after_destroy` never fires
  for a soft delete, because nothing is destroyed, so a model that has to react to *this*
  application's delete — `OrderedSequence` closing the gap its own deletion left in an
  ordered collection — needs these and not only `after_destroy`. A callback that raises
  rolls the delete back rather than leaving a deleted record beside a sequence nothing
  repaired.

Soft-deleting a parent cascades to its declared children (a Universe soft-deletes its stories,
characters, factions, faction relationships, tags, routes, and memberships; a Faction soft-deletes
relationships on either endpoint; a Story soft-deletes its sections, plots, and scenes; a Scene
soft-deletes its elements and presence links; a SceneElement soft-deletes its dialogue turns; a
Character soft-deletes its relations, ownerships, presence links, and knowledge records; a Location soft-deletes Routes
using it as either endpoint). Plot-to-Scene join rows are
retained when a Plot is soft-deleted, so restoring it restores its assignments. Dialogue-turn speaker rows
are retained when a Character is soft-deleted, like the Element-level speaker join, so restoring
the Character restores its attributed lines. Two associations are cleared rather than cascaded,
matching the existing hard-delete contract: a Section's scenes are ungrouped (`section_id` nullified)
and an Event's temporal references are cleared, so a referrer that was only identifiable through the deleted Event
keeps its row and reports the missing identifier the next time it is saved.

The unique indexes that would otherwise block re-creating a record with the same key after a soft
delete are partial (`WHERE deleted_at IS NULL`): `universes.slug`, `stories.[universe_id, slug]`,
`plots.[story_id, name]`, `plots.[story_id, slug]`, `canon_rules.[universe_id, slug]`,
`universe_memberships.[universe_id, user_id]`, and the `scene_characters` / `scene_items` /
`scene_locations` / `scene_events` link pairs. The matching model validations carry the same condition.

`users` and `sessions` are not soft-deletable: they have no user-facing delete action, and a
session is an authentication token rather than content.

A permanent delete is a different operation: the owner of a Universe may purge it and every
universe-owned row, including soft-deleted ones. The authorization and the full contract are in
[features/universe_deletion.md](features/universe_deletion.md); this section owns only what a soft
delete means.

## Photos

Schema only. The photo **contract** — the optional writers, the same-universe rule, the server-side
authority on the stored file, and the one control that serves all three page patterns — is in
[features/photos.md](features/photos.md).

A record may carry one photo, and the photo is always optional. Twenty-two models include
`HasPhoto`: `Universe`, `Story`, `Section`, `Scene`, `Character`, `Faction`, `FactionRelationship`, `Location`, `Route`, `Item`, `Event`,
`Relation`, `Ownership`, and the nine `*_tag` models. Each of those tables has a nullable
`photo_id` with an index; none of them requires it, and no view, form, or list assumes a photo
exists.

The image itself lives in its own `photos` row rather than as a `photo`/`photo_path` pair on every
table, so the bytes, the normalization, and the optional reference are defined once:

| Table | Columns (beyond timestamps) | Notes |
|---|---|---|
| `photos` | `universe_id` FK (NOT NULL), `name`, `slug` (NOT NULL) | `has_one_attached :file`; the stored file is **only** the finished 300×300 crop — neither the original upload nor its metadata is written |
| `active_storage_blobs` / `active_storage_attachments` / `active_storage_variant_records` | Rails' own tables | created by `CreateActiveStorageTables`; the only Active Storage table that varies (`variant_records`) stays empty because a photo has no variants |

Model rules, one line each: the reference is `belongs_to :photo, optional: true`; a `Photo` from
another universe is refused; the stored bytes are an image this application produced, never the
submitted bytes; replacing a photo is safe, because the old row is destroyed only after the
transaction commits and only while nothing else refers to it; and the model exposes no `url`
method. Each rule is stated in full in [features/photos.md](features/photos.md).

## Tables

### Identity & tenancy
| Table | Columns (beyond timestamps) | Notes |
|---|---|---|
| `users` | `email_address` (unique, NOT NULL), `name` (NOT NULL), `password_digest` (NOT NULL), `slug` (unique, NOT NULL), `platform_admin` (bool, default `false`, **NOT NULL**) | `has_secure_password`; email normalized (`strip.downcase`) via `normalizes`; `name` and `email_address` are both presence-validated, so a model caller sees a validation error rather than a `NotNullViolation` from `save!`. `platform_admin` is the one privilege in the application that is not a level inside a universe, and the only thing it grants is the **Limits** section of the platform settings page: it defaults to `false` so the privilege is never handed out by adding a column, and nothing in the interface sets it |
| `sessions` | `user_id` FK, `ip_address`, `user_agent`, `expires_at`, `last_used_at` | created on sign-in; referenced by the signed cookie, which expires with `expires_at`. `expires_at` is the absolute deadline (never extended by use) and `last_used_at` drives the idle timeout; both are set by the model, not by a column default, because the limits are policy values. Both are nullable so a row written before the columns existed is treated as still valid rather than signing everyone out. `user_agent` is enforced (a mismatch ends the session); `ip_address` is recorded for diagnostics only |
| `universes` | `name`, `owner_id` FK→users, `private` (bool, default `false`, **NOT NULL**), `slug` (unique), `collaboration_mode` (string, default `direct`, **NOT NULL**), `mutation_limit` (integer, default `60`, nullable), `photo_mutation_limit` / `membership_mutation_limit` / `discussion_mutation_limit` (integer, default `10`/`10`/`30`, nullable) | `visible_to(user)` includes public universes plus private universes owned by or joined by the user; only explicit `false` grants public access. `collaboration_mode` is one of `direct`/`wikipedia`/`github` and decides whether a change is written straight through or remembered for its author; what each mode commits the application to, and why the column is `NOT NULL`, are in [ADR 0019](adr/0019-collaboration-foundations.md). `mutation_limit` is how many mutations one account may make per `Universe::MUTATION_LIMIT_WINDOW` (1 minute); the column default is `DEFAULT_MUTATION_LIMIT` (60) so a new universe is limited from creation, and `NULL` is the stored form of "no limit at all" rather than a sentinel — `0` is refused by validation, because zero mutations and no limit are different settings and a universe nobody may write to is `private`. The three `*_mutation_limit` columns are that budget's per-group sub-limits — photo uploads, membership writes, discussion replies — with the same default/`NULL`/`0` rules and their own readers, listed once in `Universe::MUTATION_GROUP_COLUMNS`; a grouped mutation spends both its group's counter and `mutation_limit`. They are decided in [ADR 0029](adr/0029-per-endpoint-throttle-groups.md). `#administrators` is the owner plus the `admin` members — the `administrated_by` scope read the other way, and the set a submission is announced to, because `admin` access is the whole of who may read a reviewer's queue. `#members` is the owner plus everybody with a membership row, and `User#universes` is that relation from the other end; both are **methods rather than `has_many` through memberships**, because the owner has no membership row and an association built from memberships alone would silently leave the universe's founder out of the collaborators |
| `platform_settings` | `universe_creation_limit` (integer, default `5`, nullable); **no timestamps** | The single row of configuration that belongs to the deployment rather than to a universe: how many universes one account may create per `PlatformSetting::UNIVERSE_CREATION_WINDOW` (1 hour). It exists because universe creation is the one mutation with no universe to hold a budget, so `NULL` is "no limit on this at all" here for the same reason it is on a universe. `PlatformSetting.current` reads the first row and falls back to an unsaved one carrying the defaults rather than writing on read, and the reader substitutes the default for a `NULL` row while `#universe_creations_unlimited?` is what a limit check asks first — the same two-answer split as `Universe`. Decided in [ADR 0029](adr/0029-per-endpoint-throttle-groups.md) |
| `universe_memberships` | `universe_id` FK, `user_id` FK, `access_level` (1=read, 2=write, 3=admin; default 1) | unique per `[universe_id, user_id]`; the owner is implicitly admin and is not stored as a membership |

### Stories & sections
| Table | Columns | Notes |
|---|---|---|
| `stories` | `universe_id` FK (NOT NULL), `name`, `description`, `slug` (NOT NULL) | unique index on `[universe_id, slug]`; `has_many :scenes, dependent: :destroy` |
| `sections` | `story_id` FK (NOT NULL), `name`, `description`, `slug`, `parent_id` self-FK, `position` (default 0) | sections belong directly to a story; `has_many :scenes, dependent: :nullify` (deleting a section only ungroups scenes) |
| `plots` | `story_id` FK (NOT NULL), `name`, `description`, `slug` (NOT NULL), `deleted_at` (nullable) | named story-owned through-line; unique live `[story_id, name]` and `[story_id, slug]`; flat and unordered |
| `plots_scenes` | `plot_id` FK, `scene_id` FK | HABTM link; unique `[plot_id, scene_id]`; both ends must belong to the same Story (application validation) |
| `story_tropes` | `story_id` FK (NOT NULL), `trope_slug`, `context_note` (nullable) | one contextual annotation per catalogue slug and Story; unique `[story_id, trope_slug]`; rows survive soft deletion for restore |
| `scene_tropes` | `scene_id` FK (NOT NULL), `trope_slug`, `context_note` (nullable) | one contextual annotation per catalogue slug and Scene; unique `[scene_id, trope_slug]`; rows survive soft deletion for restore |
| `section_tags` | tag columns (below), `story_id` (NOT NULL) | story-scoped: each story owns its chapter/book/episode labels |
| `scene_tags` | tag columns (below), `story_id` (NOT NULL) | story-scoped: each story owns its scene-beat/mood labels; parent and position are story-local |
| `scenes` | `story_id` FK (NOT NULL), `name`, `description`, `slug` (NOT NULL), `status` (default `draft`, NOT NULL), `position` (default 0, NOT NULL), `section_id` FK (nullable), `datetime` (nullable), `pov_character_id` FK (nullable) | narrative order is `position`; `status` is one of `draft`/`revised`/`final` with a database check constraint; indexes on `[story_id, position]`, `[story_id, section_id]`, `[story_id, status]`, `section_id`, `pov_character_id`; no `parent_id`; Event links live in `scene_events`, not a column |
| `scene_events` | `scene_id` FK (NOT NULL), `event_id` FK (NOT NULL), `role` (nullable), `position` (default 0, NOT NULL), `deleted_at` (nullable) | an ordered depiction link: a Scene may depict several Events; unique live `[scene_id, event_id]`, index on `[scene_id, position]` and `deleted_at`; `role` is free text and blank means no role; no `parent_id`, slug, or `universe_id` |
| `scene_elements` | `scene_id` FK (NOT NULL), `kind` (NOT NULL, default `narration`), `name`, `body`, `word_count` (integer, NOT NULL, default 0), `position` (default 0, NOT NULL) | one flat ordered block of a Scene's prose; `word_count` is stored from `body` by `WordCountable` and summed by `WordCounts`; index on `[scene_id, position]`; `check_constraint` on `kind`; no `parent_id` |
| `scene_dialogue_turns` | `scene_element_id` FK (NOT NULL), `speaker_id` FK to `characters` (NOT NULL), `body`, `word_count` (integer, NOT NULL, default 0), `parenthetical`, `position` (default 0, NOT NULL), `deleted_at` (nullable) | one attributed line inside a Dialogue Element; same-Universe speaker; `word_count` follows the same stored-count rule as an Element's; index on `[scene_element_id, position]` and `deleted_at`; no `parent_id`, public slug, or `universe_id` |
| `scene_element_speakers` | `scene_element_id` FK (NOT NULL), `character_id` FK (NOT NULL) | no PK; unique `[scene_element_id, character_id]`; a plain many-to-many link with no data of its own |
| `scene_characters` | `scene_id` FK (NOT NULL), `character_id` FK (NOT NULL), `role` (nullable) | explicit presence; unique `[scene_id, character_id]`; `role` is free text and blank means no role |
| `scene_items` | `scene_id` FK (NOT NULL), `item_id` FK (NOT NULL), `role` (nullable) | explicit presence; unique `[scene_id, item_id]`; `role` is free text and blank means no role |
| `scene_locations` | `scene_id` FK (NOT NULL), `location_id` FK (NOT NULL), `role` (nullable) | explicit presence; unique `[scene_id, location_id]`; `role` is free text and blank means no role |

### Tag tables (`*_tags`) — all identical shape
`name`, `description`, `slug`, `parent_id` (self-FK), `position` (default 0),
`bgcolor` (default `#d3d3d3`), `fgcolor` (default `#000000`), `universe_id` FK —
**except `section_tags` and `scene_tags`, which have `story_id` instead of `universe_id`**.
`relation_tags` additionally has `symmetric` (bool, default `true`) and `inverse` (string).
Every tag has `taggable` (bool, default `true`): a tag with `taggable: false` is a grouping for its
children — it stays in the taxonomy tree and on records that already carry it, but it is not offered
in an element's tag editor. Its details page shows records under each direct child tag instead of a
flat descendant-inclusive list; the child sections have no include-descendants toggle. Taggable tags
retain the flat list and toggle. `character_tags`, `faction_tags`, `location_tags`, `item_tags`, and `event_tags`
additionally have `show_in_menu` (bool, default `false`): a tag with `show_in_menu: true` appears as a
tab on its workspace page and links to that tag's own details page. Workspace tab links carry
`from=workspace`, preserving that navigation on the tag page; taxonomy Details links remain canonical
and do not show workspace tabs.

Tag models: `character_tags`, `faction_tags`, `location_tags`, `item_tags`, `section_tags`, `scene_tags`,
`event_tags`, `relation_tags`, `ownership_tags`.

### Content tables
| Table | Columns | Notes |
|---|---|---|
| `characters` | `name`, `pronouns`, `aliases`, `at_a_glance`, `wants`, `needs`, `lies_to_self`, `contradictions`, `under_pressure_they`, `never`, `slug`, `parent_id`, `position`, `universe_id` | profile text fields are optional; Faction membership is zero-to-many and universe-scoped |
| `character_knowledges` | `universe_id`, `character_id`, optional `source_character_id`, `when_text`, `what_learned`, `changes_plan` (bool, default false), `deleted_at` | Character-owned knowledge change; both Character references must belong to the same Universe |
| `factions` | `name`, `slug`, `mission`, `actual_aims`, `structure`, `internal_divisions`, `resources`, `would_never`, `would_absolutely`, `universe_id`, `photo_id`, `deleted_at` | flat, universe-scoped profile |
| `faction_relationships` | `universe_id`, `from_faction_id`, `to_faction_id`, optional `name`, `description`, `from_date`, `to_date`, `slug`, `photo_id`, `deleted_at` | directed Faction-to-Faction link; endpoints must be distinct and in the same Universe; a reverse link is a separate record; the dates are a `TemporalInterval` |
| `locations` | `name`, `description`, `sensory_sight`, `sensory_sound`, `sensory_smell`, `sensory_taste`, `sensory_touch`, `layout_structure`, `layout_key_areas`, `layout_pathways`, `layout_entrances_exits`, `layout_points_of_interest`, `significance`, `history_significant_events`, `history_past_occupants`, `history_changes`, `access_controlled_by`, `access_granted_how`, `access_security`, `access_restrictions`, `slug`, `parent_id`, `position`, `universe_id`, `photo_id`, `deleted_at` | hierarchical and positioned; every profile field is optional text, ordered by `Location::PROFILE_FIELDS` and described in [features/locations.md](features/locations.md) |
| `routes` | `universe_id`, `from_location_id`, `to_location_id`, optional `name`, `description`, optional free-form `distance` and `duration`, `slug`, `photo_id`, `deleted_at` | directional path between two Locations; both endpoints must belong to the same Universe; not hierarchical or positioned |
| `canon_rules` | `universe_id` FK (NOT NULL), optional `story_id` FK, `name` (model-required), `slug` (model-required), optional `category`, optional `canon_type`, `statement` (NOT NULL), optional `source`, `deleted_at` | one rule the fiction obeys; no story means universe-wide, a story means that Story owns it; the Story must belong to the same Universe (application validation); the name is the short title, the slug is the stable address and is unique among the Universe's live rules, the optional category names the source area, and the optional canon type is `locked`/`rule`/`consequence`/`open`; `name` and `slug` are nullable in the table because existing rows are re-imported rather than backfilled; no hierarchy, position, tags, or photo — see [features/canon.md](features/canon.md) and [ADR 0045](adr/0045-a-canon-rule-has-a-name-and-a-stable-slug.md) |
| `items` | `name`, `description`, `what_it_does`, `how_it_is_used`, `side_effects`, `origin`, `value`, `cannot`, `constraints`, `history`, `jargon`, `slug`, `parent_id`, `position`, `universe_id`, `photo_id`, `deleted_at` | hierarchical and positioned; every profile field is optional text, ordered by `Item::PROFILE_FIELDS` and described in [features/items.md](features/items.md) |
| `events` | `title`, `name`, `description`, `slug`, `start_datetime`, `end_datetime`, `before_event_id`, `after_event_id`, `simultaneous_event_id` (all self-FKs), `parent_id`, `position`, `universe_id` | identity is title-driven; `has_many :scene_events, dependent: :destroy` and `has_many :scenes, through: :scene_events`; the datetimes are a `TemporalInterval` |
| `relations` | `character1_id`, `character2_id` (NOT NULL FKs), `name` (optional), `description`, `from_date`, `to_date`, `slug`, `universe_id` | **no** `parent_id`, **no** `position`; the dates are a `TemporalInterval` |
| `ownerships` | `character_id`, `item_id` (NOT NULL FKs), `name` (optional), `description`, `from_date`, `to_date`, `slug`, `universe_id` | **no** `parent_id`, **no** `position`; the dates are a `TemporalInterval` |

### HABTM join tables (no PK, two integer columns)
`characters_character_tags`, `factions_faction_tags`, `locations_location_tags`, `items_item_tags`,
`sections_section_tags`, `scenes_scene_tags`, `events_event_tags`, `relations_relation_tags`,
`ownerships_ownership_tags` — pattern `"<content table>_<tag table>"`, declared by
`has_many_tags` and reused by `has_many_tagged`. **Every one of these nine carries two foreign keys
and a unique index on its column pair** — the seven legacy tables by
`db/migrate/20260928120000_add_integrity_constraints_to_legacy_join_tables.rb`, `scenes_scene_tags`
from its own create migration — so an orphan or duplicate join row is refused by the database rather
than only by the scoped association reads. The Scene-owned tables `scene_element_speakers`,
`scene_characters`, `scene_items`, `scene_locations`, and `scene_events` do the same, their unique index being partial
(`WHERE deleted_at IS NULL`) because those five soft-delete. Every declaration supplies an explicit
shared scope
(`:universe_id`, or `:story_id` for Section/Scene tags), and both sides of each association validate
every assigned member against that scope. Association reads also apply the scope, hiding foreign
rows even if a raw/import path has already inserted a corrupt join. Because both scopes are
instance-dependent lambdas, Active Record refuses to eager load or group through these
associations; `TaggedRecordCounts` exists for the grouped read, and `tagged_records` for the
per-record read.

`characters_factions` is the separate Character↔Faction HABTM join: it has two foreign keys, a unique
pair index, and same-Universe validation on Character writes. Membership links survive a Character's
soft deletion and are visible again if that Character is restored.

`plots_scenes` is the separate story-scoped Plot↔Scene HABTM join. It also has two foreign keys and
a unique pair index; its application-level association writers and the development-data loader prove
that both records belong to the same Story.

`trope_slug` references the curated, app-wide `TropeCatalog` in code rather than another database
record. The models validate it against that list, while the owner foreign key and unique index keep
each persisted annotation attached to exactly one Story or Scene. Trope catalog and source details
are owned by [features/tropes.md](features/tropes.md).

### Conversations
| Table | Columns | Notes |
|---|---|---|
| `discussions` | `universe_id` FK (NOT NULL), `record_type` (NOT NULL), `record_id` (NOT NULL), `title` (nullable) | one thread per record; unique `[record_type, record_id]`. The pair is polymorphic and gets **no** foreign key — it is resolved and registry-gated by `RecordTarget`, and the model refuses a record whose universe is not the stored `universe_id`. `title` is reserved by the collaboration plan and **nothing writes it yet**; the record is the thread's subject |
| `discussion_messages` | `discussion_id` FK (NOT NULL), `user_id` FK (NOT NULL), `body` text (NOT NULL) | plain text; markdown is a later decision. Index `[discussion_id, created_at, id]` is the one query a thread makes, and `id` is the tiebreaker for two messages in one tick |

Both tables are reached through `HasDiscussion`, which every content and tag model except
`Photo` includes. `Photo` is the deliberate exception: it has no page of its own, so a thread on
one would have nowhere to be read. A hard-deleted record takes its thread with it, so every path
that removes a record also runs its callbacks — which is why `Character`, `Item`, and `Location`
`dependent: :destroy` their presence links rather than removing them with `delete_all`. A
*soft* delete deliberately keeps the thread, and `RecordTarget` refuses a soft-deleted record, so
the row is unreachable rather than disclosed. Which modes decide that a change is stored rather
than written is in [ADR 0019](adr/0019-collaboration-foundations.md).

`discussions.yml` and `discussion_messages.yml` load after every model in the registry, because a
thread's `record` reference may name any of them. A manifest names that record with one
`Model.slug` reference — `record: Character.martha` — which the loader resolves against
`Ability::CONTENT_CLASS_NAMES`, the same gate `RecordTarget` applies at runtime, so a manifest
cannot hang a thread off a `User` or a `Session`. A thread is identified in a manifest by its
**title**, declared as the definition's `identifier_field` rather than inferred from the model's
columns: the loader's preflight runs before the schema exists, so an identifier that asked the
database would not resolve during a reset. A `SceneElement` has no public slug, but a manifest may
name one with its YAML-only `manifest_key`; the key is not persisted.

### Remembered changes
| Table | Columns | Notes |
|---|---|---|
| `drafts` | `user_id` FK (NOT NULL), `universe_id` FK (NOT NULL), `status` (string, default `draft`, NOT NULL), `closed_at` (datetime, nullable), `applied_count`/`skipped_count`/`kept_count` (integer, NOT NULL, default 0) | one author's pending changes in one universe. Index `[user_id, universe_id]`, plus a **partial unique** index on the same pair over `status IN ('draft','submitted')`: applied and discarded drafts stay behind as history and a second editing session needs its own row, but two *unfinished* drafts for one author are refused by the database rather than left to two requests not colliding ([ADR 0022](adr/0022-an-editing-session-claims-the-browser-and-one-draft-stays-open.md)). `status` is one of `draft`/`applied`/`discarded`/`submitted`, the same list the column default comes from, and the same list the partial index names. `closed_at` plus the three counts are a closed draft's **history**: the moment it left the open statuses and the run's tally, written by whatever closed it — the applier inside its own transaction, `DraftsController#discard` outside one — from the same `Result` that wrote the `draft_change_outcomes` rows ([ADR 0024](adr/0024-an-applies-outcome-is-stored-and-a-closed-draft-stays-inspectable.md)). `Draft` validates that a draft outside the open statuses has a `closed_at`, so the moment is stored rather than read off `updated_at`; a `submitted` draft is open and has none |
| `draft_changes` | `draft_id` FK (NOT NULL), `record_type` (NOT NULL), `record_id` (nullable), `action` (NOT NULL), `payload` json (nullable), `base_version` (nullable), `created_at` | `action` is `create`/`update`/`delete`. The polymorphic pair gets **no** foreign key and is registry-gated by `RecordTarget`, like a thread's. `record_id` is nullable only because a `create` remembers a record that does not exist yet; `base_version` is required for the other two actions and refused for a `create`, which has nothing to version. `created_at` with **no** `updated_at`: a change is append-only and `before_update` raises. Index `[draft_id, created_at, id]`. A working draft's author may **destroy** one change to drop it from the draft; that is withdrawal rather than rewriting, and it is refused for a submitted or closed draft ([ADR 0036](adr/0036-a-remembered-change-can-be-dropped-before-it-is-applied.md)) |
| `draft_change_outcomes` | `draft_id` FK (NOT NULL), `draft_change_id` FK (NOT NULL, **unique**), `state` (NOT NULL), `answer` (nullable), `created_at` | what one change's apply did, so a closed draft can be read afterwards. A **new row per change** rather than columns on `draft_changes`, because a remembered change is append-only and what a run decided is a statement about a *later* moment; the unique index is then the rule "one outcome per change", which holds because a draft closes on its first apply. `state` is `written` or one of `DraftApplier::SKIP_REASONS` and `answer` is one of `DraftApplier::ANSWERS` or NULL, as two columns because a change answered `mine` **is** written while one answered `theirs` is not. `draft_id` is derivable from the change and validated against it. No `updated_at`: append-only, and `before_update` raises ([ADR 0024](adr/0024-an-applies-outcome-is-stored-and-a-closed-draft-stays-inspectable.md)) |
| `review_requests` | `draft_id` FK (NOT NULL), `universe_id` FK (NOT NULL), `submitted_by_id` FK to `users` (NOT NULL), `status` (string, default `pending`, NOT NULL), `reviewed_by_id` FK to `users` (nullable), `review_notes` text (nullable), `submission_message` text (nullable), `created_at`/`updated_at` | one author's request that somebody else apply a draft: the stored half of Phase 5's review workflow. A **new row per submission** rather than columns on `drafts`, because a rejected draft comes back as a working draft and may be submitted again, so "which review is this draft waiting for" is a history rather than one fact about the draft. `universe_id` and `submitted_by_id` are both derivable from the draft — the universe its changes were authorized in, and its one author — and both are stored so a reviewer's queue needs no join; both are validated against the draft rather than trusted, as a thread's `universe_id` is. `reviewed_by_id` is nullable because nobody has reviewed a pending request, and `review_notes` is nullable because an approval usually has nothing to explain but **required** for a rejection — a reviewer's note for the author is welcome on either decision, and an empty box is stored as `nil` rather than as an empty string that would read back as something a reviewer said. `submission_message` is the **author's** side of the same conversation — what they want a reviewer to know before reading the diffs — and it is nullable for the opposite reason: a request with nothing to add is still a request, where a rejection's notes exist to explain the decision. It is on `review_requests` rather than on `drafts` because a rejected draft may be submitted again with a different message, so what was asked for is a statement about one handover. The **partial unique** index on `draft_id` over `status = 'pending'` is the rule "one draft has one review in flight": a rejected submission stays behind as history and the author may submit again, while two *pending* requests would mean two reviewers racing to apply the same changes. `status` is `pending`/`approved`/`rejected`/`withdrawn`, the same list the column default comes from: a **withdrawal** is the author discarding the draft the submission was about, so it carries no `reviewed_by_id` and no `review_notes` (nobody reviewed it) and is not `decided?` — "decided" answers "did a reviewer rule on this", which is the question an audit asks |

The column is `payload`, not `changes` as the collaboration plan named it: Rails 8.1 refuses an
attribute that Active Record already defines, and `changes` is `ActiveModel::Dirty`'s
(`ActiveRecord::DangerousAttributeError`); `attributes` is refused the same way. `payload` is the
name the notifications table uses for opaque stored data too.

`base_version` is a **string**, and `DraftChange.capture_base_version` is the only supported way to
fill it, because it routes through `VersionStamp`. A raw `updated_at` written here is a `Time`, a
`Time` is never equal to the string it is compared against, and every stored change would then be
reported as a conflict. See [ADR 0019](adr/0019-collaboration-foundations.md).

None of these three models is in `Ability::CONTENT_CLASS_NAMES`, and none is universe content: a draft
is one author's pending work and a review request is that work under somebody else's decision, so
registering either would let the content rules answer `read` for a guest in a public universe.
`test/models/ability_test.rb` carries the reasons.

"One open draft at a time" is the rule the missing unique index left to the editing flow, and it is
`Draft`'s to answer rather than a controller's: the `open` scope, `OPEN_STATUSES`, and
`Draft.open_for` / `Draft.open_for!` are one list read three ways, so the draft a change joins, the
draft `open?` describes, and the draft the apply workflow will touch cannot disagree. `open_for` returns
the **most recent** unfinished draft (an applied or discarded one is history and is never resumed), and
`open_for!` opens one when there is none — which is the only place a draft is created outside a test.
Two requests arriving together can each find no open draft and each open one; the consequence is two
drafts for one author rather than a refused write.

Submitting is `Draft#submit!`, and it is one operation rather than two: it creates the review request
and moves the draft to `submitted` inside a single transaction, because either half alone is wrong in
both directions — a `submitted` draft with no request is a draft nobody is ever going to look at, and a
request against a draft that still says `draft` is a reviewer's queue entry whose subject the author can
still edit under. Only a working draft may be submitted, and that refusal **raises** rather than
returning false, because the caller is a workflow step rather than a form and a control that quietly did
nothing would leave an author waiting for a reviewer who was never asked. Its `message:` is the author's
optional own sentence, stored on the request it creates and normalized to `nil` when blank, because a
rejected draft may be handed over again with a different message.
`Draft#pending_review_request` reads the pending scope rather than the newest request, because a draft
that was rejected and is being edited again still carries the rejected request behind it.

A **rejection** is `ReviewRequest#reject!`, and it is the same one-transaction rule read backwards: the
request's own status and the draft's status to `draft` move together, so a rejected request cannot leave
a draft nobody can edit, and a draft back in its author's hands cannot sit in the queue still marked
pending. The draft returns to `draft` rather than to a closed status, and keeps its `draft_change_outcomes`
untouched, because a rejection is somebody else's decision about the author's work: the changes are still
there to edit and submit again. A refusal restores the stored state on the instance, so a rejected
rejection is rendered as what it is. **Approval is deliberately not on the model** — an approval is an
apply, and its decision has to land inside the applier's transaction; see
[conventions.md](conventions.md#the-reviewers-page). Its optional note is read from the request the same
way, as `nil` when it is absent or blank.

A **withdrawal** is `ReviewRequest#withdraw!`, and it is `reject!`'s one-transaction rule a third time:
the request's own status and the draft's move to `discarded` together, because a discarded draft whose
submission still said `pending` is a queue entry waiting on work that no longer exists — and approving it
would still write the changes, since `DraftApplier` asks whether a draft is open nowhere. It is the
author's own answer rather than a reviewer's, so it **raises nothing** (discarding is a control on the
author's page with no field to get wrong) and records no reviewer and no notes. `decided?` excludes it,
so "who let this through" is never answered with a person who never saw the work; `waiting?` is the
positive name for `pending?`, and the two come apart exactly where a fourth status exists.

A remembered `create` carries the submitted attributes **and** the column that places the record in its
scope, so the payload alone says where the record goes. See
[conventions.md](conventions.md#controllers) for which column that is per model and
[ADR 0020](adr/0020-remembering-mutations-instead-of-writing-them.md) for why nothing else is copied out
of the record.

A **submitted draft is not appendable**: a change arriving while its `ReviewRequest` is `pending` is
refused in the caller's own response shape rather than appended, because the reviewer's page and the
applier read the draft live and a change that arrived after the submission message was written is work
the submission never described. Nothing was hidden by that, so the guarantee rather than the visibility
is what is restored. See
[conventions.md](conventions.md#the-drafts-page).

### The `notifications` table

| Table | Columns | Notes |
|---|---|---|
| `notifications` | `user_id` FK to `users` (NOT NULL), `kind` (NOT NULL), `read` (boolean, NOT NULL, default false), `payload` json (nullable), `created_at` | one thing that was said to one person. `user_id` with a cascade rather than an owner-and-type pair because a notification has exactly one reader — marking it read is that person's act, and no version of it is for somebody else. `kind` is `review_submitted`/`review_approved`/`review_rejected`/`discussion_reply`, `Notification::KINDS`, and is **not** `type` as the collaboration plan named it: `type` is Active Record's single-table-inheritance discriminator, so a row whose type was `"review_submitted"` would be looked up as a class name (`SubclassNotFound`), which is the same answer the `payload` column gives for `changes` above. Indexes `[user_id, created_at, id]` for the reader's own list and `[user_id, read]` for the navbar's uncached unread count. `created_at` with **no `updated_at`**: `read` is the only column that changes after the row is written and nothing reports when a reader opened their bell. **No foreign key to the universe, draft, or submission** — see below |

**The payload is a frozen sentence, not a pointer**, and that is why there is no foreign key to any of
the rows it names: the universe's slug and name, the draft and submission ids, the other person's name,
and a reviewer's note where there is one are all copied in. The submission is destroyed with its draft
and with its universe, so a row that resolved any of them to print itself would raise on a page that
has to keep working; the cost is names stored twice and validated by nothing, deliberately. A row with
no payload at all is printable and simply has nothing to link at, which is what `payload` being
nullable buys. See [conventions.md](conventions.md#notifications), which owns who is told what, and
[ADR 0025](adr/0025-a-notification-is-a-stored-sentence.md), which owns why the copy is the design.

### The `story_interchange_runs` table

| Table | Columns | Notes |
|---|---|---|
| `story_interchange_runs` | `user_id` FK to `users` (NOT NULL), `source` (NOT NULL), `universe_name` (NOT NULL), `universe_slug` (NOT NULL), `replaced` (boolean, NOT NULL, default false), `outcomes` json (NOT NULL), `created_at` | one platform admin's completed story-interchange import, written in the import's own transaction. `outcomes` is the array of per-slice answers — `label_key`, `created`, `skipped` — because the full reported list is too large for a flash; [features/story_interchange.md](features/story_interchange.md#the-run-page) owns the page. **No foreign key to `universes`**: the name and slug are copied in so a run whose universe a later run replaced can still print, the trade [ADR 0025](adr/0025-a-notification-is-a-stored-sentence.md) makes. `created_at` with **no `updated_at`**, because the row is never edited. |

### Non-app tables
`solid_cache` / `solid_cable` / `solid_queue` live in their own schema files
(`db/cache_schema.rb`, `db/cable_schema.rb`, `db/queue_schema.rb`).

### Photo columns, per table
`universes`, `stories`, `sections`, `scenes`, `characters`, `factions`, `faction_relationships`, `locations`, `routes`, `items`, `events`,
`relations`, `ownerships`, and all nine `*_tags` tables each carry one nullable, indexed
`photo_id`. `users`, `sessions`, `scene_elements`, `scene_dialogue_turns`, and the Scene
presence-link tables do not. See
[Photos](#photos) for the rules those references obey.

## Tag taxonomy matrix

| Content model | Tag model (`has_many_tags`) | Join table | Tag required? |
|---|---|---|---|
| Section | `:section_tag` | `sections_section_tags` | **no** |
| Scene | `:scene_tag` | `scenes_scene_tags` | **no** |
| Character | `:character_tag` | `characters_character_tags` | **no** |
| Faction | `:faction_tag` | `factions_faction_tags` | **no** |
| Location | `:location_tag` | `locations_location_tags` | **no** |
| Item | `:item_tag` | `items_item_tags` | **no** |
| **Event** | `:event_tag` | `events_event_tags` | **no** |
| Relation | `:relation_tag` | `relations_relation_tags` | **no** |
| Ownership | `:ownership_tag` | `ownerships_ownership_tags` | **no** |
| Story / Universe / User | — | — | — |

Tags are **optional on every content model**: `has_many_tags` declares only the HABTM (no
presence validation), and no controller force-assigns a default tag — creating a character,
location, item, section, scene, relation or ownership without picking a tag simply saves it
untagged. A simple story therefore works without any taxonomy: add a few characters, locations,
sections, scenes, etc. and tag them later (or never). Deleting a tag just leaves its records
untagged; they stay valid.

## Hierarchies & positions

Models including the `Hierarchical` concern (own `parent_id` self-FK + `children` +
`position`): **Section, SectionTag, SceneTag, Character, CharacterTag, FactionTag, Location, LocationTag,
Item, ItemTag, Event, EventTag, RelationTag, OwnershipTag**.

Validations added by the concern:
1. parent must be in the **same owning scope** — same `universe_id` by default,
   same `story_id` for Section and SectionTag (`hierarchy_scope*` overrides);
2. parent cannot be itself;
3. parent cannot be a descendant (walks `ancestor_chain`).

Ordering: `position` defaults to 0; `MaintainsSiblingPositions` delegates create, move, reparent,
and destroy normalization to `PositionedResourceOrder`. The service runs each operation in a
transaction while locking the persisted scope owner, supports explicit hierarchical and flat
modes, and maintains contiguous 0..n-1 positions ordered by `(position, id)`. Drag/drop and the
accessible Move controls send the same `{ parent_id, position }` contract.

**Every positioned model also repairs its own sequence.** `OrderedSequence`
(`app/models/concerns/ordered_sequence.rb`) renumbers the whole sibling group on `after_destroy`,
`after_soft_delete`, and `after_restore`, so a write that reaches the model directly — a console
`destroy!`, a direct `soft_delete`, a `restore` — closes the gap it made instead of leaving
`[0, 1, 3]` behind. It is repair, not the service's guarantee: it runs in whatever transaction the
caller's write runs in, often none, and SQLite has no portable row lock. A hierarchical model gets
it by including `Hierarchical`; a flat one declares `ordered_sequence_within :story` (Scene) or
`:scene` (SceneElement), naming the owner whose collection *is* the sequence. On `restore` the
record is renumbered **with** the group rather than excluded from it: its own `position` is a stale
slot that a later arrival may now hold, and `(position, id)` puts it back where it was rather than
always appending it. Raw SQL, `update_column`, and `delete_all` still bypass it — no callback runs
for a write that skips the model.

**A write that skips the model is repaired by running the command.** `SequenceNormalizer`
(`app/services/sequence_normalizer.rb`) walks every positioned model, groups its records by
`Model.ordered_sequence_group_columns` — the same declaration the repair above reads on an instance
— and renumbers each group to `0..n-1`, printing every record it moves with its sequence and both
positions. Run it after raw SQL, an import, or any `create!` that named its own `position`:

    bin/rails positions:normalize                          # everything
    bin/rails positions:normalize_universe[netflix-dark]  # one universe

The same walk without the writing is the check:

    bin/rails positions:status                            # reports, writes nothing
    bin/rails positions:status_universe[netflix-dark]

**Why there is a check and not only a repair.** The command is a step somebody has to remember,
and a repair cannot notice that it was forgotten. `#check` walks exactly the same models, groups,
and records — so it cannot report on a different set than it would fix — and says `every sequence
is contiguous` or lists what is not, **exiting non-zero when anything is**, which is what makes it
usable from a script or a CI job rather than only by a person already watching the terminal.

It runs in any environment, like `search:reindex`, because it repairs data the application already
derives, and it reports every move rather than refusing outright — a reader's narrative order is
their work, so a surprising line in the output has to be visible enough to undo by hand. It is
**not** a second writer: it takes no scope-owner lock, so `PositionedResourceOrder` remains what
maintains a sequence while the application is writing to it.

Not hierarchical: **Relation**, **Ownership** (link records), **Plot**, **Scene**, **SceneElement**,
**SceneDialogueTurn** and **SceneEvent** (flat story-/scene-/element-owned sequences),
**SceneCharacter**, **SceneItem**, **SceneLocation** (link records), **Story**, **Universe**, **User**,
**Session**, **Draft** and **DraftChange**. A draft
change *is* ordered — by `created_at`, then `id`, which is the order it was remembered in — but it
is an append-only log rather than a sequence an author rearranges, so it carries no `position` and
no `parent_id`.

## Validations & invariants (per model)

| Model | Validations |
|---|---|
| `Universe` | `name` and owner presence; `private` must be an explicit boolean; `slug` unique among live rows (mirrors the partial unique index, so a taken address is a field error and not a `RecordNotUnique`); slug generated by `HasSlug`; `collaboration_mode` must be one of `COLLABORATION_MODES`, so a mode with no behaviour behind it is a field error an admin can answer rather than a universe whose writes quietly do the wrong thing; `mutation_limit` must be `nil` or a positive integer, and the reader answers `nil` rows as `DEFAULT_MUTATION_LIMIT` so an incomplete row is never the one unprotected state; the three `MUTATION_GROUP_COLUMNS` values carry the same validation and the same default-fallback reader, and an unknown group raises rather than defaulting |
| `PlatformSetting` | `universe_creation_limit` must be `nil` or a positive integer, and the reader answers `nil` rows as `DEFAULT_UNIVERSE_CREATION_LIMIT` for the same reason `Universe` does |
| `UniverseMembership` | user/universe presence; access level in read/write/admin; unique user per universe; owner cannot be a separate member |
| `Discussion` | `universe` and `record` are both required. The polymorphic `record` is `optional: true` on purpose — Rails' own presence validation reads the association, which would `constantize` a stored `record_type` before `RecordTarget` had gated it — so the two model validations own the reference: "does not exist" for a type outside `CONTENT_CLASS_NAMES`, an unknown id, or a soft-deleted record, and "must belong to the same universe" for a record the stored universe does not own. One thread per record is enforced by the unique pair index |
| `DiscussionMessage` | `discussion` and `user` presence; `body` presence | no authorization check: who may write is asked by the controller about the thread's *record* |
| `Draft` | `user` and `universe` presence; `status` inclusion in `STATUSES` (`draft`/`applied`/`discarded`/`submitted`), the same list the column default comes from — a status nothing behaves for would be a draft no control can apply or discard. Four predicates plus `open?` (`OPEN_STATUSES`: `draft` or `submitted`; an applied or discarded draft is history) so no caller re-derives a lifecycle state from a raw string, and the `open` scope reads that same list so a finder and the apply workflow cannot disagree | no authorization check: who may see a draft is asked by the controller about its **owner**, not about a universe record |
| `DraftChange` | `draft` presence; `action` inclusion in `ACTIONS` (`create`/`update`/`delete`); `record_type` presence **and** registration in `CONTENT_CLASS_NAMES`; a `create` must leave `record_id` and `base_version` blank and an `update`/`delete` must supply both; a named record must resolve through `RecordTarget` (so an unknown id and a soft-deleted record are one "does not exist") and must belong to the **draft's** universe; updates raise (`append-only`). That collapsing is the *validation's* answer; `RecordTarget.find_including_deleted` asks the other one, because a record somebody has since deleted and a record that was never there are different answers to "has this change moved?" — see [conventions.md](conventions.md) | no authorization check: a change is reached only through its draft's owner |
| `ReviewRequest` | `draft`, `universe`, and `submitted_by` presence; `status` inclusion in `STATUSES` (`pending`/`approved`/`rejected`/`withdrawn`), the same list the column default comes from — a status nothing behaves for would be a review no page can answer. `universe` must be the **draft's**, and `submitted_by` must be the **draft's author**, so the two stored-but-derivable columns cannot quietly disagree with the one they came from. A `rejected` request must carry `review_notes`, because saying why is the whole of a rejection; an `approved` one need not, because an approval has nothing to explain, and a `withdrawn` one carries neither, because nobody reviewed it. An `approved` or `rejected` request must name its `reviewed_by`, so a decision can answer who let it through; a `pending` or `withdrawn` one has no reviewer, which is why that association is `optional` and why the rule asks about `decided?` rather than `!pending?`. `submission_message` is unvalidated because it is optional by design. Four status predicates plus `decided?`, `waiting?`, and the `pending` scope all read named values rather than raw strings, so no caller re-derives a review state from a column | no authorization check: a reviewer's queue is a query inside a universe the request has already authorized at the admin level, and no action authorizes one of these rows on its own |
| `Notification` | `user` presence; `kind` inclusion in `KINDS` (`review_submitted`/`review_approved`/`review_rejected`/`discussion_reply`), so a kind with no sentence behind it is a field error rather than a badge nothing can read. `read` is a boolean with a default and nothing validates it — a notice is written once and marked, never edited | no authorization check: a notification has exactly one reader, so the scope is `Current.user.notifications` rather than a rule ([ADR 0025](adr/0025-a-notification-is-a-stored-sentence.md)) |
| `Story` | `name` presence + unique per universe; `slug` unique per universe |
| `Section` | `name` presence; `story` required; parent rules scoped to the story; `section_tags` optional, but when present they must all belong to the section's story through the shared HABTM scope; `has_many :scenes, dependent: :nullify` |
| `Plot` | `name` presence and unique among live Plots in its Story; `story` required; `scenes` optional and, when present, all must belong to the same Story; unknown, duplicate, or cross-Story scene assignments are ordinary validation errors; no `parent_id` or `position` |
| `Scene` | `name` presence; `status` presence and inclusion in `draft`/`revised`/`final` (plus a database check constraint); `story` required; `section` optional and must belong to the same story; `pov_character` optional and must belong to the story's universe; `scene_tags` optional and, when present, all belong to the story; `plots` optional and, when present, all belong to the story; an unknown optional `section_id`/`pov_character_id` is "must exist"; an unparseable `datetime` is "is not a valid date and time"; no `parent_id`; Event links are `SceneEvent` rows |
| `SceneEvent` | `scene` and `event` required; `event_id` unique per scene among live links ("is already linked to this scene"); `event` must belong to the scene's universe; an unknown `event_id` is "must exist"; `role` is free text, blank means no role; `position` is flat and contiguous inside the Scene; no `parent_id`, slug, or `universe_id` |
| `SceneTag` | `name` presence; `story` required; parent rules scoped to the story; `scenes` optional and, when present, all belong to the story; `HasColor`, `Hierarchical`, and slug behavior |
| `SceneElement` | `name` presence; `scene` required; `kind` presence and `inclusion` in `narration`/`dialogue` (plus a database check constraint); a Dialogue needs at least one same-Universe Character in its block-level speaker roster ("Speakers is required for a dialogue element"); Narration may not keep roster speakers or any turn rows, including soft-deleted turns (unless roster removal is explicitly confirmed); an unknown, duplicated, or cross-universe `character_ids` entry is an ordinary field error; no `parent_id` |
| `SceneDialogueTurn` | `scene_element` and `speaker` required; the Element must be Dialogue; the speaker must belong to the Scene's Universe; `body` and `parenthetical` optional; position is flat and contiguous inside the Element; no `parent_id` or `universe_id` |
| `SceneCharacter` | `scene` and `character` required; `character_id` unique per scene ("is already in this scene"); `character` must belong to the scene's universe; `role` is free text, blank means no role; no `parent_id`, no `position` |
| `SceneItem` | `scene` and `item` required; `item_id` unique per scene ("is already in this scene"); `item` must belong to the scene's universe; `role` is free text, blank means no role; no `parent_id`, no `position` |
| `SceneLocation` | `scene` and `location` required; `location_id` unique per scene ("is already in this scene"); `location` must belong to the scene's universe; `role` is free text, blank means no role; no `parent_id`, no `position` |
| `Character` / `Location` / `Item` | `name` presence; `*_tags` optional and, when present, all belong to the content's universe; `Hierarchical` rules |
| `Faction` | `name` presence; `faction_tags` optional and, when present, all belong to the faction's universe; profile text is optional |
| `FactionRelationship` | `from_faction` and `to_faction` required and distinct; both endpoints must belong to the relationship's Universe; optional name and description; `from_date`/`to_date` follow `TemporalInterval` |
| `_tag` models | `name` presence; `bgcolor`/`fgcolor` must be `#rrggbb` (`HasColor`); `Hierarchical` rules (for `SectionTag` the parent must share the **story**); `relation_tags` also requires `inverse` unless `symmetric` |
| `Event` | `must_be_identifiable` (title **or** start/end datetime **or** a before/after/simultaneous relation); referenced events must be in the same universe; model validation and three DB check constraints reject self references (including unsaved/future IDs); `Hierarchical` rules; *no* name-presence rule. Destroying an event nullifies all incoming temporal references; a relation-only referrer that would become unidentifiable is destroyed first |
| `Relation` | `character1`/`character2` required; both characters and all `relation_tags` must be in the same universe |
| `Ownership` | `character`/`item` required; both records and all `ownership_tags` must be in the same universe |
| `Route` | `from_location` and `to_location` required; both Locations must belong to the Route's Universe; name, distance, and duration are optional |
| `CanonRule` | `statement` required; `universe` required; `story` optional, but a named Story must belong to the Rule's Universe and an unknown `story_id` is "does not exist"; `source` optional; no slug |
| `Photo` | `universe` required; an attachment must be present (`file must be attached`) or the row is not a useful record; `HasSlug` |
| `User` | `has_secure_password` (password confirmation on create); unique normalized email (DB unique index) |
| `Session` | `user` required |
| any model including `HasPhoto` | `photo` optional; when present it must belong to the record's own universe ("must belong to the same universe"). `Photo::OWNER_CLASS_NAMES` lists every model that may point at a `Photo` and is kept equal to the `HasPhoto` includers by a model test |

Cross-universe checks are **application-level only** because ordinary foreign keys cannot prove
that two records share a universe/story. Several same-scope checks (e.g. "parent in same story",
"section tags of the same story") likewise have no join/constraint enforcement. The Event temporal
columns are the exception: SQLite check constraints enforce that they cannot point to their own row.

## Slugs

- `HasSlug` (app/models/concerns/has_slug.rb): `before_validation :set_slug`.
  Priority: an explicitly changed `slug` → slugified `name` when the name changes → the existing
  slug/name → a random hex fallback when no usable value exists. Generated slugs therefore follow
  name changes; an explicitly supplied slug wins for the save on which it is supplied.
- Event's `set_name` and the composite-slug callbacks on `Relation`/`Ownership` use `prepend: true`
  so they run before the generic `HasSlug` callback when a record is first created. Relation and
  ownership composite slugs are creation-time snapshots; later endpoint or tag changes do not
  rewrite them, while a name change follows the generic name-based rule.
- `slugify` = `parameterize` + `_+ → -`. **Write slugs dash-separated**, including fixture
  slugs; the class-level finder `Model.some_name` (custom `method_missing`) also slugifies its
  argument, so underscore-separated fixture labels are not the stored slug format.
- Uniqueness: **DB-enforced** for `universes.slug`, `users.slug` and
  `stories.[universe_id, slug]`; everywhere else uniqueness is a matter of convention. `Universe`
  and `Story` validate their unique keys too, with the index's own `deleted_at IS NULL` condition,
  so a collision is an ordinary field error; other models don't validate slug uniqueness.
- A universe's slug is its **public address** (`/u/<slug>`) and is global rather than per-universe,
  so `HasSlug` derives it from the name and two names can slugify alike. The universe form therefore
  takes an optional `slug` to disambiguate one. A blank field is not submitted
  (`UniversesController#universe_params`), because a blank submitted slug would let `HasSlug`
  regenerate the address from the name on an unrelated save — republishing the universe under a new
  address and invalidating every path stored below it. See
  [the delivery history](delivery_history.md).
- `Relation`/`Ownership` additionally generate a `character-tag-character` (or
  `character-character` when untagged) slug when no explicit slug or name is supplied. Because
  tags are optional, the tag segment is omitted for an untagged record; if no part is available,
  a random hex slug is used.

## Stories vs world building (why the split exists)

One universe can host several stories that share the same world (e.g. *A Song of Ice and Fire*
hosts *Game of Thrones* and *House of the Dragon*): characters/relations/locations/events/items
are defined once per universe, while each story has its own section tree (its plot structure) and
its own ordered scene sequence, plus its own section tags (chapter/book/episode labels). This
ownership split is defined directly by
the schema-only create migrations: `stories` owns its slug, and `sections`, `section_tags`,
`scene_tags`, and `scenes` reference `stories`. Data is disposable and reconstructed from the
per-universe directories under `db/data/`; it is not backfilled by migrations. Section tags, Scene
Tags, sections, and scenes are reachable only under the explicit story path
(`/u/<slug>/s/<story_id>/section_tags`, `/u/<slug>/s/<story_id>/scene_tags`,
`/u/<slug>/s/<story_id>/sections`, and `/u/<slug>/s/<story_id>/scenes`). The universe-level
`/u/<slug>/section_tags`, `/u/<slug>/scene_tags`, `/u/<slug>/sections`, and `/u/<slug>/scenes`
routes are intentionally invalid.

## The Scene writing model

Schema for the Scene domain is in the tables above and the per-model validations table; the domain
itself — the narrative sequence, the four workspace tabs, the participation union, the value objects,
and the deletion contract — is in [features/scenes.md](features/scenes.md).

Two things are worth keeping here because they are about the **migrations** rather than the
behaviour:

- The `scenes` create migration is schema-only: a real `story_id` foreign key, `null: false`
  `position` with a `0` default, `null: false` `slug`, timestamps, and a composite
  `[story_id, position]` index. The optional `section_id` reference and the `datetime`
  column arrived in a **separate** alter migration (`AddSceneReferencesToScenes`), because the create
  migration had already shipped; `event_id` moved to its own `scene_events` table and the column was
  removed by `RemoveEventFromScenes`.
- An applied migration is never amended: on a freshly created database Rails loads `db/schema.rb`
  instead of executing the migration files, so an edit silently changes nothing. The mechanism and the
  required workflow are in
  [development.md](development.md#amending-a-shipped-migration-does-not-work-here).

## Development data convention

`db/data/` is checked-in but disposable development data, organized as one directory per universe:

```text
db/data/dark/
db/data/lotr/
```

A new persisted model adds its data file to every universe directory where it should be exercised.
For example, a future `Dialog` model uses `db/data/dark/dialogs.yml` and, if applicable,
`db/data/lotr/dialogs.yml`; it does not get a `db/data/dialog/` feature directory. The shared
`Development::UniverseDataRegistry` order must place the model after its dependencies, and every
registered universe directory must include its file (use `[]` when intentionally unused).
References must preserve the model's universe/story scope. Universe membership data follows the
same convention (`universe_memberships.yml`) when a sample universe needs explicit private access
or delegated admin access. The loader validates the exact file set, identifiers, forward references,
attributes, and universe/story scope before writing; it normalizes hierarchical sibling positions
from file order, or requires complete unique explicit positions for a sibling group. Which command to
run, and when, is in
[development.md](development.md#required-workflow-after-editing-demo-yaml).

`SceneElement` has no public slug, so a manifest may give a referenced Element a YAML-only
`manifest_key`; the loader uses it for child references and never writes it to the table. A
`SceneDialogueTurn` names its `scene_element` by that key and its `speaker` by `Character.slug`, and
its flat positions are grouped within each Element rather than across the whole Scene.

Photo data follows the same convention with one extra rule: a `photos.yml` entry names a file under
`db/photos/<universe_slug>/` through the virtual `source_file` attribute rather than carrying bytes,
and a record references its photo by name. `source_file` goes through exactly the same processing an
upload does, so a sample photo is cropped and resized to 300×300 on the way in and the stored file
is never the source asset. Sample images are deliberately **not** square, so the stored square proves
the crop rather than passing through. `db/photos/` is a checked-in asset directory beside
`db/data/`, not inside it.
Records made only in the UI are intentionally lost and are not merged back into YAML. Neither
`db:seed` nor `db:prepare` loads `db/data/`. Development data is for browser/manual validation only;
automated tests use `test/fixtures/`, and production bootstrap data belongs in
`db/seeds.rb`/`db/seeds/`. `Draft`, `DraftChange`, `DraftChangeOutcome`, and `ReviewRequest` are the
models with no manifest at all, and
the reason is in
[development.md](development.md#adding-a-new-content-model-checklist) — a change's version stamp is
a moment rather than a reference, and a submission is somebody's unfinished work rather than universe
content.
