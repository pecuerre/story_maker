# Data Model

Everything about the schema: tables, ownership/scoping rules, tag taxonomy matrix, validations
and the slug system. Verified against `db/schema.rb` (SQLite, schema version
`2026_09_28_235300`) and the models in `app/models/`.

## Ownership graph

```
User (owner)
 └── Universe  (1..n stories; everything below is scoped to exactly one universe)
      ├── UniverseMembership ──> User (read/write/admin)
      ├── Photo (Active Storage attachment, one 300x300 square, optional on every record below)
      ├── Story ── Section ──> Section's parent Section (tree)
      │   │                     └── HABTM SectionTag ──┐
      │   ├── SceneTag (tree, story-scoped) ── HABTM SceneTag assignment
      │   └── Scene (contiguous narrative position) ──> Section / Event
      │       ├── SceneElement (contiguous flat position) ── HABTM Character (dialogue speakers)
      │       ├── SceneCharacter (explicit presence, optional free-text role) ──> Character
      │       ├── SceneItem (explicit presence, optional free-text role) ─────> Item
      │       └── SceneLocation (explicit presence, optional free-text role) > Location
      ├── Character ──> parent Character   ── HABTM CharacterTag (tree)
      ├── Location  ──> parent Location    ── HABTM LocationTag  (tree)
      ├── Item      ──> parent Item        ── HABTM ItemTag      (tree)
      ├── Event     ──> parent Event, before/after/simultaneous Event ── HABTM EventTag (tree, optional)
      ├── Relation  (character1 × character2) ── HABTM RelationTag (tree)
      ├── Ownership (character × item, dated) ── HABTM OwnershipTag (tree)
      └── (Session belongs to User, unrelated to universes)
```

**The one rule to remember:** world building (characters, locations, items, events, relations,
ownerships **and every `_tag` model except SectionTag and SceneTag**) belongs to the **universe** and
is shared by all of its stories. Only **sections** (the script: books → chapters → scenes …),
**scenes**, and their **section/scene tags** (chapter/book/episode or scene-beat labels) belong to a
**story** — each story owns its own structure taxonomy. A Scene's own components (Elements and
presence links) are narrower still: they belong to one **Scene** and reach the Universe through it.

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
- `soft_delete` / `restore` to mark and unmark a record;
- `deleted?`, and the `with_deleted` / `only_deleted` scopes to opt back in;
- a `soft_deletes :assoc` declaration for the associations that cascade.

Soft-deleting a parent cascades to its declared children (a Universe soft-deletes its stories,
characters, tags, and memberships; a Story soft-deletes its sections and scenes; a Scene
soft-deletes its elements and presence links; a Character soft-deletes its relations, ownerships,
and presence links). Two associations are cleared rather than cascaded, matching the existing
hard-delete contract: a Section's scenes are ungrouped (`section_id` nullified) and an Event's
temporal references are cleared, so a referrer that was only identifiable through the deleted Event
keeps its row and reports the missing identifier the next time it is saved.

The unique indexes that would otherwise block re-creating a record with the same key after a soft
delete are partial (`WHERE deleted_at IS NULL`): `universes.slug`, `stories.[universe_id, slug]`,
`universe_memberships.[universe_id, user_id]`, and the `scene_characters` / `scene_items` /
`scene_locations` presence-link pairs. The matching model validations carry the same condition.

`users` and `sessions` are not soft-deletable: they have no user-facing delete action, and a
session is an authentication token rather than content.

## Photos

A record may carry one photo, and the photo is always optional. Eighteen models include
`HasPhoto` (`app/models/concerns/has_photo.rb`): `Universe`, `Story`, `Section`, `Scene`,
`Character`, `Location`, `Item`, `Event`, `Relation`, `Ownership`, and the eight `*_tag` models.
Each of those tables gained a nullable `photo_id` with an index; none of them requires it, and no
view, form, or list assumes a photo exists.

The image itself lives in its own `photos` row rather than as a `photo`/`photo_path` pair on every
table, so the bytes, the normalization, and the optional reference are defined once:

| Table | Columns (beyond timestamps) | Notes |
|---|---|---|
| `photos` | `universe_id` FK (NOT NULL), `name`, `slug` (NOT NULL) | `has_one_attached :file`; the stored file is **only** the finished 300×300 crop — neither the original upload nor its metadata is written |
| `active_storage_blobs` / `active_storage_attachments` / `active_storage_variant_records` | Rails' own tables | created by `CreateActiveStorageTables`; the only Active Storage table that varies (`variant_records`) stays empty because a photo has no variants |

