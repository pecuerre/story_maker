# Story export

A Story can be read as a book or carried to another site as a universe. The feature is one
Story-scoped **Export** page, the printable HTML manuscript it produces, and the story-interchange
directory it downloads. There is no persisted export record on either output, and nothing about the
Story changes.

The printable document is not a Universe backup. It reads one Story's prose and appendices; a
[Universe backup](universe_backup.md) copies the Universe's data behind every Story. The directory
export is the interchange format described in
[story_interchange.md](story_interchange.md), not the backup's archive.

## Routes and access

| Purpose | Canonical URL |
|---|---|
| Export options | `/u/:universe_slug/s/:story_id/export` |
| Printable manuscript | `/u/:universe_slug/s/:story_id/export/manuscript` |
| Story interchange directory | `/u/:universe_slug/s/:story_id/export/interchange` |

All three are reads of the Story and follow the Story page's access rules: a guest may export a public
universe, a private universe needs its owner or a member, and another universe's Story is a `404`.
The Story is resolved through the request's already-authorized Universe by the shared `set_story`
callback, never by `Story.find`. The manuscript and the directory download are their own controllers
(`StoryManuscriptsController` and `StoryInterchangeExportsController`) rather than further actions on
`StoryExportsController`, so that the shared authorization sees a `show` and grants the same `:read`
it grants the Story page.

## The export page

Export is a link in the left sidebar's **Story workspace** block, beside Sections, Plots, and Scenes,
so it is one click from any story-scoped page. The page states the Story, offers both formats, and
returns to the Story overview.

**Printable HTML page** is the first section, and its **About the export** notes sit inside that same
card: they describe that output rather than the page. Its form is a `GET` to the manuscript URL, so
choosing a scope never writes anything and the chosen document is a shareable address. The submit
control opens the manuscript in a new tab, so the export options stay beside the document; the reader
prints it or saves it as a PDF with the browser's own print command. The page deliberately adds no PDF
or EPUB dependency: the browser already owns that step, and a printable document is the same HTML a
future download would assemble.

**Story interchange directory** is the second section, below the printable card. It is one `GET`
link, not a form: the download has no options, and a plain address keeps it shareable. The same rule
as above applies to a third format: it is a third section on this page plus one `get` route, never a
second page.

## The three scopes

The scope is a **URL value**, not a translated label. An absent or unrecognised value is `prose`, the
document that adds nothing the author did not ask for.

| Value | Label | What the document contains |
|---|---|---|
| `prose` | Prose only | Section headings, Scene titles, and the written Elements |
| `front_matter` | Prose and scene notes | The same, plus each Scene's notes (below) |
| `bible` | Prose, scene notes, and the universe bible | The same, plus the Universe appendices (below) |

## Scene status

The export page also offers **Final scenes only**, an independent GET choice beside the scope. It is
unchecked by default, so the complete manuscript remains the default output; when checked, the
manuscript URL carries `final_only=1` and `Manuscript` narrows its loaded Scenes to
`Scene::FINAL_STATUS`. The chosen scope still decides what each printed Scene carries, and section
grouping and narrative order are untouched. The Scene relation is narrowed before the Section tree,
notes, and prose are assembled, so the document cannot contain a Scene the choice excluded; the
Universe appendices are unchanged. A Story with Sections but no final Scenes says that it has no final
scenes yet rather than printing headings over nothing.

