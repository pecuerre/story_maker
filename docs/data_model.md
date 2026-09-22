# Data Model

Everything about the schema: tables, ownership/scoping rules, tag taxonomy matrix, validations
and the slug system. Verified against `db/schema.rb` (SQLite, schema version
`2026_09_23_000000`) and the models in `app/models/`.

## Ownership graph

```
User (owner)
 └── Universe  (1..n stories; everything below is scoped to exactly one universe)
      ├── Story ── Section ──> Section's parent Section (tree)
      │                          └── HABTM SectionTag        ← tags stay universe-wide
      ├── SectionTag (tree, universe-wide)
      ├── Character ──> parent Character   ── HABTM CharacterTag (tree)
      ├── Location  ──> parent Location    ── HABTM LocationTag  (tree)
      ├── Item      ──> parent Item        ── HABTM ItemTag      (tree)
      ├── Event     ──> parent Event, before/after/simultaneous Event ── HABTM EventTag (tree, optional)
      ├── Relation  (character1 × character2) ── HABTM RelationTag (tree)
      ├── Ownership (character × item, dated) ── HABTM OwnershipTag (tree)
      └── (Session belongs to User, unrelated to universes)
```

**The one rule to remember:** world building (characters, locations, items, events, relations,
ownerships **and every `_tag` model, including SectionTag**) belongs to the **universe** and is
shared by all of its stories. Only **sections** (the script: books → chapters → scenes …) belong
to a **story**.

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
| `sections` | `story_id` FK (NOT NULL), `name`, `description`, `slug`, `parent_id` self-FK, `position` (default 0) | `universe_id` was **removed** by migration `20260923000000_move_sections_to_stories` (existing rows were backfilled into a per-universe default story named *"Main story"*) |
| `section_tags` | tag columns (below), `universe_id` | universe-wide on purpose: chapter/book/episode labels are reusable across stories |

### Tag tables (`*_tags`) — all identical shape
`name`, `description`, `slug`, `parent_id` (self-FK), `position` (default 0),
`bgcolor` (default `#d3d3d3`), `fgcolor` (default `#000000`), `universe_id` FK.
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
| Section | `:section_tag` | `sections_section_tags` | yes |
| Character | `:character_tag` | `characters_character_tags` | yes |
| Location | `:location_tag` | `locations_location_tags` | yes |
| Item | `:item_tag` | `items_item_tags` | yes |
| **Event** | `:event_tag` | `events_event_tags` | **no** (`required: false`) |
| Relation | `:relation_tag` | `relations_relation_tags` | yes |
| Ownership | `:ownership_tag` | `ownerships_ownership_tags` | yes |
| Story / Universe / User | — | — | — |

Every content controller auto-assigns a default tag on create when none was chosen
(`...first.id if tags.empty?` — raises if the universe has no tags yet, see
[known_quirks.md](known_quirks.md)).

## Hierarchies & positions

Models including the `Hierarchical` concern (own `parent_id` self-FK + `children` +
`position`): **Section, SectionTag, Character, CharacterTag, Location, LocationTag, Item,
ItemTag, Event, EventTag, RelationTag, OwnershipTag**.

Validations added by the concern:
1. parent must be in the **same owning scope** — same `universe_id` by default,
   same `story_id` for Section (`hierarchy_scope*` overrides);
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
| `Universe` | *(none — name may be blank; slug generated by `HasSlug`)* |
| `Story` | `name` presence + unique per universe; `slug` unique per universe |
| `Section` | `name` presence; `story` required; parent rules scoped to the story; `section_tags` presence |
| `Character` / `Location` / `Item` | `name` presence; `*_tags` presence; `Hierarchical` rules |
| `_tag` models | `name` presence; `bgcolor`/`fgcolor` must be `#rrggbb` (`HasColor`); `Hierarchical` rules; `relation_tags` also requires `inverse` unless `symmetric` |
| `Event` | `must_be_identifiable` (title **or** start/end datetime **or** a before/after/simultaneous relation); referenced events must be in the same universe; no self references; `event_tags` optional; `Hierarchical` rules; *no* name-presence rule |
| `Relation` | `character1`/`character2` required; both characters and all `relation_tags` must be in the same universe; `relation_tags` presence |
| `Ownership` | `character`/`item` required; both records and all `ownership_tags` must be in the same universe; `ownership_tags` presence |
| `User` | `has_secure_password` (password confirmation on create); unique normalized email (DB unique index) |
| `Session` | `user` required |

Cross-universe checks are **application-level only** (the DB cannot express them); several
same-scope checks (e.g. "parent in same story") have no DB constraint either — only the FKs in
`db/schema.rb` are enforced by SQLite.

## Slugs

- `HasSlug` (app/models/concerns/has_slug.rb): `before_validation :set_slug`.
  Priority: explicit `slug` → slugified `name` (when name changed) → existing name →
  `SecureRandom.hex(4)`.
- `slugify` = `parameterize` + `_+ → -`. **Write slugs dash-separated**; the class-level finder
  `Model.some_name` (custom `method_missing`) also slugifies its argument, so underscores in
  stored slugs (only in fixtures) are not reachable that way.
- Uniqueness: **DB-enforced** only for `universes.slug`, `users.slug` and
  `stories.[universe_id, slug]`; everywhere else uniqueness is a matter of convention
  (Story validates name+slug per universe; other models don't validate slug uniqueness).
- `Relation`/`Ownership` additionally define `before_validation :generate_slug` intending a
  `character-tag-character` slug when name is blank — see
  [known_quirks.md](known_quirks.md) (likely unreachable: `HasSlug` already set a random slug).

## Stories vs world building (why the split exists)

One universe can host several stories that share the same world (e.g. *A Song of Ice and Fire*
hosts *Game of Thrones* and *House of the Dragon*): characters/relations/locations/events/items
are defined once per universe, while each story has its own section tree (its plot/scenes).
Sections moved from `universe_id` to `story_id` in migration
`db/migrate/20260923000000_move_sections_to_stories.rb`, which also added `stories.slug` and
backfilled every existing section into a per-universe default story. The old
`/u/<slug>/sections` route no longer exists — sections are only reachable under a story
(`/u/<slug>/stories/<story_id>/sections`).

Hand-maintained sketch of the core entities: [schema.txt](schema.txt).