Rules the model layer enforces:

- **Optional everywhere.** `belongs_to :photo, optional: true`. A record without a photo is
  completely normal, and no controller force-creates one.
- **Same universe.** `photo_belongs_to_the_universe` rejects a `Photo` from another universe. The
  editor never sends an id at all — it sends the cropped square as a `data:` URL, and the model
  creates the `Photo` inside the record's own universe, so a cross-universe assignment is not
  reachable from the interface. A `Universe` is its own photo scope, because a universe is the
  outermost scope.
- **The server is the authority on the stored file.** `PhotoProcessing` resizes and re-encodes
  whatever arrives to a 300×300 JPEG with its metadata stripped, so a request that skipped the
  browser cropper still cannot store something else. Submitted bytes are checked against a
  content-signature allowlist (JPEG/PNG/GIF/WebP) before an image library sees them, and payloads
  over 8 MB are refused. The stored bytes are an image this application produced, never the
  submitted bytes.
- **Replacing is safe.** A new photo row is created after the record saves, inside the same
  transaction; the photo it superseded is destroyed only after that transaction commits, and only
  when no other record still points at it (`Photo::OWNER_CLASS_NAMES`, which a test keeps equal to
  the models that include `HasPhoto`). A rejected save never takes the picture away.
- **No URL on the model.** An Active Storage attachment's URL is built by the request that serves
  it, so a view asks the router through `ApplicationHelper#record_photo_url(record)` and the model
  exposes no `url` method that could only return `nil`.

## Tables

### Identity & tenancy
| Table | Columns (beyond timestamps) | Notes |
|---|---|---|
| `users` | `email_address` (unique), `name`, `password_digest`, `slug` (unique) | `has_secure_password`; email normalized (`strip.downcase`) via `normalizes` |
| `sessions` | `user_id` FK, `ip_address`, `user_agent` | created on sign-in; referenced by the signed cookie |
| `universes` | `name`, `owner_id` FK→users, `private` (bool, default `false`, **NOT NULL**), `slug` (unique) | `visible_to(user)` includes public universes plus private universes owned by or joined by the user; only explicit `false` grants public access |
| `universe_memberships` | `universe_id` FK, `user_id` FK, `access_level` (1=read, 2=write, 3=admin; default 1) | unique per `[universe_id, user_id]`; the owner is implicitly admin and is not stored as a membership |

### Stories & sections
| Table | Columns | Notes |
|---|---|---|
| `stories` | `universe_id` FK (NOT NULL), `name`, `description`, `slug` (NOT NULL) | unique index on `[universe_id, slug]`; `has_many :scenes, dependent: :destroy` |
| `sections` | `story_id` FK (NOT NULL), `name`, `description`, `slug`, `parent_id` self-FK, `position` (default 0) | sections belong directly to a story; `has_many :scenes, dependent: :nullify` (deleting a section only ungroups scenes) |
| `section_tags` | tag columns (below), `story_id` (NOT NULL) | story-scoped: each story owns its chapter/book/episode labels |
| `scene_tags` | tag columns (below), `story_id` (NOT NULL) | story-scoped: each story owns its scene-beat/mood labels; parent and position are story-local |
| `scenes` | `story_id` FK (NOT NULL), `name`, `description`, `slug` (NOT NULL), `position` (default 0, NOT NULL), `section_id` FK (nullable), `event_id` FK (nullable), `datetime` (nullable) | narrative order is `position`; indexes on `[story_id, position]`, `[story_id, section_id]`, `section_id`, `event_id`; no `parent_id` |
| `scene_elements` | `scene_id` FK (NOT NULL), `kind` (NOT NULL, default `narration`), `name`, `body`, `position` (default 0, NOT NULL) | one flat ordered block of a Scene's prose; index on `[scene_id, position]`; `check_constraint` on `kind`; no `parent_id` |
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
retain the flat list and toggle. `character_tags`, `location_tags`, `item_tags`, and `event_tags`
additionally have `show_in_menu` (bool, default `false`): a tag with `show_in_menu: true` appears as a
tab on its workspace page and links to that tag's own details page. Workspace tab links carry
`from=workspace`, preserving that navigation on the tag page; taxonomy Details links remain canonical
and do not show workspace tabs.

Tag models: `character_tags`, `location_tags`, `item_tags`, `section_tags`, `scene_tags`,
`event_tags`, `relation_tags`, `ownership_tags`.