The status vocabulary itself, its filter, and its badges belong to [Scenes](scenes.md#writing-status).

## Assembly

`Manuscript` (`app/models/manuscript.rb`) is the one assembly step, a value object that loads the
Story's Sections and Scenes once each with their Elements, presence links, Events, and point of view.

- Sections are read in `(position, id)` order and nested by `parent_id`, so a child Section prints
  under its parent. A child's Scenes appear under the child's heading, and a Section's own Scenes come
  before its child Sections.
- Scenes keep the Story's **narrative** `position` order inside the group they belong to. Section
  grouping never reorders them.
- A Scene with no Section — or whose Section is not part of this Story's tree — is printed after the
  Section tree under the shared **Ungrouped** label (`SectionPaths::UNGROUPED_LABEL_KEY`), so the four
  surfaces that name that group keep one word for it.
- Only live records are read: the Story's associations apply the soft-delete default scopes, so a
  removed Scene, Element, turn, or presence link is not in the document. A change remembered in a
  draft has not been applied to the Story and is therefore outside this read path by construction.

### Prose

Element order is the Scene's own flat `position` sequence. Narration prints its `body`. A Dialogue
with line-level turns prints the turns — speaker, optional parenthetical, and line — because those are
the attributed lines, and its block body repeats the same speech. A Dialogue with no turns prints its
body alone. Each turn prints as one hyphenated line, `- *Speaker* (parenthetical): line`, with the
speaker in italics and a colon before the speech, so the turns read as a list of spoken lines rather
than as a cast list. A non-character turn names its speaker in the line's own tag, so the manuscript
lifts the text before the first colon out as the speaker and prints the speech alone: `registry-clerk:
…` reads as `Registry Clerk: …`, not as **Non-character speaker** followed by the tag. A line with no
tag falls back to the **Non-character speaker** label and prints whole. A wrapped line hangs under
the speech, not under the hyphen.

A registered Character name in a printed body is marked and linked, with a mention kept visually
distinct from recorded presence; the matching rules are in [mentions.md](mentions.md).

Scene names and Section names are printed as titles. Section descriptions, Scene descriptions, and
Element names are author notes about the structure, not manuscript prose, so they are not printed.
`WordCounts` owns prose totals; this document does not compute or show them.

### Scene notes

`front_matter` and `bible` add one notes block above each Scene's prose, listing only the values that
exist:

- point of view (`Scene#pov_character`);
- in-world time (`Scene#datetime`, formatted by `ScenesHelper#scene_in_world_time`);
- explicitly linked Characters, Items, and Locations, each with its free-text role when one was
  recorded;
- the depicted Events in the Scene's own link order, labelled by `Event#display_label`, with the
  link's role when one was recorded.

Only stored presence links are listed. A Character who speaks without a presence link appears in the
dialogue instead, and is not repeated as a note; presence and speech remain the two independent
sources the Scene domain defines in [scenes](scenes.md).

### Universe appendices

`bible` ends the document with the Universe's Characters, Locations, Items, and Events — not only the
records this Story uses. Each category prints its workspace title, and each record is its own entry:
the record named by its label (`display_label` for an Event, whose name may be a date) and, below that
name, the profile text the record has.

A Character prints its one-line `summary`, which stays one line of plain text. A Location and an Item
print their Markdown `description`, rendered with the same dialect as the details page, so its `##`
sections become headings. Each description heading is demoted below the entry's own heading, so a
profile section cannot outrank the category above it. An Event's `description` is plain text, exactly
as its details page shows it.

A `[[kind:slug]]` reference reads as the name of the record it names — a canon rule keeps its ledger
id — and is never a link: paper has nothing to click, and the entry already belongs to its category.
An unresolved reference stays literal, and one inside a code span stays as written, exactly as on
screen. [characters.md](characters.md#links-inside-a-description) owns the reference rules;
`StoryExportsHelper#manuscript_appendix_text` chooses the rendering.

Categories are in the order Characters, Locations, Items, Events, use the same title their workspace
uses, and an empty category is omitted; a Universe with none of the four adds no appendix section.

## The printable page

The manuscript renders in `app/views/layouts/manuscript.html.erb`, a document layout with no navbar,
sidebar, or workspace action bar, so printing yields the manuscript and nothing else. It pins
`data-bs-theme="light"` because the reader's dark theme is a screen preference and a dark page would
print as ink.

The title page carries the Universe name, the Story name, and the Story description. A screen-only
hint below it explains the browser's print command and links back to the export options; the print
stylesheet hides it. `app/assets/stylesheets/_manuscript.scss` owns the measure, title page, scene
notes, and those print rules, and every rule is scoped under `.manuscript*` so no workspace page
inherits a book's leading.

The browser's print command is the export. There is no in-page print button, which keeps the document
free of JavaScript and of a Stimulus controller that would exist only to call `window.print()`.

## The story interchange directory

The second section downloads one `.tar.gz` whose single top-level directory is the Universe's slug.
That directory is a **story-interchange source** in the layout
[story_interchange.md](story_interchange.md) owns, intended for extracting and importing at another
site. The file is assembled in memory by `StoryInterchange::Export` and is
never written into the repository.

The download is **Universe-wide even though the page is Story-scoped**. A source describes one
Universe and its Stories, and the import replaces a Universe, so a Story-only slice would be a
different format. The Story only resolves the request's Universe and carries the page's access rules;
every live Story, Character, Faction, Location, Item, canon Rule, Section, Scene, and Plot of that
Universe is in the archive.

The export aims to produce a directory `StoryInterchange.validate` accepts, but valid application data
can make it fail or change on a round trip; see [known quirks](../known_quirks.md). What the interchange
layout cannot describe stays in the database rather than being invented: tags, Routes, tropes,
relations, ownerships, Events, photos,
Character aliases, Section descriptions, Scene parentheticals, and a canon Rule's optional Story owner
do not travel. The page names that boundary beside the button rather than implying a full backup.

Writing a source is not copying the database, so a few values have a canonical export form:

- A Scene needs the format's `B-###` id and its `main` branch. The Universe stores neither, so the id
  is derived from the Scene's database id and the branch is `main`; the import reads both as source
  facts and writes neither.
- A Scene's prose becomes alternating `## Narration` and `## Dialog` blocks. Adjacent Elements of the
  same kind merge into one block, and a Scene that opens with Dialogue gets an empty Narration before
  it, because that is the block grammar the validator accepts. The Element boundary and the Element
  titles do not survive; see [known quirks](../known_quirks.md) for the open prose and order issues.
- A Scene in more than one Plot carries the first Plot in its `plot` key, because the format names one
  thread per Scene. The other assignments stay behind.
- A Scene with no Section, or one whose Section is not in the Story's tree, is written in a chapter
  named **Ungrouped** after the Story's sections. The manuscript already groups those Scenes the same
  way, and without the chapter the import would have no Section to attach them to.
- A Character's `affiliation` is its Faction links joined by `·`; a Character in no Faction writes the
  source's `— TBD`. A canon Rule whose slug is not a ledger id is numbered under the prefix its canon
  type implies, so the ledger keeps globally unique ids.
- A Location and an Item have no summary column in the import. Their summary is written as a
  `Short summary` section, so the sentence survives in the description instead of being dropped.
- A Story with no source-ready prose still writes each Scene with a Narration block, and a Scene with
  no Elements writes an empty one. A Universe with no Stories cannot be imported at all: the
  interchange requires at least one Story directory, and the archive says so by being empty of
  `stories/` children.

The download is a `GET` that writes nothing. It carries `Cache-Control: no-store`, and the filename is
`<universe slug>-story-interchange-<timestamp>.tar.gz`.

## Files

- `app/controllers/story_exports_controller.rb`, `app/controllers/story_manuscripts_controller.rb`,
  `app/controllers/story_interchange_exports_controller.rb`
- `app/models/manuscript.rb`, `app/helpers/story_exports_helper.rb`
- `lib/story_interchange/export.rb`
- `app/views/story_exports/`, `app/views/story_manuscripts/`, `app/views/layouts/manuscript.html.erb`
- `app/assets/stylesheets/_manuscript.scss`
- `test/models/manuscript_test.rb`, `test/helpers/story_exports_helper_test.rb`,
  `test/controllers/story_exports_controller_test.rb`,
  `test/controllers/story_interchange_exports_controller_test.rb`,
  `test/lib/story_interchange/export_test.rb`
