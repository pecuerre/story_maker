# Universe backup

A Universe backup is one downloadable `.tar.gz` containing a Universe's core data, its stored photo
files, and a human-readable projection in the story-interchange shape. It is the safety net the
printable [Story export](exports.md) is not: the export reads one Story as a book, while a backup
copies the data behind every Story.

The format decision and its alternatives are in
[ADR 0042](../adr/0042-a-universe-backup-is-a-core-data-archive.md). This document owns the archive
contract, the admin gate, and what the first slice deliberately leaves out. Restore is not implemented.

## What a backup is

The archive has three parts, and **only the first is authoritative**:

| Path | Contents | Role |
|---|---|---|
| `data/` | one YAML file per table, plus every HABTM join table | the lossless copy a restore will read |
| `photos/` | the stored 300×300 files named by `data/photos.yml` | the photo bytes |
| `content/` | a Markdown projection in the story-interchange shape | for a human reader |

`backup.yml` names the format version, generation time, Universe identity, record counts, the list of
deferred tables, and any photo row whose file was missing. `README.md` explains the same contents and
the restore boundary inside the archive, so the archive is understandable without this repository.

The data dump keeps the application's own columns, foreign-key ids, and soft-deleted core rows. It
does not translate references to slugs: a restore has to remap ids, and a second reference language
would make the backup disagree with the database it copies.

## Who may download it

| Purpose | Canonical URL |
|---|---|
| Backup page | `/u/:universe_slug/backup` |
| Archive download | `/u/:universe_slug/backup/download` |

**Both actions ask for `admin` on the Universe**, through the same `UniverseAuthorization` line as
memberships, the reviewer queue, and the change history. A backup is not one page's read: it carries
the whole core dataset. A plain writer receives `403`; a guest is sent to sign in, and a signed-in
non-member of a private Universe receives `404`. The page links from **Backup** beside **Members** in
the right sidebar's Configuration group, for admins only.

The download is a `GET` that writes nothing. It carries `Cache-Control: no-store`, and the archive is
assembled in memory from the database and Active Storage. There is no stored backup record.

## The data dump

`UniverseBackup::DataDump` writes one YAML file per table and one per join table. A record is a hash
of its own columns; `created_at` and `updated_at` are ISO 8601 strings, and a `json` column stays a
hash. Soft-deleted core records are included with their `deleted_at`, because a restore should be able
to rebuild the Universe as it was, not only its live view.

The dump covers the core records:

- the Universe itself and its Stories;
- canon rules;
- every tag taxonomy (character, faction, location, item, event, relation, ownership, section, and
  scene tags);
- Characters and their knowledge records; Factions and faction relationships; Locations, Routes,
  Items, and Ownerships; Relations; Events;
- Sections, Plots, Story and Scene tropes, Scenes, Scene Elements, Dialogue turns, and every Scene
  presence and Event link;
- discussions and their messages;
- photos and their file metadata.

The join tables are `characters_character_tags`, `characters_factions`, `events_event_tags`,
`factions_faction_tags`, `items_item_tags`, `locations_location_tags`, `ownerships_ownership_tags`,
`plots_scenes`, `relations_relation_tags`, `scene_element_speakers`, `scenes_scene_tags`, and
`sections_section_tags`.

## The content projection

`UniverseBackup::ContentProjection` writes the same records the
[story interchange](story_interchange.md) can describe as Markdown: canon rules, Characters,
Factions, Locations, Items, Stories, chapters and Scenes, and Plots. It exists so a reader can open the
archive without a database and so a future round trip has a starting point.

**It is not import-ready.** The database does not store every field the interchange layout asks for: a
Character has no `role` or `status`, a Plot has no `type` or `owner_pov`, a Scene has no `branch`, and
a Canon Rule has neither an area nor a source-repository id. The projection writes `— TBD` for a
missing field and uses the application's numeric rule id as `K<id>`, which is not an id from the
author's source repository. It therefore deliberately does not promise to pass
`StoryInterchange::Validator`; `data/` is the copy that must not be lossy.

The projection also flattens what the layout cannot express: a Section hierarchy becomes one chapter
per Section, a Scene's prose becomes one block per Element in reading order, and tags, routes, tropes,
events, relations, ownerships, and discussions stay only in the data dump. Photo files stay in
`photos/`.

## What is deferred

This slice is the core data. It deliberately leaves out:

- users and Universe memberships;
- drafts, their changes, their stored outcomes, and review requests;
- notifications;
- API tokens and their Universe links.

Those rows carry identity, access, or somebody else's unfinished work, and they need their own privacy
and authorization decision rather than riding along with a content backup. Their table names are in
`backup.yml` under `deferred_tables`, so an archive is never mistaken for a complete copy. The core
dump contains no password or token; those columns live only in the deferred tables.

## Restore is not implemented

The archive is the first half. Restore is a separate, destructive command that needs explicit
confirmation, must refuse a production run without it, and must never reuse the development-data
reset path. It also has to remap numeric ids and decide how a deferred table that is absent from an
older archive is treated. Nothing in this slice restores anything.

## Backup files

- `app/services/universe_backup/archive.rb` — the `.tar.gz` writer and the manifest and README
- `app/services/universe_backup/data_dump.rb` — the table and join dump, and the photo files
- `app/services/universe_backup/content_projection.rb` — the Markdown projection
- `app/controllers/universe_backups_controller.rb`, `app/views/universe_backups/`
- `test/services/universe_backup/archive_test.rb`,
  `test/controllers/universe_backups_controller_test.rb`