### Content tables
| Table | Columns | Notes |
|---|---|---|
| `characters` | `name`, `description`, `slug`, `parent_id`, `position`, `universe_id` | |
| `locations` | same shape | |
| `items` | same shape | |
| `events` | `title`, `name`, `description`, `slug`, `start_datetime`, `end_datetime`, `before_event_id`, `after_event_id`, `simultaneous_event_id` (all self-FKs), `parent_id`, `position`, `universe_id` | identity is title-driven; `has_many :scenes, dependent: :nullify` |
| `relations` | `character1_id`, `character2_id` (NOT NULL FKs), `name` (optional), `description`, `from_date`, `to_date`, `slug`, `universe_id` | **no** `parent_id`, **no** `position` |
| `ownerships` | `character_id`, `item_id` (NOT NULL FKs), `name` (optional), `description`, `from_date`, `to_date`, `slug`, `universe_id` | **no** `parent_id`, **no** `position` |

### HABTM join tables (no PK, two integer columns)
`characters_character_tags`, `locations_location_tags`, `items_item_tags`,
`sections_section_tags`, `scenes_scene_tags`, `events_event_tags`, `relations_relation_tags`,
`ownerships_ownership_tags` — pattern `"<content table>_<tag table>"`, declared by
`has_many_tags` and reused by `has_many_tagd`. The legacy join tables have no database integrity
constraints; the new `scenes_scene_tags` table adds real foreign keys and a unique
`[scene_id, scene_tag_id]` index, as do the Scene-owned tables `scene_element_speakers`,
`scene_characters`, `scene_items`, and `scene_locations`. Every declaration supplies an explicit
shared scope
(`:universe_id`, or `:story_id` for Section/Scene tags), and both sides of each association validate
every assigned member against that scope. Association reads also apply the scope, hiding foreign
rows even if a raw/import path has already inserted a corrupt join. Because both scopes are
instance-dependent lambdas, Active Record refuses to eager load or group through these
associations; `TaggedRecordCounts` exists for the grouped read, and `tagged_records` for the
per-record read.

### Non-app tables
`solid_cache` / `solid_cable` / `solid_queue` live in their own schema files
(`db/cache_schema.rb`, `db/cable_schema.rb`, `db/queue_schema.rb`).

### Photo columns, per table
`universes`, `stories`, `sections`, `scenes`, `characters`, `locations`, `items`, `events`,
`relations`, `ownerships`, and all eight `*_tags` tables each carry one nullable, indexed
`photo_id`. `users`, `sessions`, `scene_elements`, and the Scene presence-link tables do not. See
[Photos](#photos) for the rules those references obey.

## Tag taxonomy matrix

| Content model | Tag model (`has_many_tags`) | Join table | Tag required? |
|---|---|---|---|
| Section | `:section_tag` | `sections_section_tags` | **no** |
| Scene | `:scene_tag` | `scenes_scene_tags` | **no** |
| Character | `:character_tag` | `characters_character_tags` | **no** |
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
`position`): **Section, SectionTag, SceneTag, Character, CharacterTag, Location, LocationTag,
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
accessible Move controls send the same `{ parent_id, position }` contract. Direct SQL/import and
some model-dependent destroy paths remain outside the controller service and require separate
maintenance if they become supported workflows.

Not hierarchical: **Relation**, **Ownership** (link records), **Scene** and **SceneElement** (flat
story- and scene-owned sequences), **SceneCharacter**, **SceneItem**, **SceneLocation** (link
records), **Story**, **Universe**, **User**, **Session**.

## Validations & invariants (per model)

