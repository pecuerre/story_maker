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

Schema only. The photo **contract** — the optional writers, the same-universe rule, the server-side
authority on the stored file, and the one control that serves all three page patterns — is in
[features/photos.md](features/photos.md).

A record may carry one photo, and the photo is always optional. Eighteen models include
`HasPhoto`: `Universe`, `Story`, `Section`, `Scene`, `Character`, `Location`, `Item`, `Event`,
`Relation`, `Ownership`, and the eight `*_tag` models. Each of those tables gained a nullable
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
| `users` | `email_address` (unique), `name`, `password_digest`, `slug` (unique) | `has_secure_password`; email normalized (`strip.downcase`) via `normalizes` |
| `sessions` | `user_id` FK, `ip_address`, `user_agent`, `expires_at`, `last_used_at` | created on sign-in; referenced by the signed cookie, which expires with `expires_at`. `expires_at` is the absolute deadline (never extended by use) and `last_used_at` drives the idle timeout; both are set by the model, not by a column default, because the limits are policy values. Both are nullable so a row written before the columns existed is treated as still valid rather than signing everyone out. `user_agent` is enforced (a mismatch ends the session); `ip_address` is recorded for diagnostics only |
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
`has_many_tags` and reused by `has_many_tagged`. The legacy join tables have no database integrity
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
| `Universe` | `name` and owner presence; `private` must be an explicit boolean; `slug` unique among live rows (mirrors the partial unique index, so a taken address is a field error and not a `RecordNotUnique`); slug generated by `HasSlug` |
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
  `[story_id, position]` index. The optional `section_id` and `event_id` references and the `datetime`
  column arrived in a **separate** alter migration (`AddSceneReferencesToScenes`), because the create
  migration had already shipped.
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
