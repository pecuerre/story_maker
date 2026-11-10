# Story interchange

A **story interchange source** is a directory of Markdown files that describes one Universe and any
number of its Stories. It is the format the author's `tcs` repository already uses, the contract a
future import reads, and the contract a future Universe backup writes.

The ownership decision is [ADR 0041](../adr/0041-the-story-interchange-is-a-directory-contract.md),
the import decision is
[ADR 0043](../adr/0043-a-story-interchange-import-replaces-one-universe.md), and the code is
`StoryInterchange` in `lib/story_interchange/`. This document owns the directory layout, the
frontmatter, the section-to-profile mapping, the reference forms, what the validator reports, and
what an import writes. It is **not** a second storage format: the database stays the source of truth,
and the source is read in place and never modified.

The app's code-owned starting shapes are a different subject: [Story structures](story_structures.md).

## A source is a directory

The source root contains exactly two trees. Its other entries — `docs/`, `.git/`, `AGENTS.md` — are
repository process, not interchange data, and are ignored.

```
<source>/
  universe/
    README.md                the universe's name and the shared conventions
    canon/
      README.md              the ledger rules and area index
      <area>.md              one canon area: Locked facts and Open questions
    characters/
      README.md              folder guide
      <slug>.md
    factions/                README.md and <slug>.md
    locations/               README.md and <slug>.md
    tech/                    README.md and <slug>.md
    inspirations.md          authoring guidance — read by nobody, reported
  stories/
    README.md                optional human index of the stories
    <story>/
      README.md              the reading order and the story's name
      chapters/
        README.md            how chapters and scenes are numbered
        NN-chapter/
          README.md          the chapter's frontmatter record and its documentation
          NN-scene.md
      plots/
        README.md            the plot-thread index
        <slug>.md
```

`universe/` holds every record every Story shares. `stories/<story>/` holds only what that Story
owns: its chapters and scenes, its Plot threads, and its reading order. Prose never lives in
`universe/`, and a shared entity never lives inside a Story directory.

A file whose name starts with `.` is ignored, so `.gitkeep` may keep an empty directory in version
control. Only `.md` files are read.