| Model | Validations |
|---|---|
| `Universe` | `name` and owner presence; `private` must be an explicit boolean; slug generated by `HasSlug` |
| `UniverseMembership` | user/universe presence; access level in read/write/admin; unique user per universe; owner cannot be a separate member |
| `Story` | `name` presence + unique per universe; `slug` unique per universe |
| `Section` | `name` presence; `story` required; parent rules scoped to the story; `section_tags` optional, but when present they must all belong to the section's story through the shared HABTM scope; `has_many :scenes, dependent: :nullify` |
| `Scene` | `name` presence; `story` required; `section` optional and must belong to the same story; `event` optional and must belong to the story's universe; `scene_tags` optional and, when present, all belong to the story; an unknown optional `section_id`/`event_id` is "must exist"; an unparseable `datetime` is "is not a valid date and time"; no `parent_id` |
| `SceneTag` | `name` presence; `story` required; parent rules scoped to the story; `scenes` optional and, when present, all belong to the story; `HasColor`, `Hierarchical`, and slug behavior |
| `SceneElement` | `name` presence; `scene` required; `kind` presence and `inclusion` in `narration`/`dialogue` (plus a database check constraint); a Dialogue needs at least one speaker ("Speakers is required for a dialogue element"); Narration may not keep speakers ("Element type cannot be Narration while speakers are still assigned") unless the request explicitly confirms it; an unknown, duplicated, or cross-universe `character_ids` entry is an ordinary field error; speakers must belong to the scene's universe; no `parent_id` |
| `SceneCharacter` | `scene` and `character` required; `character_id` unique per scene ("is already in this scene"); `character` must belong to the scene's universe; `role` is free text, blank means no role; no `parent_id`, no `position` |
| `SceneItem` | `scene` and `item` required; `item_id` unique per scene ("is already in this scene"); `item` must belong to the scene's universe; `role` is free text, blank means no role; no `parent_id`, no `position` |
| `SceneLocation` | `scene` and `location` required; `location_id` unique per scene ("is already in this scene"); `location` must belong to the scene's universe; `role` is free text, blank means no role; no `parent_id`, no `position` |
| `Character` / `Location` / `Item` | `name` presence; `*_tags` optional and, when present, all belong to the content's universe; `Hierarchical` rules |
| `_tag` models | `name` presence; `bgcolor`/`fgcolor` must be `#rrggbb` (`HasColor`); `Hierarchical` rules (for `SectionTag` the parent must share the **story**); `relation_tags` also requires `inverse` unless `symmetric` |
| `Event` | `must_be_identifiable` (title **or** start/end datetime **or** a before/after/simultaneous relation); referenced events must be in the same universe; model validation and three DB check constraints reject self references (including unsaved/future IDs); `Hierarchical` rules; *no* name-presence rule. Destroying an event nullifies all incoming temporal references; a relation-only referrer that would become unidentifiable is destroyed first |
| `Relation` | `character1`/`character2` required; both characters and all `relation_tags` must be in the same universe |
| `Ownership` | `character`/`item` required; both records and all `ownership_tags` must be in the same universe |
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
- Uniqueness: **DB-enforced** only for `universes.slug`, `users.slug` and
  `stories.[universe_id, slug]`; everywhere else uniqueness is a matter of convention
  (Story validates name+slug per universe; other models don't validate slug uniqueness).
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

## Writing model (Scene core, references, grouping, tags, Elements, presence, and appearances implemented)

[ADR 0007](adr/0007-story-owned-scenes-and-elements.md) defines the first Scene model, and all of it
is in the current schema. Its first deliveries added the `scenes` and `scene_tags` tables, the
`Scene` and `SceneTag` models, the optional Section/Event/datetime references, story-scoped tag
assignment, and the story-scoped routes; the Element and Character-presence deliveries added
`scene_elements`, `scene_element_speakers`, and `scene_characters`, the `SceneElement` and
`SceneCharacter` models, and the derived participant view; the Item and Location-presence
deliveries added `scene_items`, `scene_locations`, and their two join models, and `SceneAppearances`
provided the reverse query. Every table and association below is delivered and nothing here is
speculative.

```text
Story
  ├── Scene (contiguous narrative position)
  │   ├── Section ───────────────────> optional same-Story grouping
  │   ├── Event ────────────────────> optional same-Universe in-world fact
  │   ├── SceneElement (contiguous flat position)
  │   │   └── characters (HABTM via scene_element_speakers)
  │   ├── SceneCharacter ────────────> Character   (optional role)
  │   ├── SceneItem ─────────────────> Item        (optional role)
  │   └── SceneLocation ─────────────> Location    (optional role)
  └── SceneTag (story-scoped hierarchy; optional Scene assignment via join)
```

The persisted fields and relationships are:

| Model/table | Intended fields and constraints |
|---|---|
| `scenes` | required `story_id`, required `name` (interface label **Title**), `slug`, optional `description`, indexed `position`; optional `section_id` (same Story), optional `event_id` (same Universe), and one optional `datetime` point using Event-compatible storage/editor precision and timezone semantics (not Event's `start_datetime`/`end_datetime` pair). The event reference and the datetime are independent: neither writes, clears, nor validates against the other |
| `scene_tags` | story-scoped hierarchical/colored tag shape; optional assignment only |
| `scenes_scene_tags` | story-scoped HABTM join with real FKs and a unique `[scene_id, scene_tag_id]` index; tags remain optional |
| `scene_elements` | required `scene_id`, `kind` (`narration`/`dialogue` by model validation *and* a database `check_constraint`, never a column named `type`), required `name` (interface label **Title**), optional plain-text `body` (interface label **Content**), indexed `[scene_id, position]` |
| `scene_element_speakers` | a plain many-to-many join — real FKs and a unique `[scene_element_id, character_id]` index. It carries no data of its own and records no turn order, so a HABTM association is the right shape; the same-Universe rule is checked through the Element's Scene |
| `scene_characters` | `scene_id` and `character_id` with real FKs, a unique `[scene_id, character_id]` index, and a nullable free-text `role` |
| `scene_items` | `scene_id` and `item_id` with real FKs, a unique `[scene_id, item_id]` index, and a nullable free-text `role`. Same shape as `scene_characters`; an Item is shared by every Story, so the link records that one Scene uses it rather than copying it |
| `scene_locations` | `scene_id` and `location_id` with real FKs, a unique `[scene_id, location_id]` index, and a nullable free-text `role`. Linking a Location says nothing about which nested place inside it a Scene used; that stays the author's free-text role |

The `scenes` create migration is schema-only: a real `story_id` foreign key, `null: false` `position`
with a `0` default, `null: false` `slug`, timestamps, and a composite `[story_id, position]` index.
`Scene` includes `HasSlug`, validates title presence, resolves its Universe through
`story.universe`, and has no `parent_id`: a flat narrative sequence is not a hierarchy. `Story`
declares `has_many :scenes, dependent: :destroy`; `Universe` exposes
`has_many :scenes, through: :stories` for scope checks only.

The optional references arrived in a **separate schema-only alter migration**
(`AddSceneReferencesToScenes`) because the `scenes` create migration had already shipped.
Amending an applied migration does not work in this project: Rails 8.1's `initialize_database`
loads `db/schema.rb` when a database has no `schema_migrations` table, so an edited create
migration is never executed on a freshly created database and the regenerated schema silently keeps
the old shape. The alter migration adds nullable `section_id` and `event_id` references with real
foreign keys, the nullable `datetime` column, and a `[story_id, section_id]` index beside the
existing narrative-order index.

`Scene` adds four application-level validations, because a foreign key cannot prove shared scope:
`section_belongs_to_story`, `event_belongs_to_story_universe`, `optional_references_exist` (an
unknown optional id becomes "must exist" instead of a foreign-key exception), and
`datetime_is_a_valid_point` (an unparseable value is reported instead of being silently cast to
`nil` and discarded). `Section` and `Event` each declare `has_many :scenes, dependent: :nullify`, so
deleting a Section only ungroups and deleting an Event only clears the reference; neither removes a
Scene or changes a narrative position.

`SceneTag` adds the story-scoped hierarchy, color, slug, and inverse tag association. The
`CreateSceneTags` migration is schema-only and creates both `scene_tags` and the constrained
`scenes_scene_tags` join. `Scene` declares `has_many_tags :scene_tag, scope: :story_id`; the shared
validation rejects tags from another Story, while the unique pair index and scoped association reads
keep duplicate or foreign join rows from becoming visible. Scene and Scene Tag collection-id writers
also turn unknown, duplicate, or cross-story ids into ordinary validation errors before the database
constraint can raise. `Story` cascades Scene Tag definitions; deleting a Scene or Scene Tag removes
assignments but never a shared world record.

`SectionPaths` (`app/models/section_paths.rb`) is a value object, not a table: it builds every
root-first Section path and the depth-indented selector options from one ordered Section list, so
neither the Scenes list nor the Sections workspace walks ancestors per Scene. `SceneTagPaths` is the
analogous Scene Tag value object: it builds root-first tag labels and selector choices from one
ordered tag list without walking parents per Scene.
`UniverseScopeResolver` (`app/models/universe_scope_resolver.rb`) is the shared answer to which
universe owns a record and is used by both `Ability` and the view helpers, so a Scene-owned
component can never lose its mutation controls or be denied a valid mutation.

`Relation#display_string` and `Ownership#display_string` fall back to their two endpoints because
both `name` columns are optional; `Event#display_string` already existed. A link record therefore
always has a readable label in list rows, row-action confirmations, and its details page.

`TaggedRecordCounts` (`app/models/tagged_record_counts.rb`) is a value object, not a table: it answers
"how many records carry each tag" for a whole taxonomy with one grouped query, because the
instance-dependent `HasManyTags` scopes cannot be eager loaded or grouped through Active Record. Its
result is a `tag id => count` hash used by the taxonomy rows' `(N records)` count pill. The
per-record read side is `HasManyTags#tagged_records`, the scoped inverse association ordered by name
(`none` on a content model), which is what a tag's details page lists.

`SceneParticipants` (`app/models/scene_participants.rb`) is a value object, not a table: it answers
"who takes part in this Scene" from the two independent sources the domain allows — the stored
`SceneCharacter` links and the Characters who speak in a Dialogue Element — and reports their
**union**, never their sum. A Character who both participates and speaks is one participant, and the
same object therefore backs both the Characters tab's rows and the Scenes list's per-row count. For a
list of Scenes it answers from two grouped queries for the whole page instead of one query per row.

`SceneAppearances` (`app/models/scene_appearances.rb`) is the reverse value object, not a table: it
answers "which Scenes of this Story involve this shared record, and why" from three possible
sources — a stored presence link, a derived Dialogue speaker, and an `event` reference — and reports
their **union** in Scene `position` order. It is the one read path behind the "Appears in scenes"
section on the Character, Item, Location, and Event details pages, and the same object therefore
backs the section's rows and its count. Its query count is fixed per record type, so a details page
costs the same whether a record appears in one Scene or in all of them. `LocationPaths`
(`app/models/location_paths.rb`) is a third value object in the same shape as `SectionPaths` and
`SceneTagPaths`: it turns one ordered Location list into root-first ancestor paths for the Locations
tab's rows and depth-indented picker options.

`SceneElement` is an ordered child component rather than a standalone navigable content model, so
it has no public slug requirement. `Scene.position` and `SceneElement.position` are contiguous `0..n-1` within their Story and Scene
respectively. They are not `parent_id` hierarchies and must not include `Hierarchical`. The
`PositionedResourceOrder` service supports an explicit flat mode for these sequences, and
`ScenesController` uses that mode with the Story as scope owner rather than adding a fake parent or
a second ordering algorithm. The development-data registry also distinguishes flat position groups
and loads
`SceneTag` before `Scene`, and `Scene` after `Event`, because a Scene may reference both a
story-scoped tag and a shared universe event and a symbolic reference may not point at a later model
file. The loader proves the Section and every assigned Scene Tag belong to the Scene's Story before
writing. The ordering contract is flat and transactional. A
title-only Scene is valid. A Scene's optional Event and single-point datetime are independent, and
multiple Scenes may reference one Event.

Narration Elements have no speakers. Dialogue Elements require at least one same-Universe Character
speaker; the server must reject a Dialogue-to-Narration change while speakers remain. Presence
roles are free text and are not analyzer vocabularies. All same-Story/same-Universe relationships
remain application-level validations, even when the individual foreign keys are real and indexed.
Unknown optional references become documented validation/not-found errors rather than database 500s.

The deletion contract is asymmetric: Scene-owned Elements, tag assignments, speaker links, and
presence links cascade with Scene/Story deletion; Scene Tag definitions are removed with their
Story; deleting a Section or Event clears Scene references while preserving Scene narrative order;
deleting a shared Character, Item, or Location removes its Scene links in addition to the existing
model-dependent hierarchy/relation/ownership behavior and never removes a Scene. Event retains its
existing child and temporal-referrer cleanup. The exact confirmation copy is in
[ADR 0007](adr/0007-story-owned-scenes-and-elements.md).

## Development data convention

`db/data/` is checked-in but disposable development data, organized as one directory per universe:

```text
db/data/dark/
db/data/lotr/
db/data/star_wars/
```

A new persisted model adds its data file to every universe directory where it should be exercised.
For example, a future `Dialog` model uses `db/data/dark/dialogs.yml` and, if applicable,
`db/data/lotr/dialogs.yml`; it does not get a `db/data/dialog/` feature directory. The shared
`Development::UniverseDataRegistry` order must place the model after its dependencies, and every
registered universe directory must include its file (use `[]` when intentionally unused).
References must preserve the model's universe/story scope. Universe membership data follows the
same convention (`universe_memberships.yml`) when a sample universe needs explicit private access
or delegated admin access. After any YAML add/delete/update, run
`UNIVERSE=<slug> bin/rails db:demo:check` and then reset the local development database so the files
are actually loaded; create-only `db:demo:load` is for an additional universe after that reset.

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
`db/seeds.rb`/`db/seeds/`.

Hand-maintained sketch of the core entities: [schema.txt](schema.txt).
