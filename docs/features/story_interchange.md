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
          README.md          the chapter's header and its display name
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
parsing its examples as references. Three READMEs are still read for the one fact each owns: the
Universe's display name, the Story's name, and optionally a chapter's display name.

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
  not a scene. A chapter becomes one top-level Section whose slug is the directory name
  (`01-arrival`) and whose name is the first `#` heading in the chapter's `README.md` when it has
  one, with the leading `Chapter NN —` removed (`# Chapter 01 — The Arrival Gate` → `The Arrival
  Gate`); without that heading the name is the slug part titleized (`01-arrival` → `Arrival`).
  Chapters are written in sorted directory order. Chapter and scene numbers are two-digit
  positions; they are filenames, not database ids, and a scene also carries its stable in-world
  identity in frontmatter.
- `stories/<story>/plots/` is optional. Each Markdown file is one Plot thread; the directory's
  `README.md` is its human index and is not a Plot.

## Frontmatter

Every entity, plot, and scene file begins with a YAML frontmatter block between `---` lines. A
README and a canon area file do not need one.

| Record | Required keys | Optional keys |
|---|---|---|
| Character | `name`, `slug`, `role`, `affiliation`, `status` | `first_appears`, `backlog` |
| Faction | `name`, `slug`, `type`, `home`, `status` | `backlog` |
| Location | `name`, `slug`, `type`, `controller`, `status` | `backlog` |
| Item (`tech/`) | `name`, `slug`, `type`, `invented_by`, `status` | `backlog` |
| Plot | `name`, `slug`, `type`, `status`, `owner_pov` | `opened_in`, `backlog` |
| Scene | `id`, `title`, `chapter`, `sequence`, `pov`, `location`, `timeline`, `branch`, `status` | `depends_on` |

Rules for those values:

- `slug` must equal the filename without `.md`, and must be a lowercase hyphenated slug.
- `name`, `role`, `type`, `status`, and the other free-text keys are author prose. `type` and a
  plot or entity `status` are not restricted to the values the template suggests, because the real
  source already uses values outside it.
- A Scene's `id` is `B-###`. `chapter` must equal its chapter directory name, and `sequence` must
  match the filename prefix. `pov` names a Character, `location` names a Location, and both must
  exist in the same source. A blank or `— TBD` value means the Scene has not recorded one.
- A Scene's `branch` is `main` or `fork of <Holder>-<NN>`.
- A Scene's `status` is one of `draft`, `revised`, or `final`, matching the application's Scene
  status vocabulary.
- `depends_on` is a list of `B-###` ids.
- An unknown frontmatter key is a warning; a missing or blank required key is an error.

## Profile sections

