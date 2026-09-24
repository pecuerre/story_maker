# Data Model

Everything about the schema: tables, ownership/scoping rules, tag taxonomy matrix, validations
and the slug system. Verified against `db/schema.rb` (SQLite, schema version
`2026_09_23_130018`) and the models in `app/models/`.

## Ownership graph

```
User (owner)
 └── Universe  (1..n stories; everything below is scoped to exactly one universe)
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

## Tables

### Identity & tenancy
| Table | Columns (beyond timestamps) | Notes |
|---|---|---|
| `users` | `email_address` (unique), `name`, `password_digest`, `slug` (unique) | `has_secure_password`; email normalized (`strip.downcase`) via `normalizes` |
| `sessions` | `user_id` FK, `ip_address`, `user_agent` | created on sign-in; referenced by the signed cookie |
| `universes` | `name`, `owner_id` FK→users, `private` (bool, default `false`), `slug` (unique) | `visible_to(user)` scope = public OR owned |

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
`has_many_tags` and reused by `has_many_tagd`.

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

Ordering: `position` defaults to 0; `MaintainsSiblingPositions` (controller concern) keeps
positions as contiguous 0..n-1 among siblings — `sibling_count` when creating,
`update_with_sibling_position` for moves (reorders the old and new parent's children), using the
model's `sibling_scope`. Drag & drop in the tree UI sends `{ position: n }` patches.

Not hierarchical: **Relation**, **Ownership** (link records), **Story**, **Universe**, **User**,
**Session**.

## Validations & invariants (per model)

| Model | Validations |
|---|---|
| `Universe` | `name` presence; slug generated by `HasSlug` |
| `Story` | `name` presence + unique per universe; `slug` unique per universe |
| `Section` | `name` presence; `story` required; parent rules scoped to the story; `section_tags` optional, but when present they must all belong to the section's story |
| `Character` / `Location` / `Item` | `name` presence; `*_tags` optional; `Hierarchical` rules |
| `_tag` models | `name` presence; `bgcolor`/`fgcolor` must be `#rrggbb` (`HasColor`); `Hierarchical` rules (for `SectionTag` the parent must share the **story**); `relation_tags` also requires `inverse` unless `symmetric` |
| `Event` | `must_be_identifiable` (title **or** start/end datetime **or** a before/after/simultaneous relation); referenced events must be in the same universe; no self references; `Hierarchical` rules; *no* name-presence rule |
| `Relation` | `character1`/`character2` required; both characters and all `relation_tags` must be in the same universe |
| `Ownership` | `character`/`item` required; both records and all `ownership_tags` must be in the same universe |
| `User` | `has_secure_password` (password confirmation on create); unique normalized email (DB unique index) |
| `Session` | `user` required |

Cross-universe checks are **application-level only** (the DB cannot express them); several
same-scope checks (e.g. "parent in same story", "section tags of the same story") have no DB
constraint either — only the FKs in `db/schema.rb` are enforced by SQLite.

## Slugs

- `HasSlug` (app/models/concerns/has_slug.rb): `before_validation :set_slug`.
  Priority: explicit `slug` → slugified `name` (when name changed) → existing name →
  `SecureRandom.hex(4)`.
- `slugify` = `parameterize` + `_+ → -`. **Write slugs dash-separated**, including fixture
  slugs; the class-level finder `Model.some_name` (custom `method_missing`) also slugifies its
  argument, so underscore-separated fixture labels are not the stored slug format.
- Uniqueness: **DB-enforced** only for `universes.slug`, `users.slug` and
  `stories.[universe_id, slug]`; everywhere else uniqueness is a matter of convention
  (Story validates name+slug per universe; other models don't validate slug uniqueness).
- `Relation`/`Ownership` additionally define `before_validation :generate_slug` intending a
  `character-tag-character` slug when name is blank — see
  [known_quirks.md](known_quirks.md) (usually unreachable: `HasSlug` already set a random slug;
  only reached when `name` was assigned but is blank).
  Since tags are optional, the tag segment is simply omitted for an untagged record
  (`character-character`), falling back to a random hex slug when nothing is left to join.

## Stories vs world building (why the split exists)

One universe can host several stories that share the same world (e.g. *A Song of Ice and Fire*
hosts *Game of Thrones* and *House of the Dragon*): characters/relations/locations/events/items
are defined once per universe, while each story has its own section tree (its plot/scenes) and
its own section tags (chapter/book/episode labels). This ownership split is defined directly by
the schema-only create migrations: `stories` owns its slug, and `sections` and `section_tags`
reference `stories`. Data is disposable and reconstructed from the files under `db/data/`; it is
not backfilled by migrations. Section tags and sections are reachable only under the explicit story
path (`/u/<slug>/s/<story_id>/section_tags` and `/u/<slug>/s/<story_id>/sections`). The
universe-level `/u/<slug>/section_tags` and `/u/<slug>/sections` routes are intentionally invalid.

Hand-maintained sketch of the core entities: [schema.txt](schema.txt).
