# Story export

A Story can be read as a book. The feature is one Story-scoped **Export** page and the printable HTML
manuscript it produces; there is no persisted export record, and nothing about the Story changes.

## Routes and access

| Purpose | Canonical URL |
|---|---|
| Export options | `/u/:universe_slug/s/:story_id/export` |
| Printable manuscript | `/u/:universe_slug/s/:story_id/export/manuscript` |

Both are reads of the Story and follow the Story page's access rules: a guest may export a public
universe, a private universe needs its owner or a member, and another universe's Story is a `404`.
The Story is resolved through the request's already-authorized Universe by the shared `set_story`
callback, never by `Story.find`. The manuscript is its own controller (`StoryManuscriptsController`)
rather than a second action on `StoryExportsController` so that the shared authorization sees a
`show` and grants the same `:read` it grants the Story page.

## The export page

Export is a link in the left sidebar's **Story workspace** block, beside Sections, Plots, and Scenes,
so it is one click from any story-scoped page. The page states the Story, offers the one format that
exists today, and returns to the Story overview.

**Printable HTML page** is the only format. Its form is a `GET` to the manuscript URL, so choosing a
scope never writes anything and the chosen document is a shareable address. The submit control opens
the manuscript in the same tab; the reader prints it or saves it as a PDF with the browser's own
print command. The page deliberately adds no PDF or EPUB dependency: the browser already owns that
step, and a printable document is the same HTML a future download would assemble.

A second format is a second section on this page plus one `get` route, reading the same assembled
Story. It is not a second page, and it does not add a scope of its own.

## The three scopes

The scope is a **URL value**, not a translated label. An absent or unrecognised value is `prose`, the
document that adds nothing the author did not ask for.

| Value | Label | What the document contains |
|---|---|---|
| `prose` | Prose only | Section headings, Scene titles, and the written Elements |
| `front_matter` | Prose and scene notes | The same, plus each Scene's notes (below) |
| `bible` | Prose, scene notes, and the universe bible | The same, plus the Universe appendices (below) |

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
body followed by the names of its speakers, which is the only attribution that source carries.
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
records this Story uses — each named by its own label and followed by one summary line when it has
one: `Character#at_a_glance` for Characters, `description` for the other three. Categories are in
that order, use the same title their workspace uses, and an empty category is omitted; a Universe
with none of the four adds no appendix section.

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

## Files

- `app/controllers/story_exports_controller.rb`, `app/controllers/story_manuscripts_controller.rb`
- `app/models/manuscript.rb`, `app/helpers/story_exports_helper.rb`
- `app/views/story_exports/`, `app/views/story_manuscripts/`, `app/views/layouts/manuscript.html.erb`
- `app/assets/stylesheets/_manuscript.scss`
- `test/models/manuscript_test.rb`, `test/helpers/story_exports_helper_test.rb`,
  `test/controllers/story_exports_controller_test.rb`
