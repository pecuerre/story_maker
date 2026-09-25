# Data Model

Everything about the schema: tables, ownership/scoping rules, tag taxonomy matrix, validations
and the slug system. Verified against `db/schema.rb` (SQLite, schema version
`2026_09_24_130100`) and the models in `app/models/`.

## Ownership graph

```
User (owner)
 └── Universe  (1..n stories; everything below is scoped to exactly one universe)
      ├── UniverseMembership ──> User (read/write/admin)
      ├── Story ── Section ──> Section's parent Section (tree)
      │   │                     └── HABTM SectionTag ──┐
      │   └── SectionTag (tree, story-scoped) ←────────┘
      ├── Character ──> parent Character   ── HABTM CharacterTag (tree)
      ├── Location  ──> parent Location    ── HABTM LocationTag  (tree)
      ├── Item      ──> parent Item        ── HABTM ItemTag      (tree)
      ├── Event     ──> parent Event, before/after/simultaneous Event ── HABTM EventTag (tree, optional)
      ├── Relation  (character1 × character2) ── HABTM RelationTag (tree)
      ├── Ownership (character × item, dated) ── HABTM OwnershipTag (tree)
      └── (Session belongs to User, unrelated to universes)
```

**The one rule to remember:** world building (characters, locations, items, events, relations,
ownerships **and every `_tag` model except SectionTag**) belongs to the **universe** and is
shared by all of its stories. Only **sections** (the script: books → chapters → scenes …) and
their **section tags** (chapter/book/episode labels) belong to a **story** — each story owns its
own section taxonomy.

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
| `stories` | `universe_id` FK (NOT NULL), `name`, `description`, `slug` (NOT NULL) | unique index on `[universe_id, slug]` |
| `sections` | `story_id` FK (NOT NULL), `name`, `description`, `slug`, `parent_id` self-FK, `position` (default 0) | sections belong directly to a story |
| `section_tags` | tag columns (below), `story_id` (NOT NULL) | story-scoped: each story owns its chapter/book/episode labels |

### Tag tables (`*_tags`) — all identical shape
`name`, `description`, `slug`, `parent_id` (self-FK), `position` (default 0),
`bgcolor` (default `#d3d3d3`), `fgcolor` (default `#000000`), `universe_id` FK —
**except `section_tags`, which has `story_id` instead of `universe_id`**.
`relation_tags` additionally has `symmetric` (bool, default `true`) and `inverse` (string).

Tag models: `character_tags`, `location_tags`, `item_tags`, `section_tags`, `event_tags`,
`relation_tags`, `ownership_tags`.

### Content tables
| Table | Columns | Notes |
|---|---|---|
| `characters` | `name`, `description`, `slug`, `parent_id`, `position`, `universe_id` | |
| `locations` | same shape | |
| `items` | same shape | |
| `events` | `title`, `name`, `description`, `slug`, `start_datetime`, `end_datetime`, `before_event_id`, `after_event_id`, `simultaneous_event_id` (all self-FKs), `parent_id`, `position`, `universe_id` | identity is title-driven |
| `relations` | `character1_id`, `character2_id` (NOT NULL FKs), `name` (optional), `description`, `from_date`, `to_date`, `slug`, `universe_id` | **no** `parent_id`, **no** `position` |
| `ownerships` | `character_id`, `item_id` (NOT NULL FKs), `name` (optional), `description`, `from_date`, `to_date`, `slug`, `universe_id` | **no** `parent_id`, **no** `position` |

### HABTM join tables (no PK, two integer columns)
`characters_character_tags`, `locations_location_tags`, `items_item_tags`,
`sections_section_tags`, `events_event_tags`, `relations_relation_tags`,
`ownerships_ownership_tags` — pattern `"<content table>_<tag table>"`, declared by
`has_many_tags` and reused by `has_many_tagd`. Every declaration supplies an explicit shared
scope (`:universe_id`, or `:story_id` for Section/SectionTag), and both sides of each association
validate every assigned member against that scope. Association reads also apply the scope, hiding
foreign rows even if a raw/import path has already inserted a corrupt join.

