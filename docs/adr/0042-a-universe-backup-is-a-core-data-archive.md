# ADR 0042: A Universe backup is a core-data archive, and the first slice is not the whole universe

- **Status:** Accepted
- **Date:** 2026-10-29
- **Related:** [Universe and Story scope](0001-universe-and-story-scope.md), [Canon rules](0039-canon-rules-are-universe-owned-with-an-optional-story.md), [Story interchange](0041-the-story-interchange-is-a-directory-contract.md), [Universe backup](../features/universe_backup.md)

## Context

The printable export reads one Story as a book. It is not a safety net for the Universe behind the
Story: tags, routes, tropes, events, relations, ownerships, photos, memberships, and change history
have no download. The author already pushes manuscripts and outlines to another service, and wants a
copy of the application's own data that is not the database file.

Two things had to be settled before a download existed. What is the archive's authoritative content,
and who may take it? The interchange layout of ADR 0041 describes story content in a readable tree,
but the database does not store every field that layout asks for — a Character has no role or status,
a Plot has no type or owner POV, a Scene has no branch, and a Canon Rule has no area or source id. A
backup that claimed to be an interchange source would therefore be lossy in exactly the places a
restore cannot afford.

The archive also carries rows a plain writer has no page for: the whole core dataset, and later the
memberships and change history. That is an access question before it is a formatting question.

## Decision

- **The lossless data dump is authoritative.** One YAML file per table and per HABTM join table, with
  the application's own columns, foreign-key ids, timestamps as ISO 8601 strings, and soft-deleted core
  rows. Restore will remap ids; the archive does not invent a second reference language.
- **The interchange tree is a projection, not the backup.** `content/` writes the layout's shape for
  readability and a future round trip. It writes `— TBD` for fields the application does not store,
  uses the application's numeric rule id as `K<id>`, and is explicitly not promised to pass
  `StoryInterchange::Validator`. The feature document states the gaps.
- **The archive is a `.tar.gz` built with the Ruby standard library.** No new dependency: RubyGems'
  `Gem::Package::TarWriter` and `Zlib::GzipWriter` write it, and the controller serves it in memory
  with `send_data`. A `.zip` would need a production dependency the application does not otherwise
  have.
- **Photos are files beside metadata.** `data/photos.yml` carries each photo's row and file path;
  `photos/` carries the stored 300×300 bytes. A photo whose attachment is missing is named in the
  manifest rather than silently skipped.
- **Both the page and the download ask for `admin` on the Universe.** A backup is the whole core
  dataset, not one page's read, so it uses the memberships, review-queue, and history gate. The
  download is a `GET` that writes nothing and carries `Cache-Control: no-store`.
- **This slice is core data only.** Users, memberships, drafts and their change history, review
  requests, notifications, and API tokens are deferred. Their table names are in the manifest so the
  archive is never mistaken for a complete copy. Their slice owns the privacy decision.
- **Restore is not part of this decision.** It remains a separate destructive command with explicit
  confirmation, and it must not reuse the development-data reset path.

## Alternatives considered

- **Export the database file.** Rejected: it is opaque, SQLite-specific, and not an interchange
  document a reader can inspect. A restore would also restore every credential and unrelated table.
- **Write only the interchange tree.** Rejected because the layout cannot represent tags, routes,
  tropes, events, relations, ownerships, photos, or the rows whose fields the application does not
  store. It would look like a backup and not be one.
- **Write only the development-data YAML manifests.** Rejected: the loader's symbolic reference
  language is a write-time convenience, and a backup should not depend on a development-only
  loader's assumptions. The neutral table dump preserves what exists without pretending to be a
  re-import already.
- **One archive containing identity, access, and history now.** Deferred by the owner on 2026-10-28.
  The core data is useful on its own, and the sensitive rows need their own decision rather than
  riding along.
- **A `rubyzip` dependency for a `.zip`.** Rejected because `.tar.gz` is standard-library work and
  the dependency is not otherwise a production one.

## Consequences

### Benefits

- The archive is a real safety net for the content the application owns, not a rendering of one
  Story.
- A reader can inspect the projection without a database, while a restore has a complete table copy.
- The admin gate and the deferred list make the scope honest: an archive says what it does not carry.
- No new gem, no background job, and no persisted export row.

### Costs and constraints

- The archive is assembled in memory, so a Universe with a very large photo set costs request memory.
  The core-data slice accepts that; a later slice can stream it or move it to a job.
- The content projection is not import-ready and must not be presented as the backup.
- Restore will have to remap ids and decide what to do with tables that an older archive lacks.
- A backup is a point-in-time copy with no checksum of the database as a whole; `backup.yml` lists
  counts and missing photo files, not a byte-level verification of every row.