The body starts with one heading and continues with `##` sections. A profile file opens with `#`
and a Scene opens with its own `##` title (see [Plot and Scene](#plot-and-scene)); either heading
names the record and is not prose. A section that maps to a profile answer is written into that
answer, with its Markdown body kept as written; a section with no target is reported by the import
slice, never silently dropped. The exact profile field lists live in
[Factions](factions.md#scope-and-profile), [Locations](locations.md#location-profile), and
[Items](items.md#item-profile); [Characters](characters.md#profile) maps its whole body instead, as
described below.

HTML comments (`<!-- … -->`) are drafting notes for the author, not prose. They are stripped before
a section is stored and before references are scanned, so a `[[slug]]` inside one is an example
rather than a reference.

The prose before the first `##` section — the source's identity block — has no dedicated column. A
Character folds it into `description`; the other profile slices report it as the record's
`introduction`. A frontmatter key the application has no column for is reported by name rather than
folded into another answer.

### Character

A Character is one short summary and one Markdown description. `At a glance` writes `summary`; the
identity block before the first `##` and every other `##` section are joined into `description`, in
source order, with their headings and Markdown kept as written. Nothing in the body is reported,
because the description has a target for all of it.

The description is the one answer whose `[[kind:slug]]` references stay in their source form: the
details page turns each into a link, so resolving it to plain names would lose the link. That render
is owned by [Characters](characters.md#links-inside-a-description).

The source has no pronouns or aliases section; those fields stay blank when a Character has none.
`affiliation` is free text in the real source and may name a Faction, another record, or prose, so
this slice **reports it and never turns it into Faction membership**: the operator assigns membership
in the app. The frontmatter keys `role`, `affiliation`, `status`, `first_appears`, and `backlog` all
have no Character column and are reported.

### Faction

| Section | Target |
|---|---|
| Mission | `mission` |
| Actually for | `actual_aims` |
| Structure | `structure` |
| Internal split | `internal_divisions` |
| Resources | `resources` |
| Would never | `would_never` |
| Would absolutely | `would_absolutely` |
| Register, The two rivals, Relationships, Open questions | no app field — report |

The Faction frontmatter keys `type`, `home`, `status`, and `backlog` have no Faction column and are
reported.

### Location

| Section | Target |
|---|---|
| What it is | `description` |
| Sensory | the five `sensory_*` answers |
| Layout | the five `layout_*` answers |
| Why it matters | `significance` |
| Control and access | the four `access_*` answers |
| History | the three `history_*` answers |
| Who is here, Events here, Story rules affecting this place, Open questions | no app field — report |

A section that fills several answers is split by label: `- Sight: a gate taller than the wall.`
writes `sensory_sight`. An item whose label names several answers fills each of them (`- Touch /
smell: cold stone.`), and words that name none are ignored. An item whose label names no answer, and
prose with no label at all, fills the group's first answer, so `sensory_sight`, `layout_structure`,
`access_controlled_by`, and `history_significant_events` hold an unlabelled paragraph.

The Location frontmatter keys `type`, `controller`, `status`, and `backlog` have no Location column
and are reported. The source is flat and a Location carries a `parent_id`, but a filename says
nothing about the hierarchy, so every imported Location is top-level and the tree is the operator's.

### Item

| Source | Target |
|---|---|
| One line | `what_it_does` |
| What it actually is | `description` |
| How it is operated | `how_it_is_used` |
| Physical side effects | `side_effects` |
| Cannot | `cannot` |
| Costs | `value` |
| Constraints | `constraints` |
| Jargon | `jargon` |
| History | `history` |
| `invented_by` (frontmatter) | `origin` |
| `type`, `status`, and `backlog` (frontmatter) | no app field — report |
| In the story, Open questions | no app field — report |

A `tech/` file is therefore an Item, not a new record kind. Its `type` and `status` are recognized
source facts with no Item column, so they are reported rather than kept in another answer. An Item
carries a `parent_id` like a Location, and the same flat-source rule applies: every imported Item is
top-level.

### Plot and Scene

A Plot is Story-owned, so the Stories slice runs first and writes them. A Plot's `## The question`
section is its `description`; its remaining sections are not profile answers and are reported, as
are `type`, `status`, `owner_pov`, `opened_in`, and `backlog`, which have no Plot column. Plot Scene
assignments belong to a later slice, so a Plot lands with no Scenes.

A Scene file becomes one Scene in the Section its chapter directory names. The frontmatter with an
application column is written: `title` is the Scene's name, `chapter` selects the Section, `sequence`
with the chapter order gives its flat position in the Story, `pov` is its point-of-view Character,
`location` is a Location presence link with no role, and `status` is its writing status. `id`,
`timeline`, `branch`, and `depends_on` have no Scene column and are reported. `timeline` is author
prose such as "ninth day after the flare", never a date the import may parse into `datetime`, so the
Scene's in-world time stays empty and the source text is kept in the report.

A Scene's body opens with its `##` title — the same text as the frontmatter `title` — and continues
as manuscript prose. The heading names the Scene and is not a section; every later `##` heading has
no Scene target and is reported. Every blank-line-separated paragraph becomes one ordered Narration
[Element](scenes.md#elements). The source records no block title, so the first Element takes the
Scene's title and each later one appends its number. No Dialogue Element, speaker, or turn is
invented: the source states a speaker and line only in prose, so dialogue attribution is preserved
only where it is written. Entity references in that prose are written as record names, as in a
profile answer; rule, scene, and backlog references stay as written. The source carries no tag
taxonomy, so the import creates no Scene Tags.

## Canon ledger

`universe/canon/README.md` is the ledger: it states the Locked/Open rule and indexes the areas.
Every area file begins with a `# Canon: <subject>` heading and holds items under `## Locked`,
`## Derived consequences`, and `## Open` headings.

- An item is a bold id at the start of a line, bulleted or not: `**K16.**`, `**L1 — Substrate.**`,
  `**D8.**`, `**O-I1.**`. The punctuation after the id is either a full stop or a short title after a
  dash; hyphen, en dash, and em dash are all read.
- `K##`, `L##`, and `D##` are rules. `O##` and `O-<letters>N` are open questions. The id prefix, not
  the heading, says which is which; a locked id under Open is a warning.
- Ids are global and stable across every area file. A duplicate is an error.
- The application imports one Canon Rule per `K`/`L`/`D`/`O` item. The id is the slug, lowercased
  (`L2` → `l2`); the title after the dash is the name (`L2 — Trigger` → `Trigger`), or the statement
  when the item states no title; the prefix is the canon type (`K` locked, `L` rule, `D` consequence,
  `O` open); and the area filename without `.md` is the category. The statement is the first sentence
  of the whole item, and the optional source passage is the item's own text. An open question becomes
  a rule of type `open`, so it is held beside the rules it questions rather than dropped from the
  import.
- An item's text runs from its bold id to the next item or `##` heading, so a sentence may span the
  line breaks the author used. The text is author prose, but it is stored as plain prose: emphasis,
  inline-code backticks, and strikethrough markers are stripped; a table keeps its cells on one line
  without its pipes or rule; a list keeps its text without its bullet; and a source file path such as
  `universe/canon/mechanism.md` or `README.md` is removed rather than stored. Rule, scene, and backlog
  references stay as written.
- A citation in the title — `(Amended by K27)`, a `rule:L3` reference — is removed from the name and
  stays in the item's text, which is where the source passage and the statement read it. A leading
  amendment note (`*(Amended by K27.)*`, `(Author direction — K67: …)`) stays in the source passage
  and is skipped when the statement is drawn, so an untitled rule is named after the rule rather than
  after the note.

The text of each item is author prose. An import must not summarize, merge, or reorder it.

## References

The source resolves these forms. A reference inside a fenced code block is an example and is ignored;
a reference inside inline code is real, because the source writes rule citations that way.

| Form | Resolves to |
|---|---|
| `[[character:slug]]` | a Character in the same source |
| `[[faction:slug]]` | a Faction in the same source |
| `[[location:slug]]` | a Location in the same source |
| `[[item:slug]]` or `[[tech:slug]]` | an Item in the same source |
| `[[plot:slug]]` | a Plot in the same source |
| `[[slug]]` | a Character, Faction, Location, Item, or Plot in the same source, by slug alone |
| `[[rule:ID]]` | a canon item (`K`, `L`, `D`, or `O`) in `universe/canon/` |
| `[[scene:NN-slug]]` | a scene in the same chapter as the referring scene |
| `B-###` | the author's backlog, written bare and never resolved; opaque to the app |

A typed reference must name a record of the kind its prefix declares. `[[location:ada]]` is an error
even though `ada` exists, because the page would have to break the link the author asked for. A bare
`[[slug]]` is the older form and is still accepted; it relies on the slug being unique across every
record kind, which the layout already requires.

A work-item id is not a link: the source writes `B-###` as plain prose, so the scanner ignores it
rather than treating it as a reference. A bracketed `[[B-###]]` is still accepted as the same
opaque id for an older source, and is never resolved either.

`[[slug]]` written as bare documentation is allowed as a placeholder; any other unresolved reference
is an error.

A profile answer other than a Character description, and a Scene's prose, store a reference as the
name of the record whose kind a slice in that run writes, so the sentence reads as prose. A Character
description keeps the reference instead, because its page renders it as a link. Rule, scene, and
backlog references are not entity references and are left as written.

## The validator

`StoryInterchange.validate(path)` reads the source and returns a `StoryInterchange::Report`. The
report exposes `universe_slug`, `universe_name`, `stories`, `chapters`, `counts`, `errors`,
`warnings`, and `valid?`, plus the parsed `canon_rules` and `canon_questions` so the canon slice
writes what the preview showed. Counts are available for canon rules, open canon questions,
characters, factions, locations, items, stories, plots, chapters, and scenes.

The report also carries each parsed record as a `Report::Entity` — its kind, slug, name, frontmatter,
`##` sections, and introduction — reachable through `entities(kind)` and `entity(slug)`. A Plot entity
also names the `story_slug` whose directory holds it. A slice reads that instead of opening the file
again, so the write cannot disagree with the preview about a heading or a reference. A chapter is a
directory rather than a record file, so it is a separate `Report::Chapter` with its Story slug,
directory name, and display name, in the sorted order the Sections slice writes.

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
- a slug does not match its filename, or two records share a slug;
- a canon id is duplicated;
- a `[[slug]]`, `[[rule:ID]]`, or `[[scene:NN-slug]]` does not resolve, or a bracket reference has
  an unknown form;
- a Scene's chapter, sequence, id, branch, status, point of view, location, or `depends_on` does not
  match the contract above.

**Warnings** do not stop an import, because the source may legitimately carry more than the app
knows:

- an unknown frontmatter key;
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
moment, and each slice's written count beside **every** source item that slice reported instead of
writing.

That answer is stored in `story_interchange_runs.outcomes`, not carried in the flash. A source with a
few hundred reported ids builds a message larger than the 4 KB a session cookie may hold, and the
cookie store raises `ActionDispatch::Cookies::CookieOverflow` while the response commits — after the
import transaction has already succeeded, so the operator saw a 500 for a completed import. The run row
is written inside that transaction, so the page exists exactly when the write does. The flash after the
redirect is one sentence (`imports.flash.imported`).

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
question as a rule of type `open`. **Characters**, **Factions**, **Locations**, and **Items** write one
record per file from the mapping above. **Stories** writes one Story per story directory, because a
Plot needs the Story it belongs to, and **Sections** then writes one Section per chapter directory,
named from its README heading as described under [Story records](#story-records).
**Scenes** follows, writing each Scene with its Elements, because it needs the Story, the Section,
and the Character and Location links those earlier slices created. **Plots** runs last and writes
each Plot with no Scenes. Plot Scene assignments remain validator-only and plug into the same
registry when their slice exists.

A slice's `Outcome` names every source item it reports instead of writing, and both the preview and
the [run page](#the-run-page) show that list: an unmapped section, a frontmatter key with no column,
the preamble block, or a `[[slug]]` whose record kind has no slice.

### Where a source may live

The page never accepts a path. It lists only the folders directly under
`STORY_INTERCHANGE_IMPORT_ROOT`, and a name with a separator, `..`, a dot-file, or a symlink that
resolves outside the root is refused. Nothing is copied into the repository. The preview, the write,
and a run's page all ask for `:manage` on `StoryInterchange::Import`, the platform-level question the
creation limit also asks, so
a guest signs in and a signed-in non-operator receives `403`.

## What the import does not do

It writes only the records a registered slice owns, and it does not write the source back out, copy
it into the repository, or restore a replaced Universe. Relations, Faction membership, Location and
Item hierarchy, Plot Scene assignments, Scene Tags, and a Scene's in-world datetime do not arrive
from this slice; the source text that would carry them is reported. Authoring
guidance such as `universe/inspirations.md` has no record kind and is reported rather than imported.
A [Universe backup](universe_backup.md) writes the reverse direction as a readable projection; that
document owns what the projection can and cannot carry.