### Non-app tables
`solid_cache` / `solid_cable` / `solid_queue` live in their own schema files
(`db/cache_schema.rb`, `db/cable_schema.rb`, `db/queue_schema.rb`).

## Tag taxonomy matrix

| Content model | Tag model (`has_many_tags`) | Join table | Tag required? |
|---|---|---|---|
| Section | `:section_tag` | `sections_section_tags` | **no** |
| Character | `:character_tag` | `characters_character_tags` | **no** |
| Location | `:location_tag` | `locations_location_tags` | **no** |
| Item | `:item_tag` | `items_item_tags` | **no** |
| **Event** | `:event_tag` | `events_event_tags` | **no** |
| Relation | `:relation_tag` | `relations_relation_tags` | **no** |
| Ownership | `:ownership_tag` | `ownerships_ownership_tags` | **no** |
| Story / Universe / User | — | — | — |

Tags are **optional on every content model**: `has_many_tags` declares only the HABTM (no
presence validation), and no controller force-assigns a default tag — creating a character,
location, item, section, relation or ownership without picking a tag simply saves it untagged.
A simple story therefore works without any taxonomy: add a few characters, locations, sections,
etc. and tag them later (or never). Deleting a tag just leaves its records untagged; they stay
valid.

## Hierarchies & positions

Models including the `Hierarchical` concern (own `parent_id` self-FK + `children` +
`position`): **Section, SectionTag, Character, CharacterTag, Location, LocationTag, Item,
ItemTag, Event, EventTag, RelationTag, OwnershipTag**.

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

Not hierarchical: **Relation**, **Ownership** (link records), **Story**, **Universe**, **User**,
**Session**.

## Validations & invariants (per model)

| Model | Validations |
|---|---|
| `Universe` | `name` and owner presence; `private` must be an explicit boolean; slug generated by `HasSlug` |
| `UniverseMembership` | user/universe presence; access level in read/write/admin; unique user per universe; owner cannot be a separate member |
| `Story` | `name` presence + unique per universe; `slug` unique per universe |
| `Section` | `name` presence; `story` required; parent rules scoped to the story; `section_tags` optional, but when present they must all belong to the section's story through the shared HABTM scope |
| `Character` / `Location` / `Item` | `name` presence; `*_tags` optional and, when present, all belong to the content's universe; `Hierarchical` rules |
| `_tag` models | `name` presence; `bgcolor`/`fgcolor` must be `#rrggbb` (`HasColor`); `Hierarchical` rules (for `SectionTag` the parent must share the **story**); `relation_tags` also requires `inverse` unless `symmetric` |
| `Event` | `must_be_identifiable` (title **or** start/end datetime **or** a before/after/simultaneous relation); referenced events must be in the same universe; model validation and three DB check constraints reject self references (including unsaved/future IDs); `Hierarchical` rules; *no* name-presence rule. Destroying an event nullifies all incoming temporal references; a relation-only referrer that would become unidentifiable is destroyed first |
| `Relation` | `character1`/`character2` required; both characters and all `relation_tags` must be in the same universe |
| `Ownership` | `character`/`item` required; both records and all `ownership_tags` must be in the same universe |
| `User` | `has_secure_password` (password confirmation on create); unique normalized email (DB unique index) |
| `Session` | `user` required |

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
the schema-only create migrations: `stories` owns its slug, and `sections`, `section_tags`, and
`scenes` reference `stories`. Data is disposable and reconstructed from the per-universe directories under
`db/data/`; it is not backfilled by migrations. Section tags, sections, and scenes are reachable
only under
the explicit story path (`/u/<slug>/s/<story_id>/section_tags`,
`/u/<slug>/s/<story_id>/sections`, and `/u/<slug>/s/<story_id>/scenes`). The universe-level
`/u/<slug>/section_tags`, `/u/<slug>/sections`, and `/u/<slug>/scenes` routes are intentionally
invalid.

