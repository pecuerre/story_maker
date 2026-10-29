# Story interchange

A **story interchange source** is a directory of Markdown files that describes one Universe and any
number of its Stories. It is the format the author's `tcs` repository already uses, the contract a
future import reads, and the contract a future Universe backup writes.

The ownership decision is [ADR 0041](../adr/0041-the-story-interchange-is-a-directory-contract.md),
and the validator is `StoryInterchange::Validator` in `lib/story_interchange/`. This document owns the
directory layout, the frontmatter, the section-to-profile mapping, the reference forms, and what the
validator reports. It is **not** a second storage format: the database stays the source of truth, and
this slice only reads a source.

The app's code-owned starting shapes are a different subject: [Story structures](story_structures.md).

## A source is a directory

The source root contains exactly two trees. Its other entries — `docs/`, `.git/`, `AGENTS.md` — are
repository process, not interchange data, and are ignored.

```
<source>/
  universe/
    canon/
      README.md              the ledger rules and area index
      <area>.md              one canon area: Locked facts and Open questions
    characters/<slug>.md
    factions/<slug>.md
    locations/<slug>.md
    tech/<slug>.md
  stories/
    README.md                optional human index of the stories
    <story>/
      README.md              the reading order and the story's name
      chapters/
        NN-chapter/
          NN-scene.md
      plots/<slug>.md
```

`universe/` holds every record every Story shares. `stories/<story>/` holds only what that Story
owns: its chapters and scenes, its Plot threads, and its reading order. Prose never lives in
`universe/`, and a shared entity never lives inside a Story directory.

A file whose name starts with `.` is ignored, so `.gitkeep` may keep an empty directory in version
control. Only `.md` files are read.

## Identity without a manifest

There is no manifest. The tree itself names its universe and stories:

- **Universe slug** — the source directory's basename, with a trailing `.git` removed and the rest
  parameterized (`The Fifth Cabinet.git` → `the-fifth-cabinet`, `tcs.git` → `tcs`). A name with no
  letters or digits is refused.
- **Universe display name** — the slug titleized (`the-fifth-cabinet` → `The Fifth Cabinet`). It is a
  default; the Universe's name can be edited in the application after an import.
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

`universe/canon/README.md` is required. It holds the ledger rules and the area index; every other
Markdown file in `universe/canon/` is one area of canon.

## Story records

- `stories/<story>/README.md` is required. Its first `#` heading is the Story's name. Its reading
  order is presentation: **Scene positions and Section order are the data**, and the table is
  regenerated for a human rather than imported as a second source of order.
- `stories/<story>/chapters/` is optional. Each child is a chapter directory `NN-slug`, and each
  child of that is a scene file `NN-slug.md`. Chapter and scene numbers are two-digit positions; they
  are filenames, not database ids, and a scene also carries its stable in-world identity in
  frontmatter.
- `stories/<story>/plots/` is optional. Each Markdown file is one Plot thread.

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

The body starts with one `#` heading and continues with `##` sections. A section that maps to a
profile answer is written into that answer; a section with no target is reported by the import
slice, never silently dropped. The exact profile field lists live in
[Characters](characters.md#profile), [Factions](factions.md#scope-and-profile),
[Locations](locations.md#location-profile), and [Items](items.md#item-profile).

### Character

| Section | Target |
|---|---|
| At a glance | `at_a_glance` |
| Wants | `wants` |
| Needs | `needs` |
| Lies about (to themselves) | `lies_to_self` |
| Contradictions | `contradictions` |
| Under pressure they | `under_pressure_they` |
| Never | `never` |
| State of knowledge | the Character's knowledge records |
| Relationships | universe Relation records |
| Voice | no app field — report |
| Arc | no app field — report |
| Open questions | no record — report |

The source has no pronouns or aliases section; those profile answers stay blank when a Character has
none. `affiliation` is a faction reference or free text; the import slice decides whether it becomes
Faction membership, a profile answer, or both.

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
| `type` and `status` (frontmatter) | no app field — report |
| In the story, Open questions | no app field — report |

A `tech/` file is therefore an Item, not a new record kind. Its `type` and `status` are recognized
source facts with no Item column today; the slice that imports Items decides whether to keep them in
the profile prose or add a field.

### Plot and Scene

Plot and Scene sections are not profile answers. [Plots](plots.md) owns which Plot columns exist and
[Scenes](scenes.md) owns the Scene record; the import slices for them decide how `type`, `status`,
`owner_pov`, `opened_in`, `timeline`, `branch`, and `depends_on` land. The source keeps them in
frontmatter so the decision is not made by dropping them.

A Scene's body is manuscript prose. It maps to the Scene's ordered Elements, one block per
paragraph, when the Scene import slice exists.

## Canon ledger

`universe/canon/README.md` is the ledger: it states the Locked/Open rule and indexes the areas.
Every area file begins with a `# Canon: <subject>` heading and holds items under `## Locked`,
`## Derived consequences`, and `## Open` headings.

- An item is a bold id at the start of a line, bulleted or not: `**K16.**`, `**L1 — Substrate.**`,
  `**D8.**`, `**O-I1.**`.
- `K##`, `L##`, and `D##` are rules. `O##` and `O-<letters>N` are open questions. The id prefix, not
  the heading, says which is which; a locked id under Open is a warning.
- Ids are global and stable across every area file. A duplicate is an error.
- The application imports one Canon Rule per `K`/`L`/`D` item. The rule's statement is the item's
  first sentence or heading text, and its optional source passage is the item's text and area
  citation. Open questions are reported, never imported as rules, because an open question is not a
  rule the prose must obey.

The text of each item is author prose. An import must not summarize, merge, or reorder it.

## References

The source resolves four forms. A reference inside a fenced code block is an example and is ignored;
a reference inside inline code is real, because the source writes rule citations that way.

| Form | Resolves to |
|---|---|
| `[[slug]]` | a Character, Faction, Location, Item, or Plot in the same source |
| `[[rule:ID]]` | a canon item (`K`, `L`, `D`, or `O`) in `universe/canon/` |
| `[[scene:NN-slug]]` | a scene in the same chapter as the referring scene |
| `[[B-###]]` | the author's backlog; opaque to the app |

`[[slug]]` written as bare documentation is allowed as a placeholder; any other unresolved reference
is an error.

## The validator

`StoryInterchange.validate(path)` reads the source and returns a `StoryInterchange::Report`. The
report exposes `universe_slug`, `universe_name`, `stories`, `counts`, `errors`, `warnings`, and
`valid?`. Counts are available for canon rules, open canon questions, characters, factions,
locations, items, plots, chapters, and scenes, so an import preview can show them before writing.

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
- an unexpected entry in a story directory.

The validator's fixtures are synthetic and live under
`test/fixtures/files/story_interchange/`. The real novel is never committed here.

## What this slice does not do

It does not write a record, create a page, add a route, or copy a source into the repository. The
first import slice owns those. A [Universe backup](universe_backup.md) writes the reverse direction
as a readable projection; that document owns what the projection can and cannot carry. Until then the
layout and the validator are the whole contract.
