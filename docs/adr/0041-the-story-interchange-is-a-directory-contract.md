# ADR 0041: The story interchange is a directory contract, not a second store

- **Status:** Accepted
- **Date:** 2026-10-28
- **Related:** [Universe and Story scope](0001-universe-and-story-scope.md), [Disposable schema and seed data](0003-disposable-schema-and-seed-data.md), [Canon rules](0039-canon-rules-are-universe-owned-with-an-optional-story.md), [Story structures](0040-story-structures-are-a-code-owned-starting-shape.md), [Story interchange](../features/story_interchange.md)

## Context

The author's `tcs` repository holds a real novel and its world as Markdown files
with YAML frontmatter. Its 2026-10-27 restructure made the ownership split
explicit: `universe/` holds what every story shares, and `stories/<story>/` holds
only that story's chapters, scenes, and plots. The canon stopped being one
`docs/canon.md` and became one file per area under `universe/canon/`, with
global, stable ids (`K##`, `L##`, `D##`, `O-*`) and Locked facts beside Open
questions.

The application can read none of it. A future importer needs a format, and a
future universe backup should write the same one, so the format has to be
settled before either slice exists. The risk is that the format becomes a second
place where the universe is stored: two copies drift, and the author cannot
tell which one the app believes.

Three questions had to be answered together: how a source names its universe and
stories without a new file, what is data and what is presentation, and how the
per-area canon files become rule records.

## Decision

- **Mirror the source tree; do not add a manifest.** A source is a directory
  containing `universe/` and `stories/`. The directory's own name is the
  universe's identity: a trailing `.git` is dropped, the rest is parameterized
  into the slug, and that slug is titleized into a default display name. Every
  directory under `stories/` is one story, named by the first `#` heading in its
  `README.md`. There is no manifest, so the source repository needs no file it
  does not already have.
- **`universe/` owns shared records.** `canon/`, `characters/`, `factions/`,
  `locations/`, and `tech/` each hold one Markdown record per file. A record's
  filename is its slug, and the slug is frozen once the file exists.
- **`stories/<story>/` owns story records.** Its `README.md` is the reading
  order, `chapters/NN-slug/NN-scene-slug.md` holds scenes, and `plots/` holds
  one plot thread per file.
- **Markdown plus YAML frontmatter.** Frontmatter carries every field that is
  not prose. The body's `##` sections are mapped to the profile answers (and, for
  a Scene, to manuscript prose); a section with no target is reported rather
  than dropped. The mapping is in the feature document.
- **Canon keeps its ledger.** `universe/canon/README.md` is the index and the
  ledger rules; each other area file is one subject. `K##`, `L##`, and `D##` are
  rules and `O-*` are open questions, whichever section they sit in. Locked,
  Derived, and Open headings are advisory placement; a misplaced id is a warning,
  not a different kind of record.
- **The story README is presentation, not data.** A Story's Scene positions and
  Section order are authoritative; the reading-order table is generated for a
  human and does not have to be imported or preserved.
- **References are graph edges.** `[[slug]]` names a universe entity or a plot,
  `[[rule:ID]]` names a canon item, `[[scene:NN-slug]]` names a scene in the
  current chapter, and `[[B-###]]` is an opaque backlog reference owned by the
  author's repository.
- **The database stays the source of truth.** The interchange is a read contract
  for import and a write contract for backup, never a second store. The
  validator reads only; the first import slice is the first code allowed to
  write records.
- **The validator is the gate.** It returns errors and warnings with counts per
  record kind, runs without writing, and is exercised only by synthetic
  fixtures. The real novel is never committed to this repository.

## Alternatives considered

- **A required `universe.yml` manifest.** Rejected by the owner on 2026-10-28:
  the source tree already names its universe and stories, and adding a manifest
  would make `tcs` change in order to be readable.
- **A normalized, app-owned directory layout.** Rejected because the source must
  open directly. A conversion step would make the author maintain two trees.
- **Importing the story README's reading order.** Rejected because Scene
  positions already carry the order; a second copy would drift silently.
- **Keeping one `canon.md`.** Rejected because the source split it per area, and
  recombining it would lose the area index and make a large file the merge
  point for every canon change.

## Consequences

### Benefits

- The author's repository is the format. No new file, no export step, and no
  conversion is required before an import.
- The validator can run against the real source without touching it, so a
  layout mistake is found before an import writes anything.
- One tree can name many stories, which matches the application's
  universe-owned world building and story-owned scripts.
- A backup writes the same tree the importer reads, so round-trip fidelity is a
  testable property rather than a second format.

### Costs and constraints

- The source directory name is the universe slug. Renaming the folder changes
  the identity, so the import page must show it before it writes; the display
  name can be edited in the application afterwards.
- `.git` is stripped and the rest parameterized, so `tcs.git` becomes `tcs`, and
  a folder with no letters or digits is refused.
- The layout accepts more than the application can store. A recognized field or
  section with no target is reported, which is honest but means an import can
  be lossy until later slices add the target.
- The source may carry warnings (a locked rule under Open, an unknown
  frontmatter key). A warning does not block an import; only an error does.