## Writing model (Scene core implemented; later slices pending)

[ADR 0007](adr/0007-story-owned-scenes-and-elements.md) defines the first Scene model. Slice 11.1
has landed the `scenes` table, the `Scene` model, and the story-scoped routes; the remaining
tables, associations, and validations below belong to slices 11.2–11.10 and are **not** in the
current schema yet.

```text
Story
  ├── Scene (contiguous narrative position)          # implemented in 11.1
  │   ├── SceneElement (contiguous flat position)     # planned
  │   │   └── SceneElementSpeaker ──> Character
  │   ├── SceneCharacter ────────────> Character   (optional role)
  │   ├── SceneItem ─────────────────> Item        (optional role)
  │   ├── SceneLocation ─────────────> Location    (optional role)
  │   ├── Section ───────────────────> optional same-Story grouping
  │   └── Event ────────────────────> optional same-Universe in-world fact
  └── SceneTag (story-scoped hierarchy; Scene assignment via join)
```

The intended persisted fields and relationships are:

| Model/table | Intended fields and constraints |
|---|---|
| `scenes` | **implemented in 11.1**: required `story_id`, required `name` (interface label **Title**), `slug`, optional `description`, indexed `position`. The optional same-Story `section_id`, optional same-Universe `event_id`, and one optional `datetime` point using Event-compatible storage/editor precision and timezone semantics (not Event's `start_datetime`/`end_datetime` pair) arrive in 11.2 |
| `scene_tags` | story-scoped hierarchical/colored tag shape; optional assignment only (11.4) |
| `scenes_scene_tags` | story-scoped HABTM join; tags remain optional (11.4) |
| `scene_elements` | required `scene_id`, `kind` (`narration`/`dialogue`, never a column named `type`), required `name` (interface label **Title**), optional plain-text `body`, indexed `position` (11.6) |
| `scene_element_speakers` | SceneElement-to-Character links with a unique pair; the same Universe rule is checked through the Element's Scene (11.6) |
| `scene_characters` | unique `[scene_id, character_id]`, nullable free-text `role` (11.7) |
| `scene_items` | unique `[scene_id, item_id]`, nullable free-text `role` (11.8) |
| `scene_locations` | unique `[scene_id, location_id]`, nullable free-text `role` (11.9) |

The `scenes` migration is schema-only: a real `story_id` foreign key, `null: false` `position`
with a `0` default, `null: false` `slug`, timestamps, and a composite `[story_id, position]`
index. `Scene` includes `HasSlug`, validates title presence, resolves its Universe through
`story.universe`, and has no `parent_id`: a flat narrative sequence is not a hierarchy. `Story`
declares `has_many :scenes, dependent: :destroy`; `Universe` exposes
`has_many :scenes, through: :stories` for scope checks only.

`SceneElement` is an ordered child component rather than a standalone navigable content model, so
it has no public slug requirement. `Scene.position` and `SceneElement.position` are contiguous `0..n-1` within their Story and Scene
respectively. They are not `parent_id` hierarchies and must not include `Hierarchical`. The
`PositionedResourceOrder` service supports an explicit flat mode for these sequences; slice 11.1
uses that mode with the Story as scope owner rather than adding a fake parent or a second
ordering algorithm. The development-data registry also distinguishes flat position groups. The
ordering contract is flat and transactional. A title-only Scene is
valid. A Scene's optional Event and single-point datetime are independent, and multiple Scenes may
reference one Event.

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
Records made only in the UI are intentionally lost and are not merged back into YAML. Neither
`db:seed` nor `db:prepare` loads `db/data/`. Development data is for browser/manual validation only;
automated tests use `test/fixtures/`, and production bootstrap data belongs in
`db/seeds.rb`/`db/seeds/`.

Hand-maintained sketch of the core entities: [schema.txt](schema.txt).