**A `README.md` is documentation at every depth.** It describes its directory for a human and is
never a record, so the validator skips it rather than reporting a missing frontmatter block or
parsing its examples as references. The Universe's and the Story's READMEs are still read for the
one fact each owns: their display name. A chapter README is read for its Section as well, as
described under [Story records](#story-records). Only the chapter README's YAML frontmatter is a
record; its body stays documentation.

## Identity without a manifest

There is no manifest. The tree itself names its universe and stories:

- **Universe slug** — the source directory's basename, with a trailing `.git` removed and the rest
  parameterized (`The Fifth Cabinet.git` → `the-fifth-cabinet`, `tcs.git` → `tcs`). A name with no
  letters or digits is refused.
- **Universe display name** — the first `#` heading in `universe/README.md` when it has one
  (`# Meridian` → `Meridian`), otherwise the slug titleized. It is a default; the Universe's name
  can be edited in the application after an import.
- **Story slug** — each directory directly under `stories/`.
- **Story name** — the first `#` heading in that Story's `README.md`.

Renaming the source root therefore changes the universe's identity. An import must show the derived
slug before it writes.

## Universe records

Each entity directory holds one record per Markdown file, and the filename without `.md` is the
record's slug:

| Directory | Record |
|---|---|
| `universe/characters/` | Character |
| `universe/factions/` | Faction |
| `universe/locations/` | Location |
| `universe/tech/` | Item |

A slug is frozen once its file exists. Slugs are unique across all four entity directories and
`stories/<story>/plots/`, because a bare `[[slug]]` must resolve without a type.

`universe/canon/README.md` is required. It holds the ledger rules and the area index; it is
documentation, so it is not parsed as one of the areas. Every other Markdown file in
`universe/canon/` is one area of canon.

A file directly under `universe/` that is not the README, the canon directory, or one of the four
entity directories has no record kind — `universe/inspirations.md` is the real example, authoring
guidance with no table behind it. It is reported as a warning and never read, so the import cannot
turn it into a record by accident.

## Story records

- `stories/<story>/README.md` is required. Its first `#` heading is the Story's name. Its reading
  order is presentation: **Scene positions and Section order are the data**, and the table is
  regenerated for a human rather than imported as a second source of order. The prose has no Story
  column to fill, so only the heading and the directory slug become the Story record.
- `stories/<story>/chapters/` is optional. Each child is a chapter directory `NN-slug`, and each
  child of that is a scene file `NN-slug.md`; a chapter's own `README.md` is documentation and is
  not a scene, but its YAML frontmatter supplies the Section record. A chapter becomes one
  top-level Section whose slug is the directory name (`01-arrival`) and whose name is the
  frontmatter `title`, with the leading `Chapter NN —` removed (`Chapter 01 — The Arrival Gate` →
  `The Arrival Gate`); without frontmatter the name falls back to the README's first `#` heading,
  then to the slug part titleized (`01-arrival` → `Arrival`). The frontmatter `summary` fills the
  Section's `short_summary`, and every other key is carried whole in its `description` as YAML,
  with entity references resolved to record names like any other profile answer. Everything after
  the closing `---` is documentation and is skipped, so a `##` subsection is neither imported nor
  reported. Every imported chapter Section is labelled with the
  Story's **Chapter** Section Tag, which the run creates once per Story. Chapters are written in
  sorted directory order. Chapter and scene numbers are two-digit positions; they are filenames, not
  database ids. A scene's frontmatter `id` is the backlog item it was written from, never a unique
  scene key; the filename is the scene's identity inside its chapter. Its story-wide address is that
  filename without the two-digit sequence (`01-the-gate` → `the-gate`); it must be unique within the
  Story and is frozen once the file exists. The imported Scene takes that address as its slug, so a
  `[[scene:slug]]` link resolves from any file in the Story.
- `stories/<story>/plots/` is optional. Each Markdown file is one Plot thread; the directory's
  `README.md` is its human index and is not a Plot.

## Frontmatter

Every entity, plot, and scene file begins with a YAML frontmatter block between `---` lines. A
chapter README carries one as its machine-readable record; the import reads it when present and
otherwise falls back to the heading and slug. The other READMEs and a canon area file do not need
one.

| Record | Required keys | Optional keys |
|---|---|---|
| Character | `name`, `slug`, `affiliation` | `role`, `status`, `first_appears`, `backlog` |
| Faction | `name`, `slug` | `type`, `home`, `status`, `backlog` |
| Location | `name`, `slug` | `type`, `controller`, `status`, `backlog` |
| Item (`tech/`) | `name`, `slug` | `type`, `invented_by`, `status`, `backlog` |
| Plot | `name`, `slug` | `type`, `status`, `owner_pov`, `opened_in`, `backlog` |
| Scene | `id`, `title`, `pov`, `location`, `timeline`, `branch` | `moment`, `plot` |
| Chapter README | `title` | `summary`, `act`, `band`, `pov`, `locations`, `plots`, `status`, `missing`, `words`, `provisional` |

A chapter README's keys are read rather than validated against the entity rules: `title` names the
Section, `summary` fills `short_summary`, `title` and `summary` are omitted from the description, and
every other key is carried there as YAML. The body after the closing `---` is documentation and is
never read as content.

Rules for those values:

- `slug` must equal the filename without `.md`, and must be a lowercase hyphenated slug.
- `name`, `role`, `type`, `status`, and the other free-text keys are author prose. `type` and a
  plot or entity `status` are not restricted to the values the template suggests, because the real
  source already uses values outside it.
- A Scene's `id` is `B-###`, the author's backlog item. It is not a unique scene key and two scenes
  may share it. `chapter` and `sequence` are the path, not frontmatter: a Scene's chapter is its
  directory and its sequence is the filename prefix. `pov` names a Character, `location` names a
  Location, and both must exist in the same source. A blank or `— TBD` value means the Scene has not
  recorded one.
- A Scene's `branch` is `main` or `fork of <Holder>-<NN>`.
- A Scene carries no writing status and no dependency list. The application writes every imported
  Scene as `draft`; a `status` or `depends_on` key is an unknown frontmatter key.
- `timeline` is author prose such as "ninth day after the flare". It is reported rather than read as
  a date; `moment` is its parseable twin.
- `moment` is optional in the validator so an older source still imports, but the current source
  carries the key in every scene, with an empty string when neither a point nor a relation is known.
  It has exactly one of these forms, most specific first:

  | Form | Meaning |
  |---|---|
  | `YYYY-MM-DD HH:MM` | a known date and clock time (`2050-03-03 09:20`) |
  | `YYYY-MM-DD` | a known date, no clock time (`3550-03-03`); a date-only Event starts at midnight |
  | `<N> <unit> before\|after <scene>` | a known span from another scene (`1500 years after 02-the-flare/01-the-flare`); the unit is `years`, `months`, `weeks`, `days`, `hours`, or `minutes` |
  | `before\|after <scene>` | only the direction is known |
  | `at the same time as <scene>` | exactly simultaneous with another scene |
  | `""` | nothing concrete and nothing relative |

  `<scene>` is the target's path under the Story's `chapters/` directory without `.md`
  (`06-the-meeting/02-the-page`), so it is unique across chapters and may point forward or
  backward. A relation must name a scene that exists in the same Story, and never the scene itself.
- A Scene's optional `plot` is the bare slug of a Plot in the same Story (`the-meeting`). It is the
  join the import writes: the Scene is assigned to that thread. A value that names no Plot in the
  Story is an error. The key is omitted when the Scene belongs to none.
- An unknown frontmatter key is a warning; a missing or blank required key is an error.

## Profile sections

The body starts with one heading and continues with `##` sections. A profile file and a Scene both
open with their record's `#` heading (see [Plot and Scene](#plot-and-scene)); that heading names the
record and is not prose. A section that maps to a record's own answer is written into that
answer, with its Markdown body kept as written; a section with no target is reported by the import
slice, never silently dropped. Characters, Factions, Locations, and Items map their whole body
instead, as described below; a Plot maps its `Short summary` and folds the rest into its description,
and a Section maps only the chapter README's frontmatter.

HTML comments (`<!-- … -->`) are drafting notes for the author, not prose. They are stripped before
a section is stored and before references are scanned, so a `[[slug]]` inside one is an example
rather than a reference. The one exception is a Scene's closing `DRAFTING CONTRACT` comment, which
the import reads into the Scene's `drafting_contract` note rather than storing as prose.

The prose before the first `##` section — the source's identity block — has no dedicated column. A
Character, Faction, Location, Item, or Plot folds it into `description`; a Scene reports prose before
its first block rather than storing it. A frontmatter key the application has no column for is
reported by name rather than folded into another answer.

### Character

A Character is one short summary and one Markdown description. `Short summary`
writes `summary`; the identity block before the first `##` and every other `##`
section are joined into `description`, in source order, with their headings and
Markdown kept as written. That includes `Information`, where the source keeps
role, status, age, homeworld, languages, occupation, and first appearance.

Nothing in the body is reported, because the description has a target for all of
it. `At a glance` is the older summary heading and is still read.

The description is the one answer whose `[[kind:slug]]` references stay in their source form: the
details page turns each into a link, so resolving it to plain names would lose the link. That render
is owned by [Characters](characters.md#links-inside-a-description).

The source has no pronouns or aliases section; those fields stay blank when a Character has none.
`affiliation` is the source's faction list. Each `[[faction:slug]]` becomes a Faction membership;
the validator has already refused a link to a missing record or to another kind, and the Factions
slice runs first so the record exists. A bare name such as an in-world institution, or `TBD`, has no
Faction behind it and is reported instead of guessed into one. The frontmatter keys `role`, `status`,
`first_appears`, and `backlog` have no Character column and are reported when they are present; the
current source keeps only the three identity keys in frontmatter and writes the others under
`Information`.

#### Relationships

The bullets under `## Relationships` become Relations. A bullet leads with the Character it names:
`[[character:slug|type:boss]] - the dynamic.` The slug is everything before the `|`; the type after
`type:` names the linked Character's role toward the file's own Character. The type is optional:
`[[character:slug]]` and `[[character:slug|type:]]` both mean a relationship with no type. A bullet
that does not lead with a Character link, such as a plain name or a Faction, names no record the
Relation can link and is not imported.

Every distinct nonblank type becomes a Relation tag in the imported Universe, created when that name
does not already exist. The tag keeps the source's name exactly. The source defines no inverse, so
the created tag keeps the model's symmetric default.

**One Relation is written per unordered pair of Characters.** The source states a mutual
relationship from both files, so reciprocal bullets collapse into one edge. The first typed bullet
decides the pair where one is stated, and a later typed bullet replaces an earlier untyped one so a
type the source did state is not lost. With a type, the linked Character is `character1` and the
file's Character is `character2`, so the tag reads as a verb about the first endpoint; an untagged
Relation keeps the file's Character first. The Relation's `description` is the bullet's dynamic plus
its `Leverage:` paragraph, with references resolved to record names and canon or rule ids.

### Faction

A Faction is one short summary and one Markdown description. `Short summary` writes `summary`;
when a file has no `Short summary`, the older `Mission` heading is the summary instead. When both
are present, `Mission` is one more `##` section and lands in `description` with everything else.
The identity block before the first `##` and every other `##` section are joined into
`description`, in source order, with their headings and Markdown kept as written. Nothing in the
body is reported, because the description has a target for all of it, including `Information`,
where the current source keeps type, home, status, and backlog as labelled bullets.

`type`, `home`, `status`, and `backlog` have no Faction column. The current source writes them under
`Information`, so they stay in the description; an older file that still carries them in
frontmatter has them reported by name.

The description's `[[kind:slug]]` references stay in their source form too, and the details page
renders them with the same dialect as a Character's description.

### Location

A Location keeps only the fields its record has columns for: a name, its place in the hierarchy, and
one Markdown description carrying every `##` section the source wrote, in source order.

The current source keeps only `name` and `slug` in a Location's frontmatter and writes type,
controller, status, and backlog as labelled bullets under `## Information`, so they stay in the
description. The older frontmatter keys are still accepted, and an older file that still carries
them in frontmatter has them reported by name. Every body section lands in the description,
including `Short summary`, `Information`, `Who is here`, `Events here`, `Story rules affecting this
place`, and `Open questions`.

The description's `[[kind:slug]]` references stay in their source form too, and the details page
renders them with the same dialect as a Character's description. The source is flat and a Location
carries a `parent_id`, but a filename says nothing about the hierarchy, so every imported Location is
top-level and the tree is the operator's.

### Item

A `tech/` file is an Item, not a new record kind. An Item keeps a name, its place in the hierarchy,
a short summary, and one Markdown description. The import writes the name, the hierarchy, and the
description: every `##` section the source wrote lands in the description, including
`Short summary`, in source order.

The current source keeps only `name` and `slug` in an Item's frontmatter and writes type, invented
by, status, and backlog as labelled bullets under `## Information`, so they stay in the description.
The older frontmatter keys are still accepted, and an older file that still carries them in
frontmatter has them reported by name. Every body section lands in the description, including
`Short summary`, `Information`, `In the story`, and `Open questions`.

The description's `[[kind:slug]]` references stay in their source form too, and the details page
renders them with the same dialect as a Character's description. An Item carries a `parent_id` like a
Location, and the same flat-source rule applies: every imported Item is top-level.

### Plot and Scene

A Plot is Story-owned, so the Stories slice runs first and writes them. `Short summary` writes the
Plot's `short_summary`, which its list row reads. The identity block before the first `##` section
and every other `##` section become one Markdown `description`, in source order, with their headings
and references kept as written. `type`, `status`, `owner_pov`, `opened_in`, and `backlog` have no
Plot column; the current source keeps them under `## Information`, so they stay in the description,
and an older file that still carries them in frontmatter has them reported by name. The Plots slice
runs last, after Scenes, and assigns the Plot every Scene whose own `plot` key names it.

A Scene file becomes one Scene in the Section its chapter directory names. The frontmatter with an
application column is written: `title` is the Scene's name, `pov` is its point-of-view Character,
`location` is a Location presence link with no role, and a concrete `moment` (a date or a date and
time) is the Scene's own `datetime`. The chapter and sequence are the path; the Scene's slug is the
filename without its two-digit sequence, the story-wide address a `[[scene:slug]]` link names. The
optional `plot` key is the thread the Scene dramatises and becomes its Plot assignment. `id`,
`timeline`, and `branch` have no Scene column and are reported. Every imported Scene is
written as `draft`, because the source keeps no writing status. A Scene's closing `DRAFTING
CONTRACT` HTML comment is read into the Scene's `drafting_contract` note rather than into prose; it
is the one comment the import keeps. The browser preference that can hide the note from Scene pages
is a display choice and never changes what the import writes.

A Scene's body opens with its `#` title heading — the same text as the frontmatter `title` — and
continues as alternating `## Narration` and `## Dialog` blocks in reading order: the first block is
Narration, and two blocks of the same kind never sit next to each other. Each block becomes one
ordered Element. A Narration block's paragraphs are the Element's Content, with entity references
written as record names as in a profile answer. A Dialog block becomes a Dialogue Element whose lines
are its ordered turns. `@[[character:slug]] "…"` names a Character speaker; a bare `@slug "…"` names a
speaker with no entity file and becomes a **non-character turn** whose `body` keeps the tag as
`slug: …`. `[[kind:slug]]` inside the line is a prose mention, resolved the same way. A turn may
wrap across physical lines; it continues until its closing quote, and the continuation lines are
joined with a space because the source's line break is the editor's. Every source line becomes a
turn, so a block's speakers are its cast and a dialog is never downgraded to Narration. A `##`
heading other than those two, prose before the first block, and two adjacent blocks of the same kind
are reported or refused as described under
[The validator](#the-validator). The source records no block title, so the first Element takes the
Scene's title and each later one appends its number. The source carries no tag taxonomy, so the
import creates no Scene Tags.

## Canon ledger

`universe/canon/README.md` is the ledger: it states the Locked/Open rule and indexes the areas.
Every area file begins with a `# Canon: <subject>` heading and holds items under `## Locked`,
`## Derived consequences`, and `## Open` headings.

- An item opens with a column-0 bullet whose marker is its own id and a full stop, followed by its
  **what**: one line naming what the item is about. `- K16. The moon event as the first checkout`,
  `- L1. Substrate`, `- O-I1. How rare the carrier condition is`. A blank line follows it, and the
  item's text runs beneath, indented two spaces, until the next column-0 marker or heading. A `###`
  group heading ends the item but not the ledger it sits in.
- `K##`, `L##`, and `D##` are rules. `O##` and `O-<letters>N` are open questions. The id prefix, not
  the heading, says which is which; a locked id under Open is a warning.
- Ids are global and stable across every area file. A duplicate is an error.
- The application imports one Canon Rule per `K`/`L`/`D`/`O` item. The id is the slug, lowercased
  (`L2` → `l2`); the what-line is the name (`- L2. Trigger` → `Trigger`); the prefix is the canon
  type (`K` locked, `L` rule, `D` consequence, `O` open); and the area filename without `.md` is the
  category. **For now the rule's `statement` is the item's whole text, the what-line and the body
  together, and the optional source passage stays empty.** An open question becomes a rule of type
  `open`, so it is held beside the rules it questions rather than dropped from the import.
- An item's text runs from its what-line to the next item or heading, so a sentence may span the
  line breaks the author used. The text is author prose, but it is stored as plain prose: emphasis,
  inline-code backticks, and strikethrough markers are stripped; a table keeps its cells on one line
  without its pipes or rule; a list keeps its text without its bullet; and a source file path such as
  `universe/canon/mechanism.md` or `README.md` is removed rather than stored. Rule, scene, and
  backlog references stay as written.

The older bold item form — `- **K16.** The moon event …`, with the item's text starting on the id
line — is still read, with its older mapping: a title after a dash is the name, the first sentence
is the statement, and the whole item is the source passage.

The text of each item is author prose. An import must not summarize, merge, or reorder it.

## References

The source resolves these forms. A reference inside a fenced code block is an example and is ignored;
a reference inside inline code is real, because the source writes rule citations that way.

| Form | Resolves to |
|---|---|
| `[[character:slug]]` | a Character in the same source |
| `[[character:slug\|type:type]]` | the same Character; [the Relationships slice](#relationships) reads the optional type |
| `[[faction:slug]]` | a Faction in the same source |
| `[[location:slug]]` | a Location in the same source |
| `[[item:slug]]` or `[[tech:slug]]` | an Item in the same source |
| `[[plot:slug]]` | a Plot in the same source |
| `[[slug]]` | a Character, Faction, Location, Item, or Plot in the same source, by slug alone |
| `[[rule:ID]]` or `[[canon:ID]]` | a canon item (`K`, `L`, `D`, or `O`) in `universe/canon/` |
| `[[scene:slug]]` | a scene in the same Story, by its story-wide bare slug; it may cross chapters |
| `B-###` | the author's backlog, written bare and never resolved; opaque to the app |

A Scene's `## Dialog` block names each line's speaker with an `@` form:
`@[[character:slug]] "…"` is a Character in the same source, and `@slug "…"` is a speaker with no
entity file, which imports as a non-character turn whose line keeps the tag. A bare speaker is never
resolved to a Character that happens to share its slug. Entity references inside a spoken line are
ordinary references and resolve to record names.

A typed reference must name a record of the kind its prefix declares. `[[location:ada]]` is an error
even though `ada` exists, because the page would have to break the link the author asked for. A bare
`[[slug]]` is the older form and is still accepted; it relies on the slug being unique across every
record kind, which the layout already requires.

A `moment` relation is not a `[[bracket]]` reference: it names its target by the scene's path under
`chapters/` without `.md` (`06-the-meeting/02-the-page`), so it is checked by the moment rules above
rather than by the reference scanner. A `[[scene:slug]]` names the same Story's scene by its
story-wide bare slug instead. Both forms may cross chapters; only the bracket form is a reference.

A work-item id is not a link: the source writes `B-###` as plain prose, so the scanner ignores it
rather than treating it as a reference. A bracketed `[[B-###]]` is still accepted as the same
opaque id for an older source, and is never resolved either.

`[[slug]]` written as bare documentation is allowed as a placeholder; any other unresolved reference
is an error.

A profile answer other than a Character description, and a Scene's prose, store a reference as the
name of the record whose kind a slice in that run writes, so the sentence reads as prose. A Character
description keeps the reference instead, because its page renders it as a link. Rule and backlog
references are not entity references and are left as written.

## The validator

`StoryInterchange.validate(path)` reads the source and returns a `StoryInterchange::Report`. The
report exposes `universe_slug`, `universe_name`, `stories`, `chapters`, `counts`, `errors`,
`warnings`, and `valid?`, plus the parsed `canon_rules` and `canon_questions` so the canon slice
writes what the preview showed. Counts are available for canon rules, open canon questions,
characters, factions, locations, items, stories, plots, chapters, scenes, and events.

The report also carries each parsed record as a `Report::Entity` — its kind, slug, name, frontmatter,
`##` sections, and introduction — reachable through `entities(kind)` and `entity(slug)`. A Plot entity
also names the `story_slug` whose directory holds it, and a Scene names its `chapter_slug`, its
story-wide `scene_slug`, and the `drafting_contract` its closing comment supplied. A slice reads that
instead of opening the file again, so the write cannot disagree with the preview about a heading or a
reference. A chapter is a
directory rather than a record file, so it is a separate `Report::Chapter` with its Story slug,
directory name, display name, the README's `summary` as its `short_summary`, and the rest of that
frontmatter as its `description`, in the sorted order the Sections slice writes.

Run it without writing anything:

```bash
bin/rails 'story_interchange:validate[/path/to/source]'
STORY_INTERCHANGE_PATH=/path/to/source bin/rails story_interchange:validate
```

The task prints the identity, the counts, and every issue, and exits non-zero when an error exists.

**Errors** stop an import:

- the source, `universe/`, `stories/`, `universe/canon/`, `universe/canon/README.md`, or an entity
  directory is missing;
- `stories/` has no Story, or a Story has no `README.md` or no `#` heading;
- an entity, plot, or scene file has no frontmatter, unreadable YAML, or a missing or blank required
  key;
- a slug does not match its filename, two records share a slug, or two scenes in one Story share a
  story-wide scene slug;
- a canon id is duplicated;
- a `[[slug]]`, `[[rule:ID]]`/`[[canon:ID]]`, or `[[scene:slug]]` does not resolve, or a bracket
  reference has an unknown form;
- a Scene's id, branch, point of view, location, or `plot` does not match the contract above;
- a Scene's `moment` does not parse, names no scene, or names its own scene;
- a Scene has no `#` title heading, no `## Narration` block, a block other than `## Narration` or
  `## Dialog`, a first block that is not Narration, two adjacent blocks of the same kind, a Dialog
  line that is not `@speaker "line"`, or a Dialog turn whose quote never closes.

**Warnings** do not stop an import, because the source may legitimately carry more than the app
knows:

- an unknown frontmatter key;
- a Scene's `#` title heading that disagrees with its frontmatter `title`;
- prose before a Scene's first `##` block, which has no Element target;
- a canon id outside a Locked, Derived, or Open section, or a locked id under Open;
- an unexpected entry in a story directory;
- an entry directly under `universe/` that is neither the README, `canon/`, nor one of the entity
  directories (`universe/inspirations.md` is the real example).

The validator's fixtures are synthetic and live under
`test/fixtures/files/story_interchange/`. The real novel is never committed here.

## Importing a source

`StoryInterchange::Import` writes a validated source into ordinary records. The platform-admin page
at `/import` and `bin/rails story_interchange:import` both call it; neither keeps an import path or
policy of its own.

### One universe, replaced

The target is derived, not chosen: the source directory's basename is the Universe's slug and the
`universe/README.md` heading (or the titleized slug when there is none) is the default name
([Identity without a manifest](#identity-without-a-manifest)). A run replaces the one live Universe
with that slug. No other universe is touched, and there is no way to import into a Universe with a
different address.

- When no live Universe has the slug, the run creates one owned by the importer.
- When one exists, the run soft-deletes it and creates a fresh Universe with the same slug. The
  application's own delete is a soft delete, so the old rows stay hidden exactly as every other
  deleted record does, while the new Universe takes the address. There is no restore path for a
  Universe, which is why the confirmation says the records created in the app for it are lost.
- A replaced Universe keeps its `private` and `collaboration_mode`; a fresh one takes the model
  defaults (public, direct). The source carries neither setting.

Delete, create, every slice, and the run's own row run in one transaction, so a slice that fails
leaves the database as it was and a committed run always has its report.

### Safety and confirmation

The run refuses, and writes nothing, when the validator reports an error, when the target Universe
has an open draft, or when it has a member other than the importer — including an owner who is
somebody else. The last two exist because replacing the Universe would destroy somebody else's
unfinished work or access; both surfaces name what they found, and the operator resolves it in the
app first.

The page shows the derived slug, the display name, and the records each slice will write before it
offers the write. The write is a `POST` behind a checkbox that says the existing records are lost;
a request without it is refused. The task prints the same preview and refuses to write unless
`CONFIRM_STORY_INTERCHANGE_IMPORT=1` is set. It takes the owner's email, because a Universe must have
an owner:

```bash
CONFIRM_STORY_INTERCHANGE_IMPORT=1 \
  bin/rails 'story_interchange:import[/path/to/source,owner@example.com]'
```

`STORY_INTERCHANGE_PATH` and `STORY_INTERCHANGE_OWNER` are the environment forms.

### The run page

A completed run has its own page at `/import/runs/:id`, and the write redirects there. It names the
source folder, the Universe the run wrote, whether it created or replaced one, the operator and the
moment, and each slice's written count beside every record that slice wrote; a record that still
carries content the app cannot store says beside its name what was left out.

That answer is stored in `story_interchange_runs.outcomes`, not carried in the flash, so the page
exists exactly when the write does and a large source does not overflow the session cookie. The
report keeps each record's name, its slug, and its leftover notes, so the page can still name what
was missing after the source is gone. The flash after the redirect is one sentence
(`imports.flash.imported`).

The page copies the Universe's name and slug into the run rather than resolving them, because a later
run replaces the Universe this one created and a soft-deleted Universe is hidden from the ordinary
scope. It links to a live Universe only when one still has that slug. This is
[ADR 0025](../adr/0025-a-notification-is-a-stored-sentence.md)'s stored-sentence trade, applied to a
run's report.

### Slices

One record type is one `StoryInterchange::Importer` subclass, registered in `Importers::ALL`. A
slice declares an I18n key for its name and the validator count it writes; a profile slice also
declares the record kind it writes, its section-to-column mapping, and the frontmatter keys it
reports. The preview, the task, and the page read that list, so adding a type never edits them.
**Canon** writes every `K`/`L`/`D`/`O` item described under [Canon ledger](#canon-ledger), the open
question as a rule of type `open`. **Factions** runs before **Characters**, **Locations**, and
**Items**, which write one record per file from the mapping above; a Character's
`[[faction:slug]]` affiliation needs its Faction to exist first. **Stories** writes one Story per
story directory, because a Plot needs the Story it belongs to, and **Sections** then writes one
Section per chapter directory, named from its README heading as described under
[Story records](#story-records), and labels each one with the Story's single **Chapter** Section
Tag.
**Scenes** follows, writing each Scene with its Elements and dialogue turns, because it needs the
Story, the Section, and the Character and Location links those earlier slices created. **Events**
runs after Scenes and writes one Event per Scene, named after the Scene and linked to it. A concrete
`moment` becomes the Event's `start_datetime`; a `before`, `after`, or `at the same time as` relation
becomes the matching `before_event`, `after_event`, or `simultaneous_event`; a span also computes
the Event's start from its target when the target has one. Every Event is created before any
relation is written, so a relation may point forward to a later scene. **Plots** runs last and
writes each Plot, then assigns it every Scene whose `plot` frontmatter names that thread. The
assignment is read from the Scene side; the source's `## Progression` rows stay in the Plot
description and are not a second source of assignment. A Scene that names no thread is simply left
unassigned.

A slice's `Outcome` lists every record it writes, in source order, and marks the ones that carry
content the app cannot store as reported. Both the preview and the [run page](#the-run-page) show one
list item per record, so the whole slice is visible, and only a record that needs a second look
carries a note. **That note is a sentence naming the leftover, not a count**: an unmapped section, a
frontmatter key with no column, the preamble block, a `[[slug]]` whose record kind has no slice, or an
affiliation that names no Faction. A long list is bounded to three names and its tail counted, so a
source with hundreds of unmapped headings still fits on the page. A record written whole is shown by
its name alone. Sections reports a chapter by its README subsections even though it writes the
README's identity block as the Section description.

### Where a source may live

The page never accepts a path. It lists only the folders directly under
`STORY_INTERCHANGE_IMPORT_ROOT`, and a name with a separator, `..`, a dot-file, or a symlink that
resolves outside the root is refused. Nothing is copied into the repository. The preview, the write,
and a run's page all ask for `:manage` on `StoryInterchange::Import`, the platform-level question the
creation limit also asks, so
a guest signs in and a signed-in non-operator receives `403`.

## What the import does not do

It writes only the records a registered slice owns, and it does not write the source back out, copy
it into the repository, or restore a replaced Universe. Faction-to-Faction relationships, Location
and Item hierarchy, and Scene Tags do not arrive from this slice; the source text that would carry
them is reported. The one Section Tag it creates is the **Chapter** label every chapter Section
carries, because a chapter is the only section kind the source names. A Scene's concrete `moment` and
the Events one per Scene are written, but an Event's own description, tags, and parent stay empty
because the source states none there.

Authoring guidance such as `universe/inspirations.md` has no record kind and is reported rather than
imported.
A [Universe backup](universe_backup.md) writes the reverse direction as a readable projection; that
document owns what the projection can and cannot carry.
